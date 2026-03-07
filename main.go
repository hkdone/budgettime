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

// getBankSettings récupère les réglages Enable Banking pour un utilisateur donné
func getBankSettings(app *pocketbase.PocketBase, userId string) (appId, privateKey, sessionId string, err error) {
	record, err := app.FindFirstRecordByFilter("bank_settings", "user = {:userId}", dbx.Params{"userId": userId})
	if err == nil && record != nil {
		return record.GetString("app_id"), record.GetString("private_key"), record.GetString("session_id"), nil
	}

	// Fallback sur les variables d'environnement si non trouvé en base (pour rétrocompatibilité)
	appId = os.Getenv("ENABLE_BANKING_APP_ID")
	sessionId = os.Getenv("ENABLE_BANKING_SESSION_ID")

	if envKey := os.Getenv("ENABLE_BANKING_PRIVATE_KEY"); envKey != "" {
		privateKey = envKey
	} else if appId != "" {
		// Chercher le fichier .pem par défaut
		baseDir := filepath.Dir(app.DataDir())
		keyPath := filepath.Join(baseDir, "secrets", fmt.Sprintf("%s.pem", appId))
		bytes, err := os.ReadFile(keyPath)
		if err == nil {
			privateKey = string(bytes)
		}
	}

	return appId, privateKey, sessionId, nil
}

// generateEnableBankingJWT génère un JWT à partir des identifiants fournis
func generateEnableBankingJWT(appId, privateKeyPEM string) (string, error) {
	if appId == "" || privateKeyPEM == "" {
		return "", fmt.Errorf("Enable Banking App ID or Private Key is missing")
	}

	// 1. Parser la clé RSA
	privateKey, err := jwt.ParseRSAPrivateKeyFromPEM([]byte(privateKeyPEM))
	if err != nil {
		return "", fmt.Errorf("failed to parse RSA private key: %w", err)
	}

	// 2. Créer le contenu du JWT (Claims)
	now := time.Now()
	claims := jwt.MapClaims{
		"iss": "enablebanking.com",
		"aud": "api.enablebanking.com",
		"iat": now.Unix(),
		"exp": now.Add(1 * time.Hour).Unix(),
	}

	// 3. Créer et signer le Token
	token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	token.Header["alg"] = "RS256"
	token.Header["typ"] = "JWT"
	token.Header["kid"] = appId

	signedToken, err := token.SignedString(privateKey)
	if err != nil {
		return "", fmt.Errorf("failed to sign JWT: %w", err)
	}

	return signedToken, nil
}

func main() {
	app := pocketbase.New()

	jsvm.MustRegister(app, jsvm.Config{})

	// Exposition des endpoints Enable Banking
	app.OnServe().BindFunc(func(e *core.ServeEvent) error {
		// Créer un groupe pour toutes les routes banking et exiger une authentification
		// apis.RequireAuth() charge également le contexte d'authentification s'il est présent
		banking := e.Router.Group("/api/banking").Bind(apis.RequireAuth())

		// Endpoint : Générer un JWT pour Enable Banking
		banking.GET("/jwt", func(e *core.RequestEvent) error {
			userId := e.Auth.Id
			appId, privateKey, _, _ := getBankSettings(app, userId)
			token, err := generateEnableBankingJWT(appId, privateKey)
			if err != nil {
				return e.Error(500, "JWT Generation Failed", err)
			}
			return e.JSON(200, map[string]string{
				"token": token,
			})
		})

		// Endpoint : Récupérer les réglages Enable Banking
		banking.GET("/settings", func(e *core.RequestEvent) error {
			userId := e.Auth.Id
			appId, privateKey, sessionId, _ := getBankSettings(app, userId)
			return e.JSON(200, map[string]any{
				"app_id":      appId,
				"has_key":     privateKey != "",
				"session_id":  sessionId,
				"private_key": privateKey,
			})
		})

		// Endpoint : Sauvegarder les réglages Enable Banking
		banking.POST("/settings", func(e *core.RequestEvent) error {
			userId := e.Auth.Id
			var data struct {
				AppId      string `json:"app_id"`
				PrivateKey string `json:"private_key"`
				SessionId  string `json:"session_id"`
			}
			if err := e.BindBody(&data); err != nil {
				return e.Error(400, "Invalid body", err)
			}

			collection, _ := app.FindCollectionByNameOrId("bank_settings")
			record, _ := app.FindFirstRecordByFilter("bank_settings", "user = {:userId}", dbx.Params{"userId": userId})
			if record == nil {
				record = core.NewRecord(collection)
				record.Set("user", userId)
			}
			if data.AppId != "" {
				record.Set("app_id", data.AppId)
			}
			if data.PrivateKey != "" {
				record.Set("private_key", data.PrivateKey)
			}
			if data.SessionId != "" {
				record.Set("session_id", data.SessionId)
			}

			if err := app.Save(record); err != nil {
				return e.Error(500, "Failed to save settings", err)
			}
			return e.JSON(200, map[string]string{"message": "Settings saved"})
		})

		// Endpoint : Récupérer la liste des banques (ASPSPs)
		banking.GET("/aspsps", func(e *core.RequestEvent) error {
			country := e.Request.URL.Query().Get("country")
			if country == "" {
				country = "FR"
			}
			userId := e.Auth.Id
			appId, privateKey, _, _ := getBankSettings(app, userId)
			token, err := generateEnableBankingJWT(appId, privateKey)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "JWT Generation Failed", "details": err.Error()})
			}

			apiURL := "https://api.enablebanking.com/aspsps?country=" + country
			req, err := http.NewRequest("GET", apiURL, nil)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "API Request Creation Failed"})
			}
			req.Header.Set("Authorization", "Bearer "+token)

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
			e.Response.Header().Set("Content-Type", "application/json; charset=utf-8")
			return e.String(200, string(body))
		})

		// Endpoint : Découvrir les liaisons existantes
		banking.GET("/discover", func(e *core.RequestEvent) error {
			userId := e.Auth.Id
			appId, privateKey, sessionID, _ := getBankSettings(app, userId)
			token, err := generateEnableBankingJWT(appId, privateKey)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "Failed to generate JWT", "details": err.Error()})
			}
			if sessionID == "" {
				return e.JSON(404, map[string]any{
					"error":      "No Session ID configured",
					"suggestion": "Merci de configurer votre Application ID et de lier votre banque via l'UI.",
				})
			}

			apiURL := "https://api.enablebanking.com/sessions/" + sessionID
			req, err := http.NewRequest("GET", apiURL, nil)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "Failed to create request"})
			}
			req.Header.Set("Authorization", "Bearer "+token)

			client := &http.Client{}
			resp, err := client.Do(req)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "Failed to call Enable Banking API"})
			}
			defer resp.Body.Close()

			if resp.StatusCode != 200 {
				body, _ := io.ReadAll(resp.Body)
				return e.JSON(resp.StatusCode, map[string]any{
					"error":   "Enable Banking API error (Session not found)",
					"details": string(body),
				})
			}

			var sessionData map[string]any
			if err := json.NewDecoder(resp.Body).Decode(&sessionData); err != nil {
				return e.JSON(500, map[string]any{"error": "Failed to parse session data"})
			}

			requisitions := []map[string]any{sessionData}
			addedCount := syncSessions(app, e, requisitions)

			return e.JSON(200, map[string]any{
				"message": "Discovery complete",
				"added":   addedCount,
			})
		})

		// Endpoint : Demander un lien d'autorisation
		banking.POST("/auth", func(e *core.RequestEvent) error {
			var reqData struct {
				BankID      string `json:"bank_id"`
				Country     string `json:"country"`
				RedirectURL string `json:"redirect_url"`
			}
			if err := e.BindBody(&reqData); err != nil {
				return e.JSON(400, map[string]any{"error": "Invalid request body", "details": err.Error()})
			}
			if reqData.BankID == "" || reqData.RedirectURL == "" {
				return e.JSON(400, map[string]any{"error": "bank_id and redirect_url are required"})
			}
			country := reqData.Country
			if country == "" {
				country = "FR"
			}

			userId := e.Auth.Id
			appId, privateKey, _, _ := getBankSettings(app, userId)
			token, err := generateEnableBankingJWT(appId, privateKey)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "JWT Generation Failed", "details": err.Error()})
			}

			validUntil := time.Now().Add(90 * 24 * time.Hour).Format(time.RFC3339)
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

			jsonData, _ := json.Marshal(authPayload)
			fmt.Printf("[EnableBanking] Auth Request Payload: %s\n", string(jsonData))

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
			e.Response.Header().Set("Content-Type", "application/json; charset=utf-8")
			return e.String(200, string(body))
		})

		// Endpoint : Callback de la banque
		banking.GET("/callback", func(e *core.RequestEvent) error {
			code := e.Request.URL.Query().Get("code")
			if code == "" {
				errorBanque := e.Request.URL.Query().Get("error")
				return e.JSON(400, map[string]any{"error": "Aucun code d'autorisation reçu", "bank_error": errorBanque})
			}

			userId := ""
			if auth := e.Auth; auth != nil {
				userId = auth.Id
			}
			appId, privateKey, _, _ := getBankSettings(app, userId)
			token, err := generateEnableBankingJWT(appId, privateKey)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "JWT Generation Failed", "details": err.Error()})
			}

			sessionPayload := map[string]any{"code": code}
			jsonData, _ := json.Marshal(sessionPayload)
			req, err := http.NewRequest("POST", "https://api.enablebanking.com/sessions", bytes.NewBuffer(jsonData))
			if err != nil {
				return e.JSON(500, map[string]any{"error": "API Request Creation Failed"})
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
			if resp.StatusCode != 200 {
				return e.JSON(resp.StatusCode, map[string]any{
					"error":   "EnableBanking failed to create session",
					"details": string(body),
				})
			}

			var sessionResult struct {
				SessionId string   `json:"session_id"`
				Status    string   `json:"status"`
				Accounts  []string `json:"accounts"`
			}
			if err := json.Unmarshal(body, &sessionResult); err != nil {
				return e.JSON(500, map[string]any{"error": "Failed to parse EnableBanking response", "details": err.Error()})
			}

			if userId != "" {
				collectionSettings, _ := app.FindCollectionByNameOrId("bank_settings")
				recordSet, _ := app.FindFirstRecordByFilter("bank_settings", "user = {:userId}", dbx.Params{"userId": userId})
				if recordSet == nil {
					recordSet = core.NewRecord(collectionSettings)
					recordSet.Set("user", userId)
				}
				recordSet.Set("session_id", sessionResult.SessionId)
				app.Save(recordSet)
			}

			collectionConn, err := app.FindCollectionByNameOrId("bank_connections")
			if err != nil {
				return e.JSON(500, map[string]any{"error": "Table bank_connections manquante"})
			}
			recordConn := core.NewRecord(collectionConn)
			recordConn.Set("user", userId)
			recordConn.Set("bank_name", "Banque Connectée")
			recordConn.Set("requisition_id", sessionResult.SessionId)
			recordConn.Set("valid_until", time.Now().AddDate(0, 0, 90).Format("2006-01-02 15:04:05.000Z"))

			if err := app.Save(recordConn); err != nil {
				return e.JSON(500, map[string]any{"error": "Impossible de sauvegarder la connexion bancaire", "details": err.Error()})
			}

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

			e.Response.Header().Set("Content-Type", "application/json; charset=utf-8")
			return e.String(200, string(body))
		})

		// Endpoint : Synchronisation des transactions
		banking.GET("/sync", func(e *core.RequestEvent) error {
			accountId := e.Request.URL.Query().Get("account_id")
			dateStart := e.Request.URL.Query().Get("date_start")
			dateEnd := e.Request.URL.Query().Get("date_end")

			if accountId == "" {
				return e.JSON(400, map[string]any{"error": "account_id is required"})
			}

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
				err = app.DB().Select("remote_account_id", "connection_id").
					From("bank_accounts").
					Where(dbx.HashExp{"remote_account_id": accountId}).
					Limit(1).
					One(&bankAccount)
				if err != nil {
					return e.JSON(404, map[string]any{"error": "Compte bancaire non trouvé localement"})
				}
			}

			var bankConnection struct {
				Id            string `db:"id"`
				RequisitionId string `db:"requisition_id"`
				UserId        string `db:"user"`
			}
			err = app.DB().Select("id", "requisition_id", "user").
				From("bank_connections").
				Where(dbx.HashExp{"id": bankAccount.ConnectionId}).
				Limit(1).
				One(&bankConnection)
			if err != nil {
				return e.JSON(404, map[string]any{"error": "Connexion parente introuvable"})
			}

			var count int
			app.DB().Select("count(id)").From("bank_sync_logs").
				Where(dbx.HashExp{"connection_id": bankConnection.Id, "status": "success"}).
				AndWhere(dbx.NewExp("created > datetime('now', '-1 hour')")).
				Row(&count)

			if count > 0 {
				return e.JSON(429, map[string]any{"error": "Rate limit: une synchro par heure maximum"})
			}

			userId := e.Auth.Id
			appId, privateKey, _, _ := getBankSettings(app, userId)
			token, err := generateEnableBankingJWT(appId, privateKey)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "JWT Gen Failed"})
			}

			apiURL := fmt.Sprintf("https://api.enablebanking.com/accounts/%s/transactions", bankAccount.RemoteAccountId)
			if dateStart != "" && dateEnd != "" {
				apiURL += fmt.Sprintf("?date_from=%s&date_to=%s", dateStart, dateEnd)
			} else {
				now := time.Now()
				dateEnd = now.Format("2006-01-02")
				dateStart = now.AddDate(0, 0, -10).Format("2006-01-02")
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
			json.Unmarshal(body, &result)

			collectionInbox, _ := app.FindCollectionByNameOrId("raw_inbox")
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

				if existing == 0 {
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
				"inserted": insertedCount,
				"message":  "Synchro effectuée",
			})
		})

		// Servir le Frontend Web
		publicDir := filepath.Join(filepath.Dir(app.DataDir()), "pb_public")
		e.Router.GET("/{path...}", apis.Static(os.DirFS(publicDir), false))

		return e.Next()
	})

	if err := app.Start(); err != nil {
		log.Fatal(err)
	}
}

// syncSessions est une fonction utilitaire pour synchroniser les requisitions/sessions reçues avec PocketBase
func syncSessions(app *pocketbase.PocketBase, e *core.RequestEvent, requisitions []map[string]any) int {
	collection, err := app.FindCollectionByNameOrId("bank_connections")
	if err != nil {
		fmt.Printf("Erreur : collection 'bank_connections' non trouvée\n")
		return 0
	}

	userId := ""
	if authRecord := e.Auth; authRecord != nil {
		userId = authRecord.Id
	}

	addedCount := 0
	for _, reqData := range requisitions {
		reqId, _ := reqData["id"].(string)
		if reqId == "" {
			continue
		}

		// Vérifier si elle existe déjà
		existing, _ := app.FindFirstRecordByFilter("bank_connections", "requisition_id = {:id}", dbx.Params{"id": reqId})
		if existing == nil {
			// Créer une nouvelle liaison
			record := core.NewRecord(collection)
			record.Set("requisition_id", reqId)
			record.Set("user", userId)
			record.Set("bank_name", reqData["aspsp_id"])
			record.Set("status", reqData["status"])
			if err := app.Save(record); err == nil {
				addedCount++
			}
		} else if reqData["status"] != nil {
			// Mettre à jour le statut si session trouvée
			existing.Set("status", reqData["status"])
			app.Save(existing)
		}
	}
	return addedCount
}
