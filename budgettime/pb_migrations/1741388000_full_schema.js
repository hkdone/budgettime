migrate((app) => {
    const collections = [
        new Collection({
            "id": "accounts000000",
            "name": "accounts",
            "type": "base",
            "fields": [
                { "id": "accounts_name", "name": "name", "type": "text", "required": true, "options": { "presentable": true } },
                { "id": "accounts_curr", "name": "currency", "type": "text", "required": true },
                { "id": "accounts_extid", "name": "external_id", "type": "text", "required": false },
                { "id": "accounts_type", "name": "type", "type": "select", "required": true, "options": { "maxSelect": 1, "values": ["checking", "savings", "cash"] } },
                { "id": "accounts_initial_balance", "name": "initial_balance", "type": "number", "required": false },
                { "id": "accounts_user", "name": "user", "type": "relation", "required": true, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 } }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        }),
        new Collection({
            "id": "members000000",
            "name": "members",
            "type": "base",
            "fields": [
                { "id": "members_name", "name": "name", "type": "text", "required": true, "options": { "presentable": true } },
                { "id": "members_icon", "name": "icon", "type": "text", "required": false },
                { "id": "members_user", "name": "user", "type": "relation", "required": true, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 } }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        }),
        new Collection({
            "id": "categories000000",
            "name": "categories",
            "type": "base",
            "fields": [
                { "id": "categories_name", "name": "name", "type": "text", "required": true, "options": { "presentable": true } },
                { "id": "categories_icon", "name": "icon_code_point", "type": "number", "required": true, "options": { "noDecimal": true } },
                { "id": "categories_color", "name": "color_hex", "type": "text", "required": true },
                { "id": "categories_is_system", "name": "is_system", "type": "bool", "required": false },
                { "id": "categories_user", "name": "user", "type": "relation", "required": true, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 } }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        }),
        new Collection({
            "id": "recurrences000",
            "name": "recurrences",
            "type": "base",
            "fields": [
                { "id": "recurrences_amount", "name": "amount", "type": "number", "required": true },
                { "id": "recurrences_label", "name": "label", "type": "text", "required": true, "options": { "presentable": true } },
                { "id": "recurrences_type", "name": "type", "type": "select", "required": true, "options": { "maxSelect": 1, "values": ["income", "expense", "transfer"] } },
                { "id": "recurrences_frequency", "name": "frequency", "type": "select", "required": true, "options": { "maxSelect": 1, "values": ["daily", "weekly", "biweekly", "monthly", "bimonthly", "yearly"] } },
                { "id": "recurrences_day", "name": "day_of_month", "type": "number", "required": false, "options": { "min": 1, "max": 31, "noDecimal": true } },
                { "id": "recurrences_next", "name": "next_due_date", "type": "date", "required": true },
                { "id": "recurrences_active", "name": "active", "type": "bool", "required": false },
                { "id": "recurrences_acct", "name": "account", "type": "relation", "required": true, "options": { "collectionId": "accounts000000", "cascadeDelete": true, "maxSelect": 1 } },
                { "id": "recurrences_target", "name": "target_account", "type": "relation", "required": false, "options": { "collectionId": "accounts000000", "cascadeDelete": false, "maxSelect": 1 } },
                { "id": "recurrences_user", "name": "user", "type": "relation", "required": true, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 } }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        }),
        new Collection({
            "id": "transactions00",
            "name": "transactions",
            "type": "base",
            "fields": [
                { "id": "transactions_amount", "name": "amount", "type": "number", "required": false },
                { "id": "transactions_label", "name": "label", "type": "text", "required": true, "options": { "presentable": true } },
                { "id": "transactions_type", "name": "type", "type": "select", "required": true, "options": { "maxSelect": 1, "values": ["income", "expense", "transfer"] } },
                { "id": "transactions_date", "name": "date", "type": "date", "required": true },
                { "id": "transactions_status", "name": "status", "type": "select", "required": true, "options": { "maxSelect": 1, "values": ["projected", "effective"] } },
                { "id": "transactions_is_auto", "name": "is_automatic", "type": "bool", "required": false },
                { "id": "transactions_acct", "name": "account", "type": "relation", "required": true, "options": { "collectionId": "accounts000000", "cascadeDelete": true, "maxSelect": 1 } },
                { "id": "transactions_cat", "name": "category", "type": "text", "required": false },
                { "id": "transactions_recur", "name": "recurrence", "type": "relation", "required": false, "options": { "collectionId": "recurrences000", "cascadeDelete": false, "maxSelect": 1 } },
                { "id": "transactions_member", "name": "member", "type": "relation", "required": false, "options": { "collectionId": "members000000", "cascadeDelete": false, "maxSelect": 1 } },
                { "id": "transactions_target", "name": "target_account", "type": "relation", "required": false, "options": { "collectionId": "accounts000000", "cascadeDelete": false, "maxSelect": 1 } },
                { "id": "transactions_user", "name": "user", "type": "relation", "required": true, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 } }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        }),
        new Collection({
            "id": "rawinbox000000",
            "name": "raw_inbox",
            "type": "base",
            "fields": [
                { "id": "rawinbox_date", "name": "date", "type": "date", "required": true },
                { "id": "rawinbox_label", "name": "label", "type": "text", "required": true, "options": { "presentable": true } },
                { "id": "rawinbox_amount", "name": "amount", "type": "number", "required": false },
                { "id": "rawinbox_user", "name": "user", "type": "relation", "required": true, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 } },
                { "id": "rawinbox_proc", "name": "is_processed", "type": "bool", "required": false },
                { "id": "rawinbox_payl", "name": "raw_payload", "type": "text", "required": false },
                { "id": "rawinbox_meta", "name": "metadata", "type": "json", "required": false }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        }),
        new Collection({
            "id": "settings000000",
            "name": "settings",
            "type": "base",
            "fields": [
                { "id": "settings_fiscal", "name": "fiscal_day_start", "type": "number", "required": true, "options": { "min": 1, "max": 31, "noDecimal": true } },
                { "id": "settings_user", "name": "user", "type": "relation", "required": true, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 } }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        }),
        // On réintègre les collections banking nécessaires (sauf bank_settings)
        new Collection({
            "id": "bankconn000000",
            "name": "bank_connections",
            "type": "base",
            "fields": [
                { "id": "bc_user", "name": "user", "type": "relation", "required": true, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 } },
                { "id": "bc_name", "name": "bank_name", "type": "text", "required": false },
                { "id": "bc_reqid", "name": "requisition_id", "type": "text", "required": true },
                { "id": "bc_status", "name": "status", "type": "text", "required": false },
                { "id": "bc_valid", "name": "valid_until", "type": "date", "required": false }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        }),
        new Collection({
            "id": "bankacc0000000",
            "name": "bank_accounts",
            "type": "base",
            "fields": [
                { "id": "ba_conn", "name": "connection_id", "type": "relation", "required": true, "options": { "collectionId": "bankconn000000", "cascadeDelete": true, "maxSelect": 1 } },
                { "id": "ba_remote", "name": "remote_account_id", "type": "text", "required": true },
                { "id": "ba_iban", "name": "iban", "type": "text", "required": false },
                { "id": "ba_local", "name": "local_account_id", "type": "relation", "required": false, "options": { "collectionId": "accounts000000", "cascadeDelete": false, "maxSelect": 1 } }
            ],
            "listRule": "@request.auth.id != ''",
            "viewRule": "@request.auth.id != ''",
            "createRule": "@request.auth.id != ''",
            "updateRule": "@request.auth.id != ''",
            "deleteRule": "@request.auth.id != ''"
        }),
        new Collection({
            "id": "banksync00000",
            "name": "bank_sync_logs",
            "type": "base",
            "fields": [
                { "id": "bs_conn", "name": "connection_id", "type": "relation", "required": true, "options": { "collectionId": "bankconn000000", "cascadeDelete": true, "maxSelect": 1 } },
                { "id": "bs_status", "name": "status", "type": "text", "required": true },
                { "id": "bs_count", "name": "transactions_count", "type": "number", "required": false }
            ],
            "listRule": "@request.auth.id != ''",
            "viewRule": "@request.auth.id != ''",
            "createRule": "@request.auth.id != ''",
            "updateRule": "@request.auth.id != ''",
            "deleteRule": "@request.auth.id != ''"
        })
    ];

    for (const collection of collections) {
        try {
            const existing = app.findCollectionByNameOrId(collection.name);
            existing.fields = collection.fields;
            existing.listRule = collection.listRule;
            existing.viewRule = collection.viewRule;
            existing.createRule = collection.createRule;
            existing.updateRule = collection.updateRule;
            existing.deleteRule = collection.deleteRule;
            app.save(existing);
        } catch (_) {
            app.save(collection);
        }
    }

    // Uniquement bank_settings est supprimé car remplacé par les fichiers .pem
    try {
        const col = app.findCollectionByNameOrId("bank_settings");
        app.delete(col);
    } catch (_) { }
}, (app) => {
    // Rollback
});
