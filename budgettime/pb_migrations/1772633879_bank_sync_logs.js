migrate((app) => {
    // 1. Suppression préventive
    try {
        const existing = app.findCollectionByNameOrId("v2logs000000001");
        if (existing) app.dao().deleteCollection(existing);
    } catch (_) { }

    const collection = new Collection({
        "id": "v2logs000000001",
        "name": "bank_sync_logs",
        "type": "base",
        "system": false,
        "schema": [
            {
                "id": "v2logs_conn",
                "name": "connection_id",
                "type": "relation",
                "required": true,
                "options": {
                    "collectionId": "v2conn000000001",
                    "cascadeDelete": true,
                    "maxSelect": 1
                }
            },
            {
                "id": "v2logs_status",
                "name": "status",
                "type": "select",
                "required": true,
                "options": {
                    "maxSelect": 1,
                    "values": ["success", "error", "pending"]
                }
            },
            {
                "id": "v2logs_count",
                "name": "transactions_count",
                "type": "number",
                "required": true,
                "options": { "min": 0, "noDecimal": true }
            },
            { "id": "v2logs_error", "name": "error_message", "type": "text", "required": false }
        ],
        "options": {}
    });

    // 2. Sauvegarde Schéma
    app.dao().saveCollection(collection);

    // 3. Rafraîchissement et ajout des règles
    const fresh = app.findCollectionByNameOrId("v2logs000000001");
    fresh.listRule = "connection_id.user = @request.auth.id";
    fresh.viewRule = "connection_id.user = @request.auth.id";

    return app.dao().saveCollection(fresh);
}, (app) => {
    const collection = app.findCollectionByNameOrId("v2logs000000001");
    if (collection) app.dao().deleteCollection(collection);
})
