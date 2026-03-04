migrate((db) => {
    const dao = new Dao(db);

    const collection = new Collection({
        "id": "v2_log_00000001",
        "name": "bank_sync_logs",
        "type": "base",
        "system": false,
        "schema": [
            {
                "id": "connection_id_ref",
                "name": "connection_id",
                "type": "relation",
                "required": true,
                "options": {
                    "collectionId": "v2_conn_0000001",
                    "cascadeDelete": true,
                    "maxSelect": 1
                }
            },
            {
                "id": "sync_status_str",
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
                "id": "transactions_count_num",
                "name": "transactions_count",
                "type": "number",
                "required": true,
                "options": {
                    "min": 0,
                    "noDecimal": true
                }
            },
            {
                "id": "error_message_str",
                "name": "error_message",
                "type": "text",
                "required": false
            }
        ],
        "listRule": "connection_id.user_id = @request.auth.id",
        "viewRule": "connection_id.user_id = @request.auth.id",
        "options": {}
    });

    return dao.saveCollection(collection);
}, (db) => {
    const dao = new Dao(db);
    const collection = dao.findCollectionByNameOrId("bank_sync_logs");
    return dao.deleteCollection(collection);
})
