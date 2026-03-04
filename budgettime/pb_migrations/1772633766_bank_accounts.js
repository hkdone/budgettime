migrate((db) => {
    const dao = new Dao(db);

    const collection = new Collection({
        "id": "v2_acc_00000001",
        "name": "bank_accounts",
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
                "id": "remote_account_id_str",
                "name": "remote_account_id",
                "type": "text",
                "required": true,
                "unique": true
            },
            {
                "id": "iban_str",
                "name": "iban",
                "type": "text",
                "required": true
            },
            {
                "id": "local_account_id_ref",
                "name": "local_account_id",
                "type": "relation",
                "required": false,
                "options": {
                    "collectionId": "accounts000000",
                    "cascadeDelete": false,
                    "maxSelect": 1
                }
            }
        ],
        "listRule": "connection_id.user_id = @request.auth.id",
        "viewRule": "connection_id.user_id = @request.auth.id",
        "deleteRule": "connection_id.user_id = @request.auth.id",
        "options": {}
    });

    return dao.saveCollection(collection);
}, (db) => {
    const dao = new Dao(db);
    const collection = dao.findCollectionByNameOrId("bank_accounts");
    return dao.deleteCollection(collection);
})
