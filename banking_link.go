package main

import (
	"fmt"
	"strings"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase"
	"github.com/pocketbase/pocketbase/core"
)

// enableBankAccount représente un compte renvoyé par l'API Enable Banking.
type enableBankAccount struct {
	Uid       string `json:"uid"`
	AccountId struct {
		Iban string `json:"iban"`
		Bban string `json:"bban"`
	} `json:"account_id"`
	AllAccountIds []struct {
		Identification string `json:"identification"`
		SchemeName     string `json:"scheme_name"`
	} `json:"all_account_ids"`
	Name     string `json:"name"`
	Currency string `json:"currency"`
}

func normalizeIban(iban string) string {
	return strings.ReplaceAll(strings.ToUpper(strings.TrimSpace(iban)), " ", "")
}

func extractIbanFromEnableAccount(acc enableBankAccount) string {
	ibanValue := acc.AccountId.Iban
	if ibanValue == "" {
		ibanValue = acc.AccountId.Bban
	}
	if ibanValue == "" {
		for _, alt := range acc.AllAccountIds {
			if alt.SchemeName == "IBAN" || alt.SchemeName == "BBAN" {
				ibanValue = alt.Identification
				break
			}
		}
	}
	return strings.TrimSpace(ibanValue)
}

func buildBankAccountDisplayLabel(name, ibanValue, uid string) string {
	displayLabel := name
	if ibanValue != "" {
		if displayLabel != "" {
			displayLabel += " - " + ibanValue
		} else {
			displayLabel = ibanValue
		}
	}
	if displayLabel == "" {
		displayLabel = uid
	}
	return displayLabel
}

func rawIbanFromDisplayLabel(displayLabel string) string {
	if displayLabel == "" {
		return ""
	}
	if strings.Contains(displayLabel, " - ") {
		return strings.TrimSpace(displayLabel[strings.LastIndex(displayLabel, " - ")+3:])
	}
	return strings.TrimSpace(displayLabel)
}

// findLocalAccountIdForIban cherche un compte BudgetTime via external_id ou une ancienne liaison bank_accounts.
func findLocalAccountIdForIban(app *pocketbase.PocketBase, userId, ibanValue string) string {
	if ibanValue == "" {
		return ""
	}
	normalized := normalizeIban(ibanValue)

	var localAccount struct {
		Id string `db:"id"`
	}
	err := app.DB().Select("id").
		From("accounts").
		Where(dbx.HashExp{"user": userId}).
		AndWhere(dbx.NewExp("REPLACE(UPPER(external_id), ' ', '') = {:iban}", dbx.Params{"iban": normalized})).
		Limit(1).
		One(&localAccount)
	if err == nil && localAccount.Id != "" {
		return localAccount.Id
	}

	// Fallback : ancienne liaison bank_accounts (même IBAN, autre session / remote id)
	var priorLink struct {
		LocalAccountId string `db:"local_account_id"`
	}
	err = app.DB().Select("ba.local_account_id").
		From("bank_accounts ba").
		InnerJoin("bank_connections bc", dbx.NewExp("ba.connection_id = bc.id")).
		Where(dbx.HashExp{"bc.user": userId}).
		AndWhere(dbx.NewExp("ba.local_account_id != '' AND ba.local_account_id IS NOT NULL")).
		AndWhere(dbx.NewExp("REPLACE(UPPER(ba.iban), ' ', '') LIKE '%' || {:iban} || '%'", dbx.Params{"iban": normalized})).
		OrderBy("ba.created DESC").
		Limit(1).
		One(&priorLink)
	if err == nil && priorLink.LocalAccountId != "" {
		return priorLink.LocalAccountId
	}

	return ""
}

func persistIbanOnLocalAccount(app *pocketbase.PocketBase, localAccountId, ibanValue string) {
	if localAccountId == "" || ibanValue == "" {
		return
	}
	_, _ = app.DB().Update("accounts", dbx.Params{
		"external_id": ibanValue,
	}, dbx.HashExp{"id": localAccountId}).Execute()
}

// persistBankMappingsBeforeSessionDelete sauvegarde l'IBAN sur accounts.external_id avant suppression.
func persistBankMappingsBeforeSessionDelete(app *pocketbase.PocketBase, connectionId string) {
	var rows []struct {
		LocalAccountId string `db:"local_account_id"`
		Iban           string `db:"iban"`
	}
	_ = app.DB().Select("local_account_id", "iban").
		From("bank_accounts").
		Where(dbx.HashExp{"connection_id": connectionId}).
		All(&rows)

	for _, row := range rows {
		if row.LocalAccountId == "" {
			continue
		}
		rawIban := rawIbanFromDisplayLabel(row.Iban)
		if rawIban != "" {
			persistIbanOnLocalAccount(app, row.LocalAccountId, rawIban)
		}
	}
}

// syncEnableBankAccount crée ou met à jour un bank_account avec auto-liaison IBAN.
// Retourne added, relinked (local_account_id restauré).
func syncEnableBankAccount(
	app *pocketbase.PocketBase,
	collectionAcc *core.Collection,
	connectionId, userId string,
	acc enableBankAccount,
) (added bool, relinked bool, err error) {
	if acc.Uid == "" || collectionAcc == nil {
		return false, false, nil
	}

	ibanValue := extractIbanFromEnableAccount(acc)
	displayLabel := buildBankAccountDisplayLabel(acc.Name, ibanValue, acc.Uid)
	localAccountId := findLocalAccountIdForIban(app, userId, ibanValue)

	// 1. Compte déjà connu par remote_account_id
	var existingId string
	_ = app.DB().Select("id").
		From("bank_accounts").
		Where(dbx.HashExp{"remote_account_id": acc.Uid}).
		Limit(1).
		Row(&existingId)

	if existingId != "" {
		record, findErr := app.FindRecordById("bank_accounts", existingId)
		if findErr != nil {
			return false, false, findErr
		}
		record.Set("connection_id", connectionId)
		record.Set("iban", displayLabel)
		if record.GetString("local_account_id") == "" && localAccountId != "" {
			record.Set("local_account_id", localAccountId)
			persistIbanOnLocalAccount(app, localAccountId, ibanValue)
			relinked = true
			fmt.Printf("[BudgetTime] Auto-liaison (update uid): IBAN %s -> compte local %s\n", ibanValue, localAccountId)
		}
		return false, relinked, app.Save(record)
	}

	// 2. Même IBAN, nouveau remote_account_id (changement de clé / session)
	if ibanValue != "" {
		normalized := normalizeIban(ibanValue)
		var priorId string
		_ = app.DB().Select("ba.id").
			From("bank_accounts ba").
			InnerJoin("bank_connections bc", dbx.NewExp("ba.connection_id = bc.id")).
			Where(dbx.HashExp{"bc.user": userId}).
			AndWhere(dbx.NewExp("REPLACE(UPPER(ba.iban), ' ', '') LIKE '%' || {:iban} || '%'", dbx.Params{"iban": normalized})).
			OrderBy("ba.created DESC").
			Limit(1).
			Row(&priorId)

		if priorId != "" {
			record, findErr := app.FindRecordById("bank_accounts", priorId)
			if findErr != nil {
				return false, false, findErr
			}
			record.Set("connection_id", connectionId)
			record.Set("remote_account_id", acc.Uid)
			record.Set("iban", displayLabel)
			if record.GetString("local_account_id") == "" && localAccountId != "" {
				record.Set("local_account_id", localAccountId)
				relinked = true
			} else if record.GetString("local_account_id") != "" {
				relinked = true
			}
			if record.GetString("local_account_id") != "" {
				persistIbanOnLocalAccount(app, record.GetString("local_account_id"), ibanValue)
			}
			fmt.Printf("[BudgetTime] Re-liaison IBAN %s (nouveau uid %s)\n", ibanValue, acc.Uid)
			return false, relinked, app.Save(record)
		}
	}

	// 3. Nouveau compte bancaire
	recordAcc := core.NewRecord(collectionAcc)
	recordAcc.Set("connection_id", connectionId)
	recordAcc.Set("remote_account_id", acc.Uid)
	recordAcc.Set("iban", displayLabel)
	if localAccountId != "" {
		recordAcc.Set("local_account_id", localAccountId)
		persistIbanOnLocalAccount(app, localAccountId, ibanValue)
		relinked = true
		fmt.Printf("[BudgetTime] Auto-liaison (nouveau): IBAN %s -> compte local %s\n", ibanValue, localAccountId)
	}
	if saveErr := app.Save(recordAcc); saveErr != nil {
		return false, false, saveErr
	}
	return true, relinked, nil
}
