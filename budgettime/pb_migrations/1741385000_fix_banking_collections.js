migrate((app) => {
    const bankingCollections = [
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
                { "id": "v2acc_localacc", "name": "local_account_id", "type": "relation", "required": false, "collectionId": "accounts000000", "cascadeDelete": false, "maxSelect": 1 }
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
        },
        {
            "id": "bank_settings_01",
            "name": "bank_settings",
            "type": "base",
            "fields": [
                { "id": "bankset_user", "name": "user", "type": "relation", "required": true, "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 },
                { "id": "bankset_appid", "name": "app_id", "type": "text", "required": false },
                { "id": "bankset_key", "name": "private_key", "type": "text", "required": false },
                { "id": "bankset_sess", "name": "session_id", "type": "text", "required": false }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        }
    ];

    bankingCollections.forEach(config => {
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
        collection.listRule = config.listRule || null;
        collection.viewRule = config.viewRule || null;
        collection.createRule = config.createRule || null;
        collection.updateRule = config.updateRule || null;
        collection.deleteRule = config.deleteRule || null;

        app.save(collection);
    });
}, (app) => {
    // Revert non nécessaire ici
})
