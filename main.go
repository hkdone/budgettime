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
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/plugins/jsvm"
)

// getBankSettings récupère les réglages Enable Banking pour un utilisateur donné
// Désormais, il ignore la base de données et se base sur le dossier secrets
func getBankSettings(app *pocketbase.PocketBase) (appId, privateKey string, err error) {
	// Chercher les fichiers .pem dans le dossier secrets (à côté de pb_data)
	baseDir := filepath.Dir(app.DataDir())
	secretsDir := filepath.Join(baseDir, "secrets")

	files, err := os.ReadDir(secretsDir)
	if err != nil {
		return "", "", fmt.Errorf("impossible de lire le dossier secrets: %w", err)
	}

	for _, f := range files {
		if !f.IsDir() && filepath.Ext(f.Name()) == ".pem" {
			// L'App ID est le nom du fichier sans .pem
			appId = f.Name()[0 : len(f.Name())-4]
			keyPath := filepath.Join(secretsDir, f.Name())
			bytes, err := os.ReadFile(keyPath)
			if err == nil {
				privateKey = string(bytes)
				return appId, privateKey, nil
			}
		}
	}

	return "", "", fmt.Errorf("aucune clé .pem trouvée dans %s", secretsDir)
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
		fmt.Println("[BudgetTime] Initialisation des routes banking...")

		// Diagnostic au démarrage : Vérifier si les collections bancaires existent
		collectionsToCheck := []string{"raw_inbox"}
		for _, name := range collectionsToCheck {
			_, err := app.FindCollectionByNameOrId(name)
			if err != nil {
				fmt.Printf("[BudgetTime] INFO: Collection '%s' absente (Optionnel)\n", name)
			} else {
				fmt.Printf("[BudgetTime] Collection '%s' active\n", name)
			}
		}

		// Créer un groupe pour toutes les routes banking et exiger une authentification
		// apis.RequireAuth() charge également le contexte d'authentification s'il est présent
		banking := e.Router.Group("/api/banking").Bind(apis.RequireAuth())

		// Endpoint : Générer un JWT pour Enable Banking
		banking.GET("/jwt", func(e *core.RequestEvent) error {
			if e.Auth == nil {
				fmt.Println("[BudgetTime] Erreur: e.Auth est nil dans /jwt")
				return e.Error(401, "Accès refusé: authentification PocketBase manquante", nil)
			}
			userId := e.Auth.Id
			fmt.Printf("[BudgetTime] /jwt demandé par userId: %s\n", userId)
			appId, privateKey, err := getBankSettings(app)
			if err != nil {
				return e.JSON(200, map[string]any{
					"token":          "",
					"config_missing": true,
					"message":        err.Error(),
				})
			}
			token, err := generateEnableBankingJWT(appId, privateKey)
			if err != nil {
				return e.JSON(500, map[string]any{"error": err.Error()})
			}
			return e.JSON(200, map[string]string{
				"token": token,
			})
		})

		// Endpoint : Récupérer les réglages Enable Banking
		banking.GET("/settings", func(e *core.RequestEvent) error {
			if e.Auth == nil {
				fmt.Println("[BudgetTime] Erreur: e.Auth est nil dans GET /settings")
				return e.Error(401, "Authentification obligatoire", nil)
			}
			userId := e.Auth.Id
			fmt.Printf("[BudgetTime] GET /settings pour userId: %s\n", userId)
			appId, privateKey, err := getBankSettings(app)
			hasKey := err == nil && privateKey != ""
			return e.JSON(200, map[string]any{
				"app_id":  appId,
				"has_key": hasKey,
			})
		})

		// Endpoint : "Sauvegarder" les réglages (Désormais informatif car géré par fichiers)
		banking.POST("/settings", func(e *core.RequestEvent) error {
			if e.Auth == nil {
				return e.Error(401, "Authentification obligatoire", nil)
			}
			// On ne sauvegarde plus rien en base. L'utilisateur doit mettre le fichier .pem manuellement.
			return e.JSON(200, map[string]string{
				"message": "Note: Les réglages sont désormais gérés par fichiers .pem dans le dossier /pb/secrets du serveur.",
			})
		})

		// Endpoint : Récupérer la liste des banques (ASPSPs)
		banking.GET("/aspsps", func(e *core.RequestEvent) error {
			if e.Auth == nil {
				return e.Error(401, "Auth record missing (ASPSPs)", nil)
			}
			country := e.Request.URL.Query().Get("country")
			if country == "" {
				country = "FR"
			}
			appId, privateKey, err := getBankSettings(app)
			if err != nil {
				return e.JSON(200, map[string]any{
					"aspsps":         []any{},
					"config_missing": true,
					"message":        "Fichier .pem manquant dans /secrets",
				})
			}
			token, err := generateEnableBankingJWT(appId, privateKey)

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
			if e.Auth == nil {
				return e.Error(401, "Auth record missing (Discover)", nil)
			}
			// On ne peut plus discover via une session_id globale car elle n'est plus stockée.
			// L'UI devra passer par une liste de connexions déjà stockées dans bank_connections.
			return e.JSON(200, map[string]any{
				"message": "Discovery (Sessions) désactivé. Utilisez la liste des connexions enregistrées.",
				"found":   0,
				"added":   0,
			})
		})

		// Endpoint : Demander un lien d'autorisation
		banking.POST("/auth", func(e *core.RequestEvent) error {
			if e.Auth == nil {
				return e.Error(401, "Auth record missing (Auth URL)", nil)
			}
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
			appId, privateKey, err := getBankSettings(app)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "Fichier .pem manquant", "details": err.Error()})
			}
			token, err := generateEnableBankingJWT(appId, privateKey)

			validUntil := time.Now().Add(90 * 24 * time.Hour).Format(time.RFC3339)
			stateAuth := fmt.Sprintf("bt_%s_%s", userId, reqData.BankID)
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

		// Endpoint : Callback de la banque (Public car c'est une redirection externe)
		e.Router.GET("/api/banking/callback", func(e *core.RequestEvent) error {
			code := e.Request.URL.Query().Get("code")
			if code == "" {
				errorBanque := e.Request.URL.Query().Get("error")
				return e.JSON(400, map[string]any{"error": "Aucun code d'autorisation reçu", "bank_error": errorBanque})
			}

			state := e.Request.URL.Query().Get("state")
			userId := ""

			if len(state) > 3 && strings.HasPrefix(state, "bt_") {
				partsArray := strings.Split(state, "_")
				if len(partsArray) >= 2 {
					userId = partsArray[1]
				}
			}

			if userId == "" {
				// Fallback si l'auth est quand même présente (test direct)
				if auth := e.Auth; auth != nil {
					userId = auth.Id
				}
			}
			appId, privateKey, err := getBankSettings(app)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "Fichier .pem manquant", "details": err.Error()})
			}
			token, err := generateEnableBankingJWT(appId, privateKey)

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
				SessionId string `json:"session_id"`
				Status    string `json:"status"`
				Accounts  []struct {
					Uid string `json:"uid"`
				} `json:"accounts"`
			}
			if err := json.Unmarshal(body, &sessionResult); err != nil {
				return e.JSON(500, map[string]any{"error": "Failed to parse EnableBanking response", "details": err.Error()})
			}

			// On ne sauvegarde plus la session_id en base dans bank_settings.
			// Elle sera découverte via /discover si besoin, ou passée par env var.

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
				for _, acc := range sessionResult.Accounts {
					recordAcc := core.NewRecord(collectionAcc)
					recordAcc.Set("connection_id", recordConn.Id)
					recordAcc.Set("remote_account_id", acc.Uid)
					recordAcc.Set("iban", acc.Uid)
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

			appId, privateKey, err := getBankSettings(app)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "Fichier .pem manquant"})
			}
			token, err := generateEnableBankingJWT(appId, privateKey)

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
