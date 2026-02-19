/// <reference path="../pb_data/types.d.ts" />
migrate((db) => {
    const dao = new Dao(db);

    // 1. Create 'accounts' collection
    const accounts = new Collection({
        "id": "accounts000000",
        "name": "accounts",
        "type": "base",
        "system": false,
        "schema": [
            {
                "system": false,
                "id": "accounts_name",
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
                "id": "accounts_type",
                "name": "type",
                "type": "select",
                "required": true,
                "presentable": false,
                "unique": false,
                "options": {
                    "maxSelect": 1,
                    "values": ["checking", "savings"]
                }
            },
            {
                "system": false,
                "id": "accounts_initial_balance",
                "name": "initial_balance",
                "type": "number",
                "required": false,
                "presentable": false,
                "unique": false,
                "options": {
                    "min": null,
                    "max": null,
                    "noDecimal": false
                }
            },
            {
                "system": false,
                "id": "accounts_user",
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
    dao.saveCollection(accounts);

    // 2. Create 'members' collection
    const members = new Collection({
        "id": "members000000",
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
                "required": false,
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
    dao.saveCollection(members);

    // 3. Create 'categories' collection
    const categories = new Collection({
        "id": "categories000000",
        "name": "categories",
        "type": "base",
        "system": false,
        "schema": [
            {
                "system": false,
                "id": "categories_name",
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
                "id": "categories_icon",
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
                "id": "categories_color",
                "name": "color",
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
                "id": "categories_user",
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
    dao.saveCollection(categories);

    // 4. Create 'recurrences' collection
    const recurrences = new Collection({
        "id": "recurrences000",
        "name": "recurrences",
        "type": "base",
        "system": false,
        "schema": [
            {
                "system": false,
                "id": "recurrences_amount",
                "name": "amount",
                "type": "number",
                "required": true,
                "presentable": false,
                "unique": false,
                "options": {
                    "min": null,
                    "max": null,
                    "noDecimal": false
                }
            },
            {
                "system": false,
                "id": "recurrences_label",
                "name": "label",
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
                "id": "recurrences_type",
                "name": "type",
                "type": "select",
                "required": true,
                "presentable": false,
                "unique": false,
                "options": {
                    "maxSelect": 1,
                    "values": ["income", "expense", "transfer"]
                }
            },
            {
                "system": false,
                "id": "recurrences_frequency",
                "name": "frequency",
                "type": "select",
                "required": true,
                "presentable": false,
                "unique": false,
                "options": {
                    "maxSelect": 1,
                    "values": ["daily", "weekly", "biweekly", "monthly", "bimonthly", "yearly"]
                }
            },
            {
                "system": false,
                "id": "recurrences_day",
                "name": "day_of_month",
                "type": "number",
                "required": false,
                "presentable": false,
                "unique": false,
                "options": {
                    "min": 1,
                    "max": 31,
                    "noDecimal": true
                }
            },
            {
                "system": false,
                "id": "recurrences_next",
                "name": "next_due_date",
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
                "id": "recurrences_active",
                "name": "active",
                "type": "bool",
                "required": false,
                "presentable": false,
                "unique": false,
                "options": {}
            },
            {
                "system": false,
                "id": "recurrences_acct",
                "name": "account",
                "type": "relation",
                "required": true,
                "presentable": false,
                "unique": false,
                "options": {
                    "collectionId": "accounts000000",
                    "cascadeDelete": true,
                    "minSelect": null,
                    "maxSelect": 1,
                    "displayFields": null
                }
            },
            {
                "system": false,
                "id": "recurrences_target",
                "name": "target_account",
                "type": "relation",
                "required": false,
                "presentable": false,
                "unique": false,
                "options": {
                    "collectionId": "accounts000000",
                    "cascadeDelete": false,
                    "minSelect": null,
                    "maxSelect": 1,
                    "displayFields": null
                }
            },
            {
                "system": false,
                "id": "recurrences_user",
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
    dao.saveCollection(recurrences);

    // 5. Create 'transactions' collection
    const transactions = new Collection({
        "id": "transactions00",
        "name": "transactions",
        "type": "base",
        "system": false,
        "schema": [
            {
                "system": false,
                "id": "transactions_amount",
                "name": "amount",
                "type": "number",
                "required": true,
                "presentable": false,
                "unique": false,
                "options": {
                    "min": null,
                    "max": null,
                    "noDecimal": false
                }
            },
            {
                "system": false,
                "id": "transactions_label",
                "name": "label",
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
                "id": "transactions_type",
                "name": "type",
                "type": "select",
                "required": true,
                "presentable": false,
                "unique": false,
                "options": {
                    "maxSelect": 1,
                    "values": ["income", "expense", "transfer"]
                }
            },
            {
                "system": false,
                "id": "transactions_date",
                "name": "date",
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
                "id": "transactions_status",
                "name": "status",
                "type": "select",
                "required": true,
                "presentable": false,
                "unique": false,
                "options": {
                    "maxSelect": 1,
                    "values": ["projected", "effective"]
                }
            },
            {
                "system": false,
                "id": "transactions_is_auto",
                "name": "is_automatic",
                "type": "bool",
                "required": false,
                "presentable": false,
                "unique": false,
                "options": {}
            },
            {
                "system": false,
                "id": "transactions_acct",
                "name": "account",
                "type": "relation",
                "required": true,
                "presentable": false,
                "unique": false,
                "options": {
                    "collectionId": "accounts000000",
                    "cascadeDelete": true,
                    "minSelect": null,
                    "maxSelect": 1,
                    "displayFields": null
                }
            },
            {
                "system": false,
                "id": "transactions_cat",
                "name": "category",
                "type": "text", // Keeping as text for now for flexibility, or relation to categories
                "required": false,
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
                "id": "transactions_recur",
                "name": "recurrence",
                "type": "relation",
                "required": false,
                "presentable": false,
                "unique": false,
                "options": {
                    "collectionId": "recurrences000",
                    "cascadeDelete": false,
                    "minSelect": null,
                    "maxSelect": 1,
                    "displayFields": null
                }
            },
            {
                "system": false,
                "id": "transactions_member",
                "name": "member",
                "type": "relation",
                "required": false,
                "presentable": false,
                "unique": false,
                "options": {
                    "collectionId": "members000000",
                    "cascadeDelete": false,
                    "minSelect": null,
                    "maxSelect": 1,
                    "displayFields": null
                }
            },
            {
                "system": false,
                "id": "transactions_target",
                "name": "target_account",
                "type": "relation",
                "required": false,
                "presentable": false,
                "unique": false,
                "options": {
                    "collectionId": "accounts000000",
                    "cascadeDelete": false,
                    "minSelect": null,
                    "maxSelect": 1,
                    "displayFields": null
                }
            },
            {
                "system": false,
                "id": "transactions_user",
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
    dao.saveCollection(transactions);

    // 6. Create 'raw_inbox' collection (for imported CSVs/Banks)
    const rawInbox = new Collection({
        "id": "rawinbox000000",
        "name": "raw_inbox",
        "type": "base",
        "system": false,
        "schema": [
            {
                "system": false,
                "id": "rawinbox_date",
                "name": "date",
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
                "id": "rawinbox_label",
                "name": "label",
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
                "id": "rawinbox_amount",
                "name": "amount",
                "type": "number",
                "required": true,
                "presentable": false,
                "unique": false,
                "options": {
                    "min": null,
                    "max": null,
                    "noDecimal": false
                }
            },
            {
                "system": false,
                "id": "rawinbox_user",
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
    dao.saveCollection(rawInbox);

}, (db) => {
    const dao = new Dao(db);
    // delete in reverse order of creation
    try { dao.deleteCollection(dao.findCollectionByNameOrId("raw_inbox")); } catch (_) { }
    try { dao.deleteCollection(dao.findCollectionByNameOrId("transactions")); } catch (_) { }
    try { dao.deleteCollection(dao.findCollectionByNameOrId("recurrences")); } catch (_) { }
    try { dao.deleteCollection(dao.findCollectionByNameOrId("categories")); } catch (_) { }
    try { dao.deleteCollection(dao.findCollectionByNameOrId("members")); } catch (_) { }
    try { dao.deleteCollection(dao.findCollectionByNameOrId("accounts")); } catch (_) { }
})
