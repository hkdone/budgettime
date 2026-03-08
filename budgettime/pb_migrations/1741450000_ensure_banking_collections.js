migrate((app) => {
    // 1. Table bank_connections
    try {
        app.findCollectionByNameOrId("bank_connections");
    } catch (e) {
        const collection = new Collection({
            "id": "bank_conn_00001",
            "name": "bank_connections",
            "type": "base",
            "system": false,
            "fields": [
                { "name": "user", "type": "relation", "required": true, "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 },
                { "name": "bank_name", "type": "text", "required": true },
                { "name": "requisition_id", "type": "text", "required": true },
                { "name": "valid_until", "type": "date", "required": true },
                { "name": "bank_logo", "type": "text", "required": false }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id",
            "indexes": ["CREATE UNIQUE INDEX idx_requisition_id_bt ON bank_connections (requisition_id)"]
        });
        app.save(collection);
    }

    // 2. Table bank_accounts
    try {
        app.findCollectionByNameOrId("bank_accounts");
    } catch (e) {
        const collection = new Collection({
            "id": "bank_acc_000001",
            "name": "bank_accounts",
            "type": "base",
            "system": false,
            "fields": [
                { "name": "connection_id", "type": "relation", "required": true, "collectionId": "bank_conn_00001", "cascadeDelete": true, "maxSelect": 1 },
                { "name": "remote_account_id", "type": "text", "required": true },
                { "name": "iban", "type": "text", "required": true },
                { "name": "local_account_id", "type": "relation", "required": false, "collectionId": "accounts000000", "cascadeDelete": false, "maxSelect": 1 }
            ],
            "listRule": "connection_id.user = @request.auth.id",
            "viewRule": "connection_id.user = @request.auth.id",
            "deleteRule": "connection_id.user = @request.auth.id",
            "indexes": ["CREATE UNIQUE INDEX idx_remote_account_id_bt ON bank_accounts (remote_account_id)"]
        });
        app.save(collection);
    }

    // 3. Table bank_sync_logs (optionnelle mais utile pour le rate limit géré dans main.go)
    try {
        app.findCollectionByNameOrId("bank_sync_logs");
    } catch (e) {
        const collection = new Collection({
            "id": "bank_logs_000001",
            "name": "bank_sync_logs",
            "type": "base",
            "system": false,
            "fields": [
                { "name": "connection_id", "type": "relation", "required": true, "collectionId": "bank_conn_00001", "cascadeDelete": true, "maxSelect": 1 },
                { "name": "status", "type": "select", "required": true, "maxSelect": 1, "values": ["success", "error", "pending"] },
                { "name": "transactions_count", "type": "number", "required": true, "min": 0, "noDecimal": true },
                { "name": "error_message", "type": "text", "required": false }
            ],
            "listRule": "connection_id.user = @request.auth.id",
            "viewRule": "connection_id.user = @request.auth.id"
        });
        app.save(collection);
    }
}, (app) => {
    // Down non nécessaire
});
