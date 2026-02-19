/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
    const dao = new Dao(db);

    // 1. Create 'members' collection
    const membersCollection = new Collection({
        "id": "members00000000",
        "created": "2024-02-19 14:00:00.000Z",
        "updated": "2024-02-19 14:00:00.000Z",
        "name": "members",
        "type": "base",
        "system": false,
        "schema": [
            {
                "system": false,
                "id": "members_name",
                "name": "name",
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
                "id": "members_icon",
                "name": "icon",
                "type": "text",
                "required": true,
                "presentable": false,
                "unique": false,
                "options": {
                    "min": null,
                    "max": null,
                    "pattern": ""
                }
            },
            {
                "system": false,
                "id": "members_user",
                "name": "user",
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
            }
        ],
        "indexes": [],
        "listRule": "user = @request.auth.id",
        "viewRule": "user = @request.auth.id",
        "createRule": "user = @request.auth.id",
        "updateRule": "user = @request.auth.id",
        "deleteRule": "user = @request.auth.id",
        "options": {}
    });

    dao.saveCollection(membersCollection);

    // 2. Add 'member' relation to 'transactions' collection
    const transactionsCollection = dao.findCollectionByNameOrId("transactions");

    // Check if field already exists to avoid error
    if (!transactionsCollection.schema.getFieldByName("member")) {
        transactionsCollection.schema.addField(new SchemaField({
            "system": false,
            "id": "transactions_member",
            "name": "member",
            "type": "relation",
            "required": false,
            "presentable": false,
            "unique": false,
            "options": {
                "collectionId": membersCollection.id,
                "cascadeDelete": false,
                "minSelect": null,
                "maxSelect": 1,
                "displayFields": null
            }
        }));

        dao.saveCollection(transactionsCollection);
    }

}, (db) => {
    const dao = new Dao(db);

    // Revert modifications
    try {
        const transactions = dao.findCollectionByNameOrId("transactions");
        if (transactions.schema.getFieldByName("member")) {
            transactions.schema.removeField("member");
            dao.saveCollection(transactions);
        }
    } catch (_) { /* ignore if collection doesn't exist */ }

    try {
        const members = dao.findCollectionByNameOrId("members");
        dao.deleteCollection(members);
    } catch (_) { /* ignore */ }
})
