migrate((db) => {
    const dao = new Dao(db);

    const collection = new Collection({
        "id": "v2_conn_0000001",
        "name": "bank_connections",
        "type": "base",
        "system": false,
        "schema": [
            {
                "id": "user_id_ref",
                "name": "user_id",
                "type": "relation",
                "required": true,
                "options": {
                    "collectionId": "_pb_users_auth_",
                    "cascadeDelete": true,
                    "maxSelect": 1
                }
            },
            {
                "id": "bank_name_str",
                "name": "bank_name",
                "type": "text",
                "required": true
            },
            {
                "id": "requisition_id_str",
                "name": "requisition_id",
                "type": "text",
                "required": true,
                "unique": true
            },
            {
                "id": "valid_until_date",
                "name": "valid_until",
                "type": "date",
                "required": true
            },
            {
                "id": "bank_logo_str",
                "name": "bank_logo",
                "type": "text",
                "required": false
            }
        ],
        "listRule": "user_id = @request.auth.id",
        "viewRule": "user_id = @request.auth.id",
        "deleteRule": "user_id = @request.auth.id",
        "options": {}
    });

    return dao.saveCollection(collection);
}, (db) => {
    const dao = new Dao(db);
    const collection = dao.findCollectionByNameOrId("bank_connections");
    return dao.deleteCollection(collection);
})
