migrate((app) => {
    const collection = new Collection({
        "id": "bank_sync_logs",
        "createdAt": "",
        "updatedAt": "",
        "name": "bank_sync_logs",
        "type": "base",
        "system": false,
        "schema": [
            {
                "system": false,
                "id": "connection_id_ref",
                "name": "connection_id",
                "type": "relation",
                "required": true,
                "presentable": false,
                "unique": false,
                "options": {
                    "collectionId": "bank_connections",
                    "cascadeDelete": true,
                    "minSelect": null,
                    "maxSelect": 1,
                    "displayFields": null
                }
            },
            {
                "system": false,
                "id": "sync_status_str",
                "name": "status",
                "type": "select",
                "required": true,
                "presentable": true,
                "unique": false,
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
                "system": false,
                "id": "transactions_count_num",
                "name": "transactions_count",
                "type": "number",
                "required": true,
                "presentable": false,
                "unique": false,
                "options": {
                    "min": 0,
                    "max": null,
                    "noDecimal": true
                }
            },
            {
                "system": false,
                "id": "error_message_str",
                "name": "error_message",
                "type": "text",
                "required": false,
                "presentable": false,
                "unique": false,
                "options": {
                    "min": null,
                    "max": null,
                    "pattern": ""
                }
            }
        ],
        "indexes": [],
        "listRule": "@request.auth.id != '' && connection_id.user_id = @request.auth.id",
        "viewRule": "@request.auth.id != '' && connection_id.user_id = @request.auth.id",
        "createRule": null,
        "updateRule": null,
        "deleteRule": null,
        "options": {}
    });

    return app.save(collection);
}, (app) => {
    const collection = app.findCollectionByNameOrId("bank_sync_logs");
    return app.delete(collection);
})
