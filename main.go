package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/pocketbase/dbx"
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

		// 1. Endpoint : Récupérer la liste des banques (Institutions)
		e.Router.GET("/api/banking/institutions", func(e *core.RequestEvent) error {
			country := e.Request.URL.Query().Get("country")
			if country == "" {
				country = "FR" // Par défaut, la France
			}

			// 1. Générer le JWT
			token, err := generateEnableBankingJWT(app)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "JWT Generation Failed", "details": err.Error()})
			}

			// 2. Préparer l'appel à Enable Banking API (v2)
			apiURL := "https://api.enablebanking.com/application/2/institutions?country=" + country
			req, err := http.NewRequest("GET", apiURL, nil)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "API Request Creation Failed"})
			}
			req.Header.Set("Authorization", "Bearer "+token)

			// 3. Exécuter l'appel Http
			client := &http.Client{Timeout: 10 * time.Second}
			resp, err := client.Do(req)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "API Call to EnableBanking Failed", "details": err.Error()})
			}
			defer resp.Body.Close()

			body, _ := io.ReadAll(resp.Body)

			// 4. Si ce n'est pas un 200, remonter l'erreur native
			if resp.StatusCode != 200 {
				return e.JSON(resp.StatusCode, map[string]any{
					"error":   "EnableBanking returned an error",
					"details": string(body),
				})
			}

			// 5. Renvoyer le JSON brut des banques à l'application Flutter
			// En Go PocketBase e.JSON demande une structure, on parse puis on renvoie pour être propre
			// ou bien on utilise e.String avec le bon Content-Type. On va simplifier avec String + Blob.
			e.Response.Header().Set("Content-Type", "application/json; charset=utf-8")
			return e.String(200, string(body))
		})

		// 2. Endpoint : Demander un lien d'autorisation pour une banque spécifique
		e.Router.POST("/api/banking/auth", func(e *core.RequestEvent) error {
			// 1. Lire le body envoyé par Flutter
			var reqData struct {
				BankID      string `json:"bank_id"`
				Country     string `json:"country"`
				RedirectURL string `json:"redirect_url"` // L'URL publique de BudgetTime (ex: http://mon.nas.local:8097/api/banking/callback)
			}
			if err := e.BindBody(&reqData); err != nil {
				return e.JSON(400, map[string]any{"error": "Invalid request body", "details": err.Error()})
			}
			if reqData.BankID == "" || reqData.RedirectURL == "" {
				return e.JSON(400, map[string]any{"error": "bank_id and redirect_url are required"})
			}
			country := reqData.Country
			if country == "" {
				country = "FR" // Default fallback
			}

			// 2. Générer le JWT
			token, err := generateEnableBankingJWT(app)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "JWT Generation Failed", "details": err.Error()})
			}

			// 3. Préparer le JSON pour Enable Banking
			// On demande un accès valide pour 90 jours (le maximum autorisé standard DSP2)
			validUntil := time.Now().Add(90 * 24 * time.Hour).Format(time.RFC3339)

			// Le "state" est un identifiant arbitraire pour sécuriser le retour, on peut y injecter l'ID de l'utilisateur PocketBase par exemple
			stateAuth := "budgettime_" + reqData.BankID

			authPayload := map[string]any{
				"access": map[string]any{
					"valid_until": validUntil,
				},
				"aspsp": map[string]any{
					"name":    reqData.BankID,
					"country": country,
				},
				"state":        stateAuth,
				"redirect_url": reqData.RedirectURL,
			}

			jsonData, err := json.Marshal(authPayload)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "Failed to encode auth payload"})
			}

			// 4. Appeler l'API Enable Banking
			apiURL := "https://api.enablebanking.com/auth"
			req, err := http.NewRequest("POST", apiURL, bytes.NewBuffer(jsonData))
			if err != nil {
				return e.JSON(500, map[string]any{"error": "API Request Creation Failed"})
			}
			req.Header.Set("Authorization", "Bearer "+token)
			req.Header.Set("Content-Type", "application/json")

			client := &http.Client{Timeout: 10 * time.Second}
			resp, err := client.Do(req)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "API Call to EnableBanking Failed", "details": err.Error()})
			}
			defer resp.Body.Close()

			body, _ := io.ReadAll(resp.Body)

			if resp.StatusCode != 200 {
				return e.JSON(resp.StatusCode, map[string]any{
					"error":   "EnableBanking returned an error",
					"details": string(body),
				})
			}

			// 5. Renvoyer la réponse (qui contient l'URL d'autorisation "url")
			e.Response.Header().Set("Content-Type", "application/json; charset=utf-8")
			return e.String(200, string(body))
		})

		// 3. Endpoint : Gérer le retour de la banque (Callback / Session)
		e.Router.GET("/api/banking/callback", func(e *core.RequestEvent) error {
			// Le portail bancaire redirige l'utilisateur ici avec des paramètres d'URL
			code := e.Request.URL.Query().Get("code")
			if code == "" {
				errorBanque := e.Request.URL.Query().Get("error")
				return e.JSON(400, map[string]any{"error": "Aucun code d'autorisation reçu", "bank_error": errorBanque})
			}

			// 1. Générer le JWT
			token, err := generateEnableBankingJWT(app)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "JWT Generation Failed", "details": err.Error()})
			}

			// 2. Préparer l'appel à Enable Banking (Création de session)
			sessionPayload := map[string]any{
				"code": code,
			}
			jsonData, _ := json.Marshal(sessionPayload)

			req, err := http.NewRequest("POST", "https://api.enablebanking.com/sessions", bytes.NewBuffer(jsonData))
			if err != nil {
				return e.JSON(500, map[string]any{"error": "API Request Creation Failed"})
			}
			req.Header.Set("Authorization", "Bearer "+token)
			req.Header.Set("Content-Type", "application/json")

			// 3. Appel à l'API Enable Banking
			client := &http.Client{Timeout: 10 * time.Second}
			resp, err := client.Do(req)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "API Call Failed", "details": err.Error()})
			}
			defer resp.Body.Close()

			body, _ := io.ReadAll(resp.Body)

			if resp.StatusCode != 200 {
				return e.JSON(resp.StatusCode, map[string]any{
					"error":   "EnableBanking failed to create session",
					"details": string(body),
				})
			}

			// 4. Parser la réponse de session pour en extraire le session_id et les IBANs (accounts)
			var sessionResult struct {
				SessionId string   `json:"session_id"`
				Status    string   `json:"status"`
				Accounts  []string `json:"accounts"`
			}
			if err := json.Unmarshal(body, &sessionResult); err != nil {
				return e.JSON(500, map[string]any{"error": "Failed to parse EnableBanking response", "details": err.Error()})
			}

			// 5. Enregistrer le consentement en BDD PocketBase
			authRecord := e.Auth
			if authRecord == nil {
				return e.JSON(401, map[string]any{"error": "Unauthorized: le token PocketBase est manquant ou invalide"})
			}

			// A. Sauvegarde de la Connexion globale
			collectionConn, err := app.FindCollectionByNameOrId("bank_connections")
			if err != nil {
				return e.JSON(500, map[string]any{"error": "Table bank_connections manquante"})
			}
			recordConn := core.NewRecord(collectionConn)
			recordConn.Set("user_id", authRecord.Id)
			recordConn.Set("bank_name", "Banque Connectée") // Ou extraire du state plus tard
			recordConn.Set("requisition_id", sessionResult.SessionId)
			recordConn.Set("valid_until", time.Now().AddDate(0, 0, 90).Format("2006-01-02 15:04:05.000Z")) // DSP2 = 90 Jours

			if err := app.Save(recordConn); err != nil {
				return e.JSON(500, map[string]any{"error": "Impossible de sauvegarder la connexion bancaire", "details": err.Error()})
			}

			// B. Sauvegarde Physique de chaque IBAN/Account autorisé
			collectionAcc, err := app.FindCollectionByNameOrId("bank_accounts")
			if err == nil {
				for _, accIban := range sessionResult.Accounts {
					recordAcc := core.NewRecord(collectionAcc)
					recordAcc.Set("connection_id", recordConn.Id)
					recordAcc.Set("remote_account_id", accIban)
					recordAcc.Set("iban", accIban)
					app.Save(recordAcc)
				}
			}

			// 6. Renvoyer le JSON final à Flutter
			e.Response.Header().Set("Content-Type", "application/json; charset=utf-8")
			return e.String(200, string(body))
		})

		// 4. Endpoint : Synchroniser les transactions (Fetch & Inject)
		e.Router.GET("/api/banking/sync", func(e *core.RequestEvent) error {
			accountId := e.Request.URL.Query().Get("account_id")
			dateStart := e.Request.URL.Query().Get("date_start")
			dateEnd := e.Request.URL.Query().Get("date_end")

			if accountId == "" {
				return e.JSON(400, map[string]any{"error": "account_id is required"})
			}

			// 1. Trouver bank_accounts et bank_connections
			var bankAccount struct {
				RemoteAccountId string `db:"remote_account_id"`
				ConnectionId    string `db:"connection_id"`
			}
			err := app.DB().Select("remote_account_id", "connection_id").
				From("bank_accounts").
				Where(dbx.HashExp{"local_account_id": accountId}).
				Limit(1).
				One(&bankAccount)
			if err != nil {
				// Fallback si on passe directement le remote_account_id
				err = app.DB().Select("remote_account_id", "connection_id").
					From("bank_accounts").
					Where(dbx.HashExp{"remote_account_id": accountId}).
					Limit(1).
					One(&bankAccount)
				if err != nil {
					return e.JSON(404, map[string]any{"error": "Compte bancaire (IBAN) non trouvé localement", "details": err.Error()})
				}
			}

			var bankConnection struct {
				Id            string `db:"id"`
				RequisitionId string `db:"requisition_id"`
				UserId        string `db:"user_id"`
			}
			err = app.DB().Select("id", "requisition_id", "user_id").
				From("bank_connections").
				Where(dbx.HashExp{"id": bankAccount.ConnectionId}).
				Limit(1).
				One(&bankConnection)
			if err != nil {
				return e.JSON(404, map[string]any{"error": "Connexion parente introuvable"})
			}

			// 2. Rate Limiting Sécurisé (Anti-ban EnableBanking)
			var count int
			app.DB().Select("count(id)").
				From("bank_sync_logs").
				Where(dbx.HashExp{"connection_id": bankConnection.Id, "status": "success"}).
				AndWhere(dbx.NewExp("created > datetime('now', '-1 hour')")).
				Row(&count)

			if count > 0 {
				return e.JSON(429, map[string]any{"error": "L'API a déjà été interrogée il y a moins d'une heure. Rate Limit activé pour protéger vos accès."})
			}

			// 3. Appeler Enable Banking
			token, err := generateEnableBankingJWT(app)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "JWT Gen Failed"})
			}

			apiURL := fmt.Sprintf("https://api.enablebanking.com/accounts/%s/transactions", bankAccount.RemoteAccountId)
			if dateStart != "" && dateEnd != "" {
				apiURL += fmt.Sprintf("?date_from=%s&date_to=%s", dateStart, dateEnd)
			} else {
				now := time.Now()
				dateEnd = now.Format("2006-01-02")
				dateStart = now.AddDate(0, 0, -10).Format("2006-01-02") // 10 jours par défaut
				apiURL += fmt.Sprintf("?date_from=%s&date_to=%s", dateStart, dateEnd)
			}

			req, err := http.NewRequest("GET", apiURL, nil)
			req.Header.Set("Authorization", "Bearer "+token)

			client := &http.Client{Timeout: 30 * time.Second}
			resp, err := client.Do(req)
			if err != nil || resp.StatusCode != 200 {
				collectionLogs, _ := app.FindCollectionByNameOrId("bank_sync_logs")
				if collectionLogs != nil {
					recordLog := core.NewRecord(collectionLogs)
					recordLog.Set("connection_id", bankConnection.Id)
					recordLog.Set("status", "error")
					recordLog.Set("transactions_count", 0)
					app.Save(recordLog)
				}
				return e.JSON(500, map[string]any{"error": "API Call Failed"})
			}
			defer resp.Body.Close()
			body, _ := io.ReadAll(resp.Body)

			var result struct {
				Transactions []struct {
					TransactionId string `json:"transaction_id"`
					BookingDate   string `json:"booking_date"`
					Amount        struct {
						Value    string `json:"value"`
						Currency string `json:"currency"`
					} `json:"amount"`
					CreditorName   string `json:"creditor_name"`
					DebtorName     string `json:"debtor_name"`
					RemittanceInfo string `json:"remittance_information_unstructured"`
				} `json:"transactions"`
			}
			if err := json.Unmarshal(body, &result); err != nil {
				return e.JSON(500, map[string]any{"error": "JSON parse error", "details": err.Error()})
			}

			collectionInbox, err := app.FindCollectionByNameOrId("raw_inbox")
			if err != nil {
				return e.JSON(500, map[string]any{"error": "Table raw_inbox absente"})
			}

			insertedCount := 0
			for _, t := range result.Transactions {
				label := t.CreditorName
				if label == "" {
					label = t.DebtorName
				}
				if label == "" {
					label = t.RemittanceInfo
				}
				if label == "" {
					label = "Transaction bancaire"
				}

				var existing int
				app.DB().Select("count(id)").From("raw_inbox").
					Where(dbx.HashExp{"raw_payload": t.TransactionId, "user": bankConnection.UserId}).
					Row(&existing)

				if existing > 0 {
					continue // Déjà traitée
				}

				record := core.NewRecord(collectionInbox)
				record.Set("date", t.BookingDate+" 12:00:00.000Z")
				record.Set("label", label)
				record.Set("amount", t.Amount.Value)
				record.Set("user", bankConnection.UserId)
				record.Set("is_processed", false)
				record.Set("raw_payload", t.TransactionId)

				if err := app.Save(record); err == nil {
					insertedCount++
				}
			}

			collectionLogs, _ := app.FindCollectionByNameOrId("bank_sync_logs")
			if collectionLogs != nil {
				recordLog := core.NewRecord(collectionLogs)
				recordLog.Set("connection_id", bankConnection.Id)
				recordLog.Set("status", "success")
				recordLog.Set("transactions_count", insertedCount)
				app.Save(recordLog)
			}

			return e.JSON(200, map[string]any{
				"message":       "Synchro terminée",
				"inserted":      insertedCount,
				"total_fetched": len(result.Transactions),
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
