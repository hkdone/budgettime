package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/jsvm"
)

// generateEnableBankingJWT lit la clé privée et génère un JWT valide pour 1h
func generateEnableBankingJWT() (string, error) {
	// 1. Récupérer l'Application ID
	appId := os.Getenv("ENABLE_BANKING_APP_ID")
	if appId == "" {
		return "", fmt.Errorf("ENABLE_BANKING_APP_ID environment variable is missing")
	}

	// 2. Trouver la clé privée (soit env var, soit fichier local dans ./secrets)
	var privateKeyBytes []byte
	if envKey := os.Getenv("ENABLE_BANKING_PRIVATE_KEY"); envKey != "" {
		privateKeyBytes = []byte(envKey)
	} else {
		// Chercher dans le dossier ./secrets/ à la racine
		keyPath := filepath.Join("secrets", "enablebanking_private.pem")
		bytes, err := os.ReadFile(keyPath)
		if err != nil {
			return "", fmt.Errorf("failed to read private key from %s: %w", keyPath, err)
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
			token, err := generateEnableBankingJWT()
			if err != nil {
				return e.Error(500, "JWT Generation Failed", err)
			}
			return e.JSON(200, map[string]string{
				"token": token,
			})
		})
		return e.Next()
	})

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}
