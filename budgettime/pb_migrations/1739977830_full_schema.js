migrate((app) => {
    const collectionConfigs = [
        {
            "id": "accounts_0000000",
            "name": "accounts",
            "type": "base",
            "fields": [
                { "id": "accounts_name", "name": "name", "type": "text", "required": true, "presentable": true },
                { "id": "accounts_curr", "name": "currency", "type": "text", "required": true },
                { "id": "accounts_extid", "name": "external_id", "type": "text", "required": false },
                { "id": "accounts_type", "name": "type", "type": "select", "required": true, "maxSelect": 1, "values": ["checking", "savings"] },
                { "id": "accounts_initial_balance", "name": "initial_balance", "type": "number", "required": false },
                { "id": "accounts_user", "name": "user", "type": "relation", "required": true, "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        },
        {
            "id": "members00000000",
            "name": "members",
            "type": "base",
            "fields": [
                { "id": "members_name", "name": "name", "type": "text", "required": true, "presentable": true },
                { "id": "members_icon", "name": "icon", "type": "text", "required": false },
                { "id": "members_user", "name": "user", "type": "relation", "required": true, "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        },
        {
            "id": "categories_0000",
            "name": "categories",
            "type": "base",
            "fields": [
                { "id": "categories_name", "name": "name", "type": "text", "required": true, "presentable": true },
                { "id": "categories_icon", "name": "icon_code_point", "type": "number", "required": true, "noDecimal": true },
                { "id": "categories_color", "name": "color_hex", "type": "text", "required": true },
                { "id": "categories_is_system", "name": "is_system", "type": "bool", "required": false },
                { "id": "categories_user", "name": "user", "type": "relation", "required": true, "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        },
        {
            "id": "recurrences_000",
            "name": "recurrences",
            "type": "base",
            "fields": [
                { "id": "recurrences_amount", "name": "amount", "type": "number", "required": true },
                { "id": "recurrences_label", "name": "label", "type": "text", "required": true, "presentable": true },
                { "id": "recurrences_type", "name": "type", "type": "select", "required": true, "maxSelect": 1, "values": ["income", "expense", "transfer"] },
                { "id": "recurrences_frequency", "name": "frequency", "type": "select", "required": true, "maxSelect": 1, "values": ["daily", "weekly", "biweekly", "monthly", "bimonthly", "yearly"] },
                { "id": "recurrences_day", "name": "day_of_month", "type": "number", "required": false, "min": 1, "max": 31, "noDecimal": true },
                { "id": "recurrences_next", "name": "next_due_date", "type": "date", "required": true },
                { "id": "recurrences_active", "name": "active", "type": "bool", "required": false },
                { "id": "recurrences_acct", "name": "account", "type": "relation", "required": true, "collectionId": "accounts_0000000", "cascadeDelete": true, "maxSelect": 1 },
                { "id": "recurrences_target", "name": "target_account", "type": "relation", "required": false, "collectionId": "accounts_0000000", "cascadeDelete": false, "maxSelect": 1 },
                { "id": "recurrences_user", "name": "user", "type": "relation", "required": true, "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        },
        {
            "id": "transactions_00",
            "name": "transactions",
            "type": "base",
            "fields": [
                { "id": "transactions_amount", "name": "amount", "type": "number", "required": false },
                { "id": "transactions_label", "name": "label", "type": "text", "required": true, "presentable": true },
                { "id": "transactions_type", "name": "type", "type": "select", "required": true, "maxSelect": 1, "values": ["income", "expense", "transfer"] },
                { "id": "transactions_date", "name": "date", "type": "date", "required": true },
                { "id": "transactions_status", "name": "status", "type": "select", "required": true, "maxSelect": 1, "values": ["projected", "effective"] },
                { "id": "transactions_is_auto", "name": "is_automatic", "type": "bool", "required": false },
                { "id": "transactions_acct", "name": "account", "type": "relation", "required": true, "collectionId": "accounts_0000000", "cascadeDelete": true, "maxSelect": 1 },
                { "id": "transactions_cat", "name": "category", "type": "text", "required": false },
                { "id": "transactions_recur", "name": "recurrence", "type": "relation", "required": false, "collectionId": "recurrences_000", "cascadeDelete": false, "maxSelect": 1 },
                { "id": "transactions_member", "name": "member", "type": "relation", "required": false, "collectionId": "members00000000", "cascadeDelete": false, "maxSelect": 1 },
                { "id": "transactions_bank", "name": "bank_balance", "type": "number", "required": false },
                { "id": "transactions_target", "name": "target_account", "type": "relation", "required": false, "collectionId": "accounts_0000000", "cascadeDelete": false, "maxSelect": 1 },
                { "id": "transactions_user", "name": "user", "type": "relation", "required": true, "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        },
        {
            "id": "raw_inbox_00000",
            "name": "raw_inbox",
            "type": "base",
            "fields": [
                { "id": "rawinbox_date", "name": "date", "type": "date", "required": true },
                { "id": "rawinbox_label", "name": "label", "type": "text", "required": true, "presentable": true },
                { "id": "rawinbox_amount", "name": "amount", "type": "number", "required": false },
                { "id": "rawinbox_user", "name": "user", "type": "relation", "required": true, "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 },
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
            "id": "settings_000000",
            "name": "settings",
            "type": "base",
            "fields": [
                { "id": "settings_fiscal", "name": "fiscal_day_start", "type": "number", "required": true, "min": 1, "max": 31, "noDecimal": true },
                { "id": "settings_user", "name": "user", "type": "relation", "required": true, "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 },
                { "id": "set_parsers", "name": "active_parsers", "type": "json", "required": false }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        },
        {
            "id": "bank_conn_00001",
            "name": "bank_connections",
            "type": "base",
            "fields": [
                { "id": "v2conn_user", "name": "user", "type": "relation", "required": true, "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 },
                { "id": "v2conn_bank", "name": "bank_name", "type": "text", "required": true },
                { "id": "v2conn_reqid", "name": "requisition_id", "type": "text", "required": true },
                { "id": "v2conn_valid", "name": "valid_until", "type": "date", "required": true },
                { "id": "v2conn_logo", "name": "bank_logo", "type": "text", "required": false }
            ],
            "indexes": [
                "CREATE UNIQUE INDEX idx_requisition_id ON bank_connections (requisition_id)"
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        },
        {
            "id": "bank_acc_000001",
            "name": "bank_accounts",
            "type": "base",
            "fields": [
                { "id": "v2acc_conn", "name": "connection_id", "type": "relation", "required": true, "collectionId": "bank_conn_00001", "cascadeDelete": true, "maxSelect": 1 },
                { "id": "v2acc_remote", "name": "remote_account_id", "type": "text", "required": true },
                { "id": "v2acc_iban", "name": "iban", "type": "text", "required": true },
                { "id": "v2acc_localacc", "name": "local_account_id", "type": "relation", "required": false, "collectionId": "accounts_0000000", "cascadeDelete": false, "maxSelect": 1 }
            ],
            "indexes": [
                "CREATE UNIQUE INDEX idx_remote_account_id ON bank_accounts (remote_account_id)"
            ],
            "listRule": "connection_id.user = @request.auth.id",
            "viewRule": "connection_id.user = @request.auth.id",
            "deleteRule": "connection_id.user = @request.auth.id"
        },
        {
            "id": "bank_logs_000001",
            "name": "bank_sync_logs",
            "type": "base",
            "fields": [
                { "id": "v2logs_conn", "name": "connection_id", "type": "relation", "required": true, "collectionId": "bank_conn_00001", "cascadeDelete": true, "maxSelect": 1 },
                { "id": "v2logs_status", "name": "status", "type": "select", "required": true, "maxSelect": 1, "values": ["success", "error", "pending"] },
                { "id": "v2logs_count", "name": "transactions_count", "type": "number", "required": true, "min": 0, "noDecimal": true },
                { "id": "v2logs_error", "name": "error_message", "type": "text", "required": false }
            ],
            "listRule": "connection_id.user = @request.auth.id",
            "viewRule": "connection_id.user = @request.auth.id"
        }
    ];

    // Étape 1 : Créer les collections SANS les règles
    collectionConfigs.forEach(config => {
        const c = new Collection({
            "id": config.id,
            "name": config.name,
            "type": config.type,
            "fields": config.fields,
            "indexes": config.indexes || []
        });
        app.save(c);
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
}, (app) => {
    const names = ["bank_sync_logs", "bank_accounts", "bank_connections", "settings", "raw_inbox", "transactions", "recurrences", "categories", "members", "accounts"];
    names.forEach(name => {
        try { app.delete(app.findCollectionByNameOrId(name)); } catch (_) { }
    });
})
