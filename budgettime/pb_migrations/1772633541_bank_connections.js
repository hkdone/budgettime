migrate((app) => {
    const collection = new Collection({
        "id": "bank_connections",
        "name": "bank_connections",
        "type": "base",
        "system": false,
        "schema": [
            {
                "system": false,
                "id": "user_id_ref",
                "name": "user_id",
                "type": "relation",
                "required": true,
                "presentable": false,
                "unique": false,
                "options": {
                    "collectionId": "_pb_users_auth_",
                    "cascadeDelete": true,
                    "minSelect": null,
                    "maxSelect": 1,
                    "displayFields": null
                }
            },
            {
                "system": false,
                "id": "bank_name_str",
                "name": "bank_name",
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
                "id": "requisition_id_str",
                "name": "requisition_id",
                "type": "text",
                "required": true,
                "presentable": false,
                "unique": true,
                "options": {
                    "min": null,
                    "max": null,
                    "pattern": ""
                }
            },
            {
                "system": false,
                "id": "valid_until_date",
                "name": "valid_until",
                "type": "date",
                "required": true,
                "presentable": false,
                "unique": false,
                "options": {
                    "min": "",
                    "max": ""
                }
            },
            {
                "system": false,
                "id": "bank_logo_str",
                "name": "bank_logo",
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
        "listRule": null,
        "viewRule": null,
        "createRule": null,
        "updateRule": null,
        "deleteRule": null,
        "options": {}
    });

    // 1. Sauvegarde du schéma seul
    app.save(collection);

    // 2. Ajout de l'index une fois la colonne créée
    collection.indexes = [
        "CREATE UNIQUE INDEX `bank_connections_req_idx` ON `bank_connections` (`requisition_id`)"
    ];
    app.save(collection);

    // 3. Ajout des règles
    collection.listRule = "user_id = @request.auth.id";
    collection.viewRule = "user_id = @request.auth.id";
    collection.deleteRule = "user_id = @request.auth.id";

    return app.save(collection);
}, (app) => {
    const collection = app.findCollectionByNameOrId("bank_connections");
    return app.delete(collection);
})
