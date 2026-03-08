migrate((app) => {
    const collectionConfigs = [
        {
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
        },
        {
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
        },
        {
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
        },
        {
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
        },
        {
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
        },
        {
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
        },
        {
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
        }
    ];

    // Étape 1 : Créer ou Mettre à jour la structure
    collectionConfigs.forEach(config => {
        let collection;
        try {
            collection = app.findCollectionByNameOrId(config.name);
        } catch (_) {
            collection = new Collection({
                "id": config.id,
                "name": config.name,
                "type": config.type
            });
        }

        collection.fields = config.fields;
        if (config.indexes) {
            collection.indexes = config.indexes;
        }

        app.save(collection);
    });

    // Étape 2 : Appliquer les règles
    collectionConfigs.forEach(config => {
        const c = app.findCollectionByNameOrId(config.name);
        c.listRule = config.listRule || null;
        c.viewRule = config.viewRule || null;
        c.createRule = config.createRule || null;
        c.updateRule = config.updateRule || null;
        c.deleteRule = config.deleteRule || null;
        app.save(c);
    });

    // Nettoyage final des collections obsolètes
    const namesToRemove = ["bank_settings", "bank_sync_logs", "bank_accounts", "bank_connections"];
    namesToRemove.forEach(name => {
        try {
            const col = app.findCollectionByNameOrId(name);
            if (col) { app.delete(col); }
        } catch (_) { }
    });
}, (app) => {
    // Rollback
})
