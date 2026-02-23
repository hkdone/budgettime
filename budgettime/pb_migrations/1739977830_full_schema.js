migrate((db) => {
    const dao = new Dao(db);

    const getFieldByName = (collection, name) => {
        try {
            return collection.schema.getFieldByName(name);
        } catch (_) {
            return null;
        }
    }

    const ensureCollection = (config) => {
        let collection;
        try {
            collection = dao.findCollectionByNameOrId(config.name);
        } catch (_) {
            // Not found, create new
            collection = new Collection({
                ...config,
                schema: [] // Start empty and add fields to ensure correct formatting
            });
            // We set the ID if provided in config to ensure consistency if it's a new create
            if (config.id) collection.id = config.id;
        }

        // Update Rules
        if (config.listRule !== undefined) collection.listRule = config.listRule;
        if (config.viewRule !== undefined) collection.viewRule = config.viewRule;
        if (config.createRule !== undefined) collection.createRule = config.createRule;
        if (config.updateRule !== undefined) collection.updateRule = config.updateRule;
        if (config.deleteRule !== undefined) collection.deleteRule = config.deleteRule;
        if (config.type !== undefined) collection.type = config.type;

        // Process Schema
        const schema = collection.schema;
        config.schema.forEach((fieldDef) => {
            const existingField = getFieldByName(collection, fieldDef.name);
            if (existingField) {
                // Field exists, update options if provided
                if (fieldDef.options) {
                    existingField.options = {
                        ...existingField.options,
                        ...fieldDef.options
                    };
                }
            } else {
                // Field does not exist, add it.
                schema.addField(new SchemaField(fieldDef));
            }
        });

        dao.saveCollection(collection);
    };

    // 1. Accounts
    ensureCollection({
        "id": "accounts000000",
        "name": "accounts",
        "type": "base",
        "system": false,
        "schema": [
            { "id": "accounts_name", "name": "name", "type": "text", "required": true, "presentable": true, "unique": false, "options": { "min": null, "max": null, "pattern": "" } },
            { "id": "accounts_type", "name": "type", "type": "select", "required": true, "presentable": false, "unique": false, "options": { "maxSelect": 1, "values": ["checking", "savings"] } },
            { "id": "accounts_initial_balance", "name": "initial_balance", "type": "number", "required": false, "presentable": false, "unique": false, "options": { "min": null, "max": null, "noDecimal": false } },
            { "id": "accounts_user", "name": "user", "type": "relation", "required": true, "presentable": false, "unique": false, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "minSelect": null, "maxSelect": 1, "displayFields": null } }
        ],
        "listRule": "user = @request.auth.id",
        "viewRule": "user = @request.auth.id",
        "createRule": "user = @request.auth.id",
        "updateRule": "user = @request.auth.id",
        "deleteRule": "user = @request.auth.id",
        "options": {}
    });

    // 2. Members
    ensureCollection({
        "id": "members000000",
        "name": "members",
        "type": "base",
        "system": false,
        "schema": [
            { "id": "members_name", "name": "name", "type": "text", "required": true, "presentable": true, "unique": false, "options": { "min": null, "max": null, "pattern": "" } },
            { "id": "members_icon", "name": "icon", "type": "text", "required": false, "presentable": false, "unique": false, "options": { "min": null, "max": null, "pattern": "" } },
            { "id": "members_user", "name": "user", "type": "relation", "required": true, "presentable": false, "unique": false, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "minSelect": null, "maxSelect": 1, "displayFields": null } }
        ],
        "listRule": "user = @request.auth.id",
        "viewRule": "user = @request.auth.id",
        "createRule": "user = @request.auth.id",
        "updateRule": "user = @request.auth.id",
        "deleteRule": "user = @request.auth.id",
        "options": {}
    });

    // 3. Categories
    ensureCollection({
        "id": "categories000000",
        "name": "categories",
        "type": "base",
        "system": false,
        "schema": [
            { "id": "categories_name", "name": "name", "type": "text", "required": true, "presentable": true, "unique": false, "options": { "min": null, "max": null, "pattern": "" } },
            { "id": "categories_icon", "name": "icon_code_point", "type": "number", "required": true, "presentable": false, "unique": false, "options": { "min": null, "max": null, "noDecimal": true } },
            { "id": "categories_color", "name": "color_hex", "type": "text", "required": true, "presentable": false, "unique": false, "options": { "min": null, "max": null, "pattern": "" } },
            { "id": "categories_is_system", "name": "is_system", "type": "bool", "required": false, "presentable": false, "unique": false, "options": {} },
            { "id": "categories_user", "name": "user", "type": "relation", "required": true, "presentable": false, "unique": false, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "minSelect": null, "maxSelect": 1, "displayFields": null } }
        ],
        "listRule": "user = @request.auth.id",
        "viewRule": "user = @request.auth.id",
        "createRule": "user = @request.auth.id",
        "updateRule": "user = @request.auth.id",
        "deleteRule": "user = @request.auth.id",
        "options": {}
    });

    // 4. Recurrences
    ensureCollection({
        "id": "recurrences000",
        "name": "recurrences",
        "type": "base",
        "system": false,
        "schema": [
            { "id": "recurrences_amount", "name": "amount", "type": "number", "required": true, "presentable": false, "unique": false, "options": { "min": null, "max": null, "noDecimal": false } },
            { "id": "recurrences_label", "name": "label", "type": "text", "required": true, "presentable": true, "unique": false, "options": { "min": null, "max": null, "pattern": "" } },
            { "id": "recurrences_type", "name": "type", "type": "select", "required": true, "presentable": false, "unique": false, "options": { "maxSelect": 1, "values": ["income", "expense", "transfer"] } },
            { "id": "recurrences_frequency", "name": "frequency", "type": "select", "required": true, "presentable": false, "unique": false, "options": { "maxSelect": 1, "values": ["daily", "weekly", "biweekly", "monthly", "bimonthly", "yearly"] } },
            { "id": "recurrences_day", "name": "day_of_month", "type": "number", "required": false, "presentable": false, "unique": false, "options": { "min": 1, "max": 31, "noDecimal": true } },
            { "id": "recurrences_next", "name": "next_due_date", "type": "date", "required": true, "presentable": false, "unique": false, "options": { "min": "", "max": "" } },
            { "id": "recurrences_active", "name": "active", "type": "bool", "required": false, "presentable": false, "unique": false, "options": {} },
            { "id": "recurrences_acct", "name": "account", "type": "relation", "required": true, "presentable": false, "unique": false, "options": { "collectionId": "accounts000000", "cascadeDelete": true, "minSelect": null, "maxSelect": 1, "displayFields": null } },
            { "id": "recurrences_target", "name": "target_account", "type": "relation", "required": false, "presentable": false, "unique": false, "options": { "collectionId": "accounts000000", "cascadeDelete": false, "minSelect": null, "maxSelect": 1, "displayFields": null } }, // New Field
            { "id": "recurrences_user", "name": "user", "type": "relation", "required": true, "presentable": false, "unique": false, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "minSelect": null, "maxSelect": 1, "displayFields": null } }
        ],
        "listRule": "user = @request.auth.id",
        "viewRule": "user = @request.auth.id",
        "createRule": "user = @request.auth.id",
        "updateRule": "user = @request.auth.id",
        "deleteRule": "user = @request.auth.id",
        "options": {}
    });

    // 5. Transactions
    ensureCollection({
        "id": "transactions00",
        "name": "transactions",
        "type": "base",
        "system": false,
        "schema": [
            { "id": "transactions_amount", "name": "amount", "type": "number", "required": true, "presentable": false, "unique": false, "options": { "min": null, "max": null, "noDecimal": false } },
            { "id": "transactions_label", "name": "label", "type": "text", "required": true, "presentable": true, "unique": false, "options": { "min": null, "max": null, "pattern": "" } },
            { "id": "transactions_type", "name": "type", "type": "select", "required": true, "presentable": false, "unique": false, "options": { "maxSelect": 1, "values": ["income", "expense", "transfer"] } },
            { "id": "transactions_date", "name": "date", "type": "date", "required": true, "presentable": false, "unique": false, "options": { "min": "", "max": "" } },
            { "id": "transactions_status", "name": "status", "type": "select", "required": true, "presentable": false, "unique": false, "options": { "maxSelect": 1, "values": ["projected", "effective"] } },
            { "id": "transactions_is_auto", "name": "is_automatic", "type": "bool", "required": false, "presentable": false, "unique": false, "options": {} },
            { "id": "transactions_acct", "name": "account", "type": "relation", "required": true, "presentable": false, "unique": false, "options": { "collectionId": "accounts000000", "cascadeDelete": true, "minSelect": null, "maxSelect": 1, "displayFields": null } },
            { "id": "transactions_cat", "name": "category", "type": "text", "required": false, "presentable": false, "unique": false, "options": { "min": null, "max": null, "pattern": "" } },
            { "id": "transactions_recur", "name": "recurrence", "type": "relation", "required": false, "presentable": false, "unique": false, "options": { "collectionId": "recurrences000", "cascadeDelete": false, "minSelect": null, "maxSelect": 1, "displayFields": null } },
            { "id": "transactions_member", "name": "member", "type": "relation", "required": false, "presentable": false, "unique": false, "options": { "collectionId": "members000000", "cascadeDelete": false, "minSelect": null, "maxSelect": 1, "displayFields": null } },
            { "id": "transactions_target", "name": "target_account", "type": "relation", "required": false, "presentable": false, "unique": false, "options": { "collectionId": "accounts000000", "cascadeDelete": false, "minSelect": null, "maxSelect": 1, "displayFields": null } }, // New Field
            { "id": "transactions_user", "name": "user", "type": "relation", "required": true, "presentable": false, "unique": false, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "minSelect": null, "maxSelect": 1, "displayFields": null } }
        ],
        "listRule": "user = @request.auth.id",
        "viewRule": "user = @request.auth.id",
        "createRule": "user = @request.auth.id",
        "updateRule": "user = @request.auth.id",
        "deleteRule": "user = @request.auth.id",
        "options": {}
    });

    // 6. Raw Inbox
    ensureCollection({
        "id": "rawinbox000000",
        "name": "raw_inbox",
        "type": "base",
        "system": false,
        "schema": [
            { "id": "rawinbox_date", "name": "date", "type": "date", "required": true, "presentable": false, "unique": false, "options": { "min": "", "max": "" } },
            { "id": "rawinbox_label", "name": "label", "type": "text", "required": true, "presentable": true, "unique": false, "options": { "min": null, "max": null, "pattern": "" } },
            { "id": "rawinbox_amount", "name": "amount", "type": "number", "required": false, "presentable": false, "unique": false, "options": { "min": null, "max": null, "noDecimal": false } },
            { "id": "rawinbox_user", "name": "user", "type": "relation", "required": true, "presentable": false, "unique": false, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "minSelect": null, "maxSelect": 1, "displayFields": null } },
            { "id": "rawinbox_proc", "name": "is_processed", "type": "bool", "required": false, "presentable": false, "unique": false, "options": {} },
            { "id": "rawinbox_payl", "name": "raw_payload", "type": "text", "required": false, "presentable": false, "unique": false, "options": { "min": null, "max": null, "pattern": "" } },
            { "id": "rawinbox_meta", "name": "metadata", "type": "json", "required": false, "presentable": false, "unique": false, "options": { "maxSize": 2000000 } }
        ],
        "listRule": "user = @request.auth.id",
        "viewRule": "user = @request.auth.id",
        "createRule": "",
        "updateRule": "user = @request.auth.id",
        "deleteRule": "user = @request.auth.id",
        "options": {}
    });

    // 7. Settings
    ensureCollection({
        "id": "settings000000",
        "name": "settings",
        "type": "base",
        "system": false,
        "schema": [
            { "id": "settings_fiscal", "name": "fiscal_day_start", "type": "number", "required": true, "presentable": false, "unique": false, "options": { "min": 1, "max": 31, "noDecimal": true } },
            { "id": "settings_user", "name": "user", "type": "relation", "required": true, "presentable": false, "unique": false, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "minSelect": null, "maxSelect": 1, "displayFields": null } },
            { "id": "set_parsers", "name": "active_parsers", "type": "json", "required": false, "presentable": false, "unique": false, "options": { "maxSize": 2000000 } }
        ],
        "listRule": "user = @request.auth.id",
        "viewRule": "user = @request.auth.id",
        "createRule": "user = @request.auth.id",
        "updateRule": "user = @request.auth.id",
        "deleteRule": "user = @request.auth.id",
        "options": {}
    });

}, (db) => {
    // Migration revert is dangerous if we are doing upserts. 
    // We typically don't want to delete tables on revert in this context, 
    // or we only delete if we know we created them. 
    // For safety in this "Idempotent/Repair" mode, we might leave revert empty or comment it out.
    // If the user manually reverts, they might expect deletion. 
    // But since this is a "Full Schema" snapshot, reverting it implies going to empty?
    // Let's keep the deletes but only if they exist.
    const dao = new Dao(db);
    try { dao.deleteCollection(dao.findCollectionByNameOrId("settings")); } catch (_) { }
    try { dao.deleteCollection(dao.findCollectionByNameOrId("raw_inbox")); } catch (_) { }
    try { dao.deleteCollection(dao.findCollectionByNameOrId("transactions")); } catch (_) { }
    try { dao.deleteCollection(dao.findCollectionByNameOrId("recurrences")); } catch (_) { }
    try { dao.deleteCollection(dao.findCollectionByNameOrId("categories")); } catch (_) { }
    try { dao.deleteCollection(dao.findCollectionByNameOrId("members")); } catch (_) { }
    try { dao.deleteCollection(dao.findCollectionByNameOrId("accounts")); } catch (_) { }
})
