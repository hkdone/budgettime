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

			// Récupérer les sessions détaillées
			type sessionInfo struct {
				Id            string `json:"id"`
				RequisitionId string `json:"requisition_id"`
				BankName      string `json:"bank_name"`
				ValidUntil    string `json:"valid_until"`
			}
			sessionDetails := []sessionInfo{}
			app.DB().Select("id", "requisition_id", "bank_name", "valid_until").
				From("bank_connections").
				Where(dbx.HashExp{"user": userId}).
				All(&sessionDetails)

			return e.JSON(200, map[string]any{
				"app_id":   appId,
				"has_key":  hasKey,
				"sessions": sessionDetails,
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

		// Endpoint : Supprimer une connexion bancaire (session)
		banking.DELETE("/sessions/{id}", func(e *core.RequestEvent) error {
			if e.Auth == nil {
				return e.Error(401, "Auth missing", nil)
			}
			id := e.Request.PathValue("id")
			record, err := app.FindRecordById("bank_connections", id)
			if err != nil {
				return e.JSON(404, map[string]any{"error": "Session introuvable"})
			}
			if record.GetString("user") != e.Auth.Id {
				return e.JSON(403, map[string]any{"error": "Accès refusé"})
			}

			// Optionnel : Supprimer aussi les comptes associés ?
			// Probablement oui pour garder propre.
			app.DB().Delete("bank_accounts", dbx.HashExp{"connection_id": id}).Execute()

			if err := app.Delete(record); err != nil {
				return e.JSON(500, map[string]any{"error": "Échec de suppression", "details": err.Error()})
			}
			return e.JSON(200, map[string]any{"message": "Session supprimée"})
		})

		// Endpoint : Découvrir les liaisons existantes
		banking.GET("/discover", func(e *core.RequestEvent) error {
			if e.Auth == nil {
				return e.Error(401, "Auth record missing (Discover)", nil)
			}
			userId := e.Auth.Id
			appId, privateKey, err := getBankSettings(app)
			if err != nil {
				return e.JSON(500, map[string]any{"error": "Fichier .pem manquant"})
			}
			token, err := generateEnableBankingJWT(appId, privateKey)

			// 1. Lister les connexions de l'utilisateur
			var connections []struct {
				Id            string `db:"id"`
				RequisitionId string `db:"requisition_id"`
				BankName      string `db:"bank_name"`
			}
			err = app.DB().Select("id", "requisition_id", "bank_name").
				From("bank_connections").
				Where(dbx.HashExp{"user": userId}).
				All(&connections)

			if err != nil {
				return e.JSON(200, map[string]any{"found": 0, "added": 0, "message": "Aucune connexion trouvée en base"})
			}

			client := &http.Client{Timeout: 10 * time.Second}
			collectionAcc, _ := app.FindCollectionByNameOrId("bank_accounts")
			totalAdded := 0

			for _, conn := range connections {
				req, _ := http.NewRequest("GET", "https://api.enablebanking.com/accounts", nil)
				req.Header.Set("Authorization", "Bearer "+token)
				// Passage de la session via query ou header selon l'API. Enable Banking utilise souvent le Bearer Token qui représente la session si c'est un token d'accès temporaire,
				// MAIS ici on utilise un JWT Application. Donc on doit passer la session dans l'URL ou un header spécifique.
				// Selon la doc Enable Banking, pour lister les comptes d'une session : GET /accounts avec le header Authorization: Bearer <session_jwt>
				// Cependant, nous utilisons un JWT d'application. Pour accéder aux comptes d'une session spécifique,
				// il faut parfois un token de session. Mais l'API permet aussi d'utiliser le JWT App avec le context.
				// Correction : Utilisons l'URL avec session_id si possible ou le header X-Session-Id si supporté (à vérifier).
				// Plus simple avec Enable Banking : GET /accounts?session_id=...
				q := req.URL.Query()
				q.Add("session_id", conn.RequisitionId)
				req.URL.RawQuery = q.Encode()

				resp, err := client.Do(req)
				if err != nil || resp.StatusCode != 200 {
					continue
				}
				defer resp.Body.Close()

				var accResult struct {
					Accounts []struct {
						Uid      string `json:"uid"`
						Iban     string `json:"iban"`
						Bban     string `json:"bban"`
						Name     string `json:"name"`
						Currency string `json:"currency"`
					} `json:"accounts"`
				}
				body, _ := io.ReadAll(resp.Body)
				json.Unmarshal(body, &accResult)

				for _, acc := range accResult.Accounts {
					// Vérifier si le compte existe déjà
					var exists int
					app.DB().Select("count(*)").From("bank_accounts").
						Where(dbx.HashExp{"remote_account_id": acc.Uid}).Row(&exists)

					if exists == 0 && collectionAcc != nil {
						recordAcc := core.NewRecord(collectionAcc)
						recordAcc.Set("connection_id", conn.Id)
						recordAcc.Set("remote_account_id", acc.Uid)
						// Priorité IBAN > BBAN > (Banque + Name) > UID
						displayLabel := acc.Iban
						if displayLabel == "" {
							displayLabel = acc.Bban
						}
						if displayLabel == "" {
							displayLabel = conn.BankName
							if acc.Name != "" {
								displayLabel += " - " + acc.Name
							}
							if acc.Uid != "" {
								displayLabel += " (" + acc.Uid[:8] + ")"
							}
						}
						recordAcc.Set("iban", displayLabel)
						if err := app.Save(recordAcc); err == nil {
							totalAdded++
						}
					}
				}
			}

			return e.JSON(200, map[string]any{
				"found":   len(connections),
				"added":   totalAdded,
				"message": fmt.Sprintf("Découverte terminée : %d liaisons trouvées, %d nouveaux comptes ajoutés.", len(connections), totalAdded),
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
			fmt.Printf("[BudgetTime] Callback reçu - state: %s, code: %s\n", state, code)
			userId := ""

			bankName := "Banque Connectée"
			if len(state) > 3 && strings.HasPrefix(state, "bt_") {
				partsArray := strings.Split(state, "_")
				if len(partsArray) >= 2 {
					userId = partsArray[1]
				}
				if len(partsArray) >= 3 {
					bankName = strings.ReplaceAll(partsArray[2], "+", " ")
				}
			}

			if userId == "" {
				// Fallback si l'auth est quand même présente (test direct)
				if auth := e.Auth; auth != nil {
					userId = auth.Id
				}
			}
			fmt.Printf("[BudgetTime] Identification utilisateur callback : %s\n", userId)
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
					Uid      string `json:"uid"`
					Iban     string `json:"iban"`
					Bban     string `json:"bban"`
					Name     string `json:"name"`
					Currency string `json:"currency"`
				} `json:"accounts"`
			}
			if err := json.Unmarshal(body, &sessionResult); err != nil {
				return e.JSON(500, map[string]any{"error": "Failed to parse EnableBanking response", "details": err.Error()})
			}

			// On ne sauvegarde plus la session_id en base dans bank_settings.
			// Elle sera découverte via /discover si besoin, ou passée par env var.

			collectionConn, err := app.FindCollectionByNameOrId("bank_connections")
			if err != nil {
				fmt.Printf("[BudgetTime] Erreur : Table bank_connections introuvable\n")
				return e.JSON(500, map[string]any{"error": "Table bank_connections manquante"})
			}
			recordConn := core.NewRecord(collectionConn)
			recordConn.Set("user", userId)
			recordConn.Set("bank_name", bankName)
			recordConn.Set("requisition_id", sessionResult.SessionId)
			recordConn.Set("valid_until", time.Now().AddDate(0, 0, 90).Format("2006-01-02 15:04:05.000Z"))

			if err := app.Save(recordConn); err != nil {
				fmt.Printf("[BudgetTime] Erreur sauvegarde connexion: %v\n", err)
				return e.JSON(500, map[string]any{"error": "Impossible de sauvegarder la connexion bancaire", "details": err.Error()})
			}
			fmt.Printf("[BudgetTime] Connexion bancaire sauvegardée ID: %s\n", recordConn.Id)

			compteCount := 0
			collectionAcc, err := app.FindCollectionByNameOrId("bank_accounts")
			if err == nil {
				for _, acc := range sessionResult.Accounts {
					if acc.Uid == "" {
						continue
					}
					recordAcc := core.NewRecord(collectionAcc)
					recordAcc.Set("connection_id", recordConn.Id)
					recordAcc.Set("remote_account_id", acc.Uid)
					displayLabel := acc.Iban
					if displayLabel == "" {
						displayLabel = acc.Bban
					}
					if displayLabel == "" {
						displayLabel = acc.Name
					}
					if displayLabel == "" {
						displayLabel = acc.Uid
					}
					// If it still looks like a technical ID but we have a bank name, prefix it
					if (displayLabel == "" || (strings.Contains(displayLabel, "-") && len(displayLabel) > 20)) && bankName != "" {
						displayLabel = bankName + " (" + acc.Uid[:8] + ")"
					}

					recordAcc.Set("iban", displayLabel)
					if err := app.Save(recordAcc); err == nil {
						compteCount++
					}
				}
			}
			fmt.Printf("[BudgetTime] %d comptes sauvegardés (Total détectés: %d)\n", compteCount, len(sessionResult.Accounts))

			// Rediriger vers l'application au lieu d'afficher du JSON
			return e.Redirect(302, "/")
		})

		// Endpoint : Synchronisation des transactions
		banking.GET("/sync", func(e *core.RequestEvent) error {
			accountId := e.Request.URL.Query().Get("account_id")
			dateStart := e.Request.URL.Query().Get("date_start")
			dateEnd := e.Request.URL.Query().Get("date_end")

			fmt.Printf("[BudgetTime] Lancement Sync pour compte: %s\n", accountId)

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
			// AJOUT INDISPENSABLE : session_id
			qParams := ""
			if dateStart != "" && dateEnd != "" {
				qParams = fmt.Sprintf("date_from=%s&date_to=%s", dateStart, dateEnd)
			} else {
				now := time.Now()
				dateEnd = now.Format("2006-01-02")
				dateStart = now.AddDate(0, 0, -30).Format("2006-01-02") // 30 jours par défaut
				qParams = fmt.Sprintf("date_from=%s&date_to=%s", dateStart, dateEnd)
			}
			apiURL += "?" + qParams + "&session_id=" + bankConnection.RequisitionId

			fmt.Printf("[BudgetTime] Appel EnableBanking Sync API: %s\n", apiURL)
			req, err := http.NewRequest("GET", apiURL, nil)
			req.Header.Set("Authorization", "Bearer "+token)

			client := &http.Client{Timeout: 45 * time.Second} // Timeout plus généreu pour le sync
			resp, err := client.Do(req)
			if err != nil {
				fmt.Printf("[BudgetTime] Erreur Réseau Sync: %v\n", err)
				return e.JSON(500, map[string]any{"error": "Sync Network Error", "details": err.Error()})
			}
			defer resp.Body.Close()

			body, _ := io.ReadAll(resp.Body)
			fmt.Printf("[BudgetTime] Réponse Sync Status: %d\n", resp.StatusCode)

			if resp.StatusCode != 200 {
				collectionLogs, _ := app.FindCollectionByNameOrId("bank_sync_logs")
				if collectionLogs != nil {
					recordLog := core.NewRecord(collectionLogs)
					recordLog.Set("connection_id", bankConnection.Id)
					recordLog.Set("status", "error")
					app.Save(recordLog)
				}
				return e.JSON(resp.StatusCode, map[string]any{"error": "EnableBanking returns error", "details": string(body)})
			}

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
				fmt.Printf("[BudgetTime] Erreur Unmarshal Sync: %v\n", err)
				return e.JSON(500, map[string]any{"error": "Failed to parse transactions", "details": err.Error()})
			}

			if len(result.Transactions) == 0 {
				fmt.Printf("[BudgetTime] EnableBanking a renvoyé 0 transactions pour cette période. Corps brut: %s\n", string(body))
			}

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

			fmt.Printf("[BudgetTime] Sync fini: %d transactions reçues, %d nouvelles insérées.\n", len(result.Transactions), insertedCount)

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
