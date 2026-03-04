migrate((app) => {
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
                    "values": [
                        "success",
                        "error",
                        "pending"
                    ]
                }
            },
            {
                "id": "v2logs_count",
                "name": "transactions_count",
                "type": "number",
                "required": true,
                "options": {
                    "min": 0,
                    "noDecimal": true
                }
            },
            {
                "id": "v2logs_error",
                "name": "error_message",
                "type": "text",
                "required": false
            }
        ],
        "options": {}
    });

    // 1. Sauvegarde initiale pour enregistrer les champs
    app.save(collection);

    // 2. Application des règles (le validateur reconnaîtra désormais 'connection_id')
    collection.listRule = "connection_id.user_id = @request.auth.id";
    collection.viewRule = "connection_id.user_id = @request.auth.id";

    return app.save(collection);
}, (app) => {
    const collection = app.findCollectionByNameOrId("v2logs000000001");
    return app.delete(collection);
})
