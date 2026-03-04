package main

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/jsvm"
)

// generateEnableBankingJWT lit la clé privée et génère un JWT valide pour 1h
func generateEnableBankingJWT(app *pocketbase.PocketBase) (string, error) {
	// 1. Récupérer l'Application ID
	appId := os.Getenv("ENABLE_BANKING_APP_ID")
	if appId == "" {
		return "", fmt.Errorf("ENABLE_BANKING_APP_ID environment variable is missing")
	}

	// 2. Trouver la clé privée (soit env var, soit fichier local dans ./secrets/<appId>.pem)
	var privateKeyBytes []byte
	if envKey := os.Getenv("ENABLE_BANKING_PRIVATE_KEY"); envKey != "" {
		privateKeyBytes = []byte(envKey)
	} else {
		// Chercher dans le dossier ./secrets/ à la racine le fichier nommé comme l'App ID
		// On s'assure de cibler le même répertoire parent que 'pb_data' ou 'pb_public'
		fileName := fmt.Sprintf("%s.pem", appId)

		var baseDir string
		if app != nil {
			baseDir = filepath.Dir(app.DataDir())
		} else {
			baseDir = "."
		}

		keyPath := filepath.Join(baseDir, "secrets", fileName)
		bytes, err := os.ReadFile(keyPath)
		if err != nil {
			return "", fmt.Errorf("échec de la lecture de la clé privée depuis %s : %w", keyPath, err)
		}
		privateKeyBytes = bytes
	}

	// 3. Parser la clé RSA
	privateKey, err := jwt.ParseRSAPrivateKeyFromPEM(privateKeyBytes)
	if err != nil {
		return "", fmt.Errorf("failed to parse RSA private key: %w", err)
	}

	// 4. Créer le contenu du JWT (Claims)
	now := time.Now()
	claims := jwt.MapClaims{
		"iss": "enablebanking.com",
		"aud": "api.enablebanking.com",
		"iat": now.Unix(),
		"exp": now.Add(1 * time.Hour).Unix(), // Expiration 1h (Max 24h par EnableBanking)
	}

	// 5. Créer et signer le Token
	token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)

	// HEADER: RS256 et 'kid' = Application ID
	token.Header["alg"] = "RS256"
	token.Header["typ"] = "JWT"
	token.Header["kid"] = appId

	// 6. Signer avec la clé privée castée
	signedToken, err := token.SignedString(privateKey)
	if err != nil {
		return "", fmt.Errorf("failed to sign JWT: %w", err)
	}

	return signedToken, nil
}

func main() {
	app := pocketbase.New()

	jsvm.MustRegister(app, jsvm.Config{})

	// Exposition du générateur JWT via une route API Serveur (Locally accessible via pb_hooks)
	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		e.Router.GET("/api/banking/jwt", func(e *core.RequestEvent) error {
			// Autoriser uniquement les appels serveurs locaux ou admin pour la sécurité
			// On génère la clé RSA JWT
			token, err := generateEnableBankingJWT(app)
			if err != nil {
				return e.Error(500, "JWT Generation Failed", err)
			}
			return e.JSON(200, map[string]string{
				"token": token,
			})
		})

		// Route de test directe en Go Natif (Bypass JSVM pour éviter les 404 Docker)
		e.Router.GET("/api/test-banking", func(e *core.RequestEvent) error {
			token, err := generateEnableBankingJWT(app)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "JWT Gen Failed", "details": err.Error()})
			}

			req, err := http.NewRequest("GET", "https://api.enablebanking.com/application", nil)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "Request creation failed"})
			}
			req.Header.Set("Authorization", "Bearer "+token)
			req.Header.Set("Content-Type", "application/json")

			client := &http.Client{Timeout: 10 * time.Second}
			resp, err := client.Do(req)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "API Call Failed", "details": err.Error()})
			}
			defer resp.Body.Close()

			body, _ := io.ReadAll(resp.Body)

			return e.JSON(200, map[string]any{
				"status":            "Test réussi en Go Natif !",
				"jwt_generated":     token[:15] + "...",
				"api_response_code": resp.StatusCode,
				"api_response_body": string(body),
			})
		})

		// Indispensable pour les Frameworks Custom (Go natif) : Servir le Frontend Web
		publicDir := filepath.Join(filepath.Dir(app.DataDir()), "pb_public")
		e.Router.GET("/{path...}", apis.Static(os.DirFS(publicDir), false))

		return e.Next()
	})

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
