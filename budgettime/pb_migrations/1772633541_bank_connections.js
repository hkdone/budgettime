migrate((app) => {
    const collection = new Collection({
        "id": "bank_connections",
        "createdAt": "",
        "updatedAt": "",
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
        "indexes": [
            "CREATE UNIQUE INDEX `bank_connections_req_idx` ON `bank_connections` (`requisition_id`)"
        ],
        "listRule": "@request.auth.id != '' && user_id = @request.auth.id",
        "viewRule": "@request.auth.id != '' && user_id = @request.auth.id",
        "createRule": null,
        "updateRule": null,
        "deleteRule": "@request.auth.id != '' && user_id = @request.auth.id",
        "options": {}
    });

    return app.save(collection);
}, (app) => {
    const collection = app.findCollectionByNameOrId("bank_connections");
    return app.delete(collection);
})
