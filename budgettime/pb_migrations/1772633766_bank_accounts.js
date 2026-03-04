migrate((app) => {
    const collection = new Collection({
        "id": "bank_acc000000",
        "name": "bank_accounts",
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
                    "collectionId": "bank_conn00000",
                    "cascadeDelete": true,
                    "minSelect": null,
                    "maxSelect": 1,
                    "displayFields": null
                }
            },
            {
                "system": false,
                "id": "remote_account_id_str",
                "name": "remote_account_id",
                "type": "text",
                "required": true,
                "presentable": true,
                "unique": false,
                "options": {
                    "min": null,
                    "max": null,
                    "pattern": ""
                }
            },
            {
                "system": false,
                "id": "iban_str",
                "name": "iban",
                "type": "text",
                "required": true,
                "presentable": true,
                "unique": false,
                "options": {
                    "min": null,
                    "max": null,
                    "pattern": ""
                }
            },
            {
                "system": false,
                "id": "local_account_id_ref",
                "name": "local_account_id",
                "type": "relation",
                "required": false,
                "presentable": false,
                "unique": false,
                "options": {
                    "collectionId": "accounts",
                    "cascadeDelete": false,
                    "minSelect": null,
                    "maxSelect": 1,
                    "displayFields": null
                }
            }
        ],
        "indexes": [],
        "listRule": null,
        "viewRule": null,
        "createRule": null,
        "updateRule": null,
        "deleteRule": null,
        "options": {}
    });

    // 1. Schéma
    app.save(collection);

    // 2. Index
    collection.indexes = [
        "CREATE UNIQUE INDEX `bank_accounts_remote_idx` ON `bank_accounts` (`remote_account_id`)"
    ];
    app.save(collection);

    // 3. Règles
    collection.listRule = "connection_id.user_id = @request.auth.id";
    collection.viewRule = "connection_id.user_id = @request.auth.id";
    collection.deleteRule = "connection_id.user_id = @request.auth.id";

    return app.save(collection);
}, (app) => {
    const collection = app.findCollectionByNameOrId("bank_accounts");
    return app.delete(collection);
})
