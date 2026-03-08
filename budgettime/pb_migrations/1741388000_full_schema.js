migrate((app) => {
    const configs = [
        {
            "id": "accounts0000000",
            "name": "accounts",
            "type": "base",
            "fields": [
                { "id": "accounts_name_", "name": "name", "type": "text", "required": true, "options": { "presentable": true } },
                { "id": "accounts_curr_", "name": "currency", "type": "text", "required": true },
                { "id": "accounts_extid", "name": "external_id", "type": "text", "required": false },
                { "id": "accounts_type_", "name": "type", "type": "select", "required": true, "options": { "maxSelect": 1, "values": ["checking", "savings", "cash"] } },
                { "id": "accounts_initia", "name": "initial_balance", "type": "number", "required": false },
                { "id": "accounts_user_", "name": "user", "type": "relation", "required": true, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 } }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        },
        {
            "id": "members00000000",
            "name": "members",
            "type": "base",
            "fields": [
                { "id": "members_name__", "name": "name", "type": "text", "required": true, "options": { "presentable": true } },
                { "id": "members_icon__", "name": "icon", "type": "text", "required": false },
                { "id": "members_user__", "name": "user", "type": "relation", "required": true, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 } }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        },
        {
            "id": "categories00000",
            "name": "categories",
            "type": "base",
            "fields": [
                { "id": "categories_name", "name": "name", "type": "text", "required": true, "options": { "presentable": true } },
                { "id": "categories_icon", "name": "icon_code_point", "type": "number", "required": true, "options": { "noDecimal": true } },
                { "id": "categories_colo", "name": "color_hex", "type": "text", "required": true },
                { "id": "categories_syst", "name": "is_system", "type": "bool", "required": false },
                { "id": "categories_user", "name": "user", "type": "relation", "required": true, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 } }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        },
        {
            "id": "recurrences0000",
            "name": "recurrences",
            "type": "base",
            "fields": [
                { "id": "recur_amount___", "name": "amount", "type": "number", "required": true },
                { "id": "recur_label____", "name": "label", "type": "text", "required": true, "options": { "presentable": true } },
                { "id": "recur_type_____", "name": "type", "type": "select", "required": true, "options": { "maxSelect": 1, "values": ["income", "expense", "transfer"] } },
                { "id": "recur_freq_____", "name": "frequency", "type": "select", "required": true, "options": { "maxSelect": 1, "values": ["daily", "weekly", "biweekly", "monthly", "bimonthly", "yearly"] } },
                { "id": "recur_day______", "name": "day_of_month", "type": "number", "required": false, "options": { "min": 1, "max": 31, "noDecimal": true } },
                { "id": "recur_next_____", "name": "next_due_date", "type": "date", "required": true },
                { "id": "recur_active___", "name": "active", "type": "bool", "required": false },
                { "id": "recur_account__", "name": "account", "type": "relation", "required": true, "options": { "collectionId": "accounts0000000", "cascadeDelete": true, "maxSelect": 1 } },
                { "id": "recur_target___", "name": "target_account", "type": "relation", "required": false, "options": { "collectionId": "accounts0000000", "cascadeDelete": false, "maxSelect": 1 } },
                { "id": "recur_user_____", "name": "user", "type": "relation", "required": true, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 } }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        },
        {
            "id": "transactions000",
            "name": "transactions",
            "type": "base",
            "fields": [
                { "id": "trans_amount___", "name": "amount", "type": "number", "required": false },
                { "id": "trans_label____", "name": "label", "type": "text", "required": true, "options": { "presentable": true } },
                { "id": "trans_type_____", "name": "type", "type": "select", "required": true, "options": { "maxSelect": 1, "values": ["income", "expense", "transfer"] } },
                { "id": "trans_date_____", "name": "date", "type": "date", "required": true },
                { "id": "trans_status___", "name": "status", "type": "select", "required": true, "options": { "maxSelect": 1, "values": ["projected", "effective"] } },
                { "id": "trans_isauto___", "name": "is_automatic", "type": "bool", "required": false },
                { "id": "trans_account__", "name": "account", "type": "relation", "required": true, "options": { "collectionId": "accounts0000000", "cascadeDelete": true, "maxSelect": 1 } },
                { "id": "trans_category_", "name": "category", "type": "text", "required": false },
                { "id": "trans_recur____", "name": "recurrence", "type": "relation", "required": false, "options": { "collectionId": "recurrences0000", "cascadeDelete": false, "maxSelect": 1 } },
                { "id": "trans_member___", "name": "member", "type": "relation", "required": false, "options": { "collectionId": "members00000000", "cascadeDelete": false, "maxSelect": 1 } },
                { "id": "trans_target___", "name": "target_account", "type": "relation", "required": false, "options": { "collectionId": "accounts0000000", "cascadeDelete": false, "maxSelect": 1 } },
                { "id": "trans_user_____", "name": "user", "type": "relation", "required": true, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 } }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        },
        {
            "id": "rawinbox0000000",
            "name": "raw_inbox",
            "type": "base",
            "fields": [
                { "id": "rawinbox_date__", "name": "date", "type": "date", "required": true },
                { "id": "rawinbox_label_", "name": "label", "type": "text", "required": true, "options": { "presentable": true } },
                { "id": "rawinbox_amount", "name": "amount", "type": "number", "required": false },
                { "id": "rawinbox_user__", "name": "user", "type": "relation", "required": true, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 } },
                { "id": "rawinbox_proc__", "name": "is_processed", "type": "bool", "required": false },
                { "id": "rawinbox_payl__", "name": "raw_payload", "type": "text", "required": false },
                { "id": "rawinbox_meta__", "name": "metadata", "type": "json", "required": false }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        },
        {
            "id": "settings0000000",
            "name": "settings",
            "type": "base",
            "fields": [
                { "id": "settings_fiscal", "name": "fiscal_day_start", "type": "number", "required": true, "options": { "min": 1, "max": 31, "noDecimal": true } },
                { "id": "settings_user_", "name": "user", "type": "relation", "required": true, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 } }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        },
        {
            "id": "bankconn0000000",
            "name": "bank_connections",
            "type": "base",
            "fields": [
                { "id": "bc_user________", "name": "user", "type": "relation", "required": true, "options": { "collectionId": "_pb_users_auth_", "cascadeDelete": true, "maxSelect": 1 } },
                { "id": "bc_bank_name___", "name": "bank_name", "type": "text", "required": false },
                { "id": "bc_req_id______", "name": "requisition_id", "type": "text", "required": true },
                { "id": "bc_status______", "name": "status", "type": "text", "required": false },
                { "id": "bc_valid_until_", "name": "valid_until", "type": "date", "required": false }
            ],
            "listRule": "user = @request.auth.id",
            "viewRule": "user = @request.auth.id",
            "createRule": "user = @request.auth.id",
            "updateRule": "user = @request.auth.id",
            "deleteRule": "user = @request.auth.id"
        },
        {
            "id": "bankacc00000000",
            "name": "bank_accounts",
            "type": "base",
            "fields": [
                { "id": "ba_connection__", "name": "connection_id", "type": "relation", "required": true, "options": { "collectionId": "bankconn0000000", "cascadeDelete": true, "maxSelect": 1 } },
                { "id": "ba_remote_id___", "name": "remote_account_id", "type": "text", "required": true },
                { "id": "ba_iban________", "name": "iban", "type": "text", "required": false },
                { "id": "ba_local_acc___", "name": "local_account_id", "type": "relation", "required": false, "options": { "collectionId": "accounts0000000", "cascadeDelete": false, "maxSelect": 1 } }
            ],
            "listRule": "@request.auth.id != ''",
            "viewRule": "@request.auth.id != ''",
            "createRule": "@request.auth.id != ''",
            "updateRule": "@request.auth.id != ''",
            "deleteRule": "@request.auth.id != ''"
        },
        {
            "id": "banksync0000000",
            "name": "bank_sync_logs",
            "type": "base",
            "fields": [
                { "id": "bs_connection__", "name": "connection_id", "type": "relation", "required": true, "options": { "collectionId": "bankconn0000000", "cascadeDelete": true, "maxSelect": 1 } },
                { "id": "bs_status______", "name": "status", "type": "text", "required": true },
                { "id": "bs_trans_count_", "name": "transactions_count", "type": "number", "required": false }
            ],
            "listRule": "@request.auth.id != ''",
            "viewRule": "@request.auth.id != ''",
            "createRule": "@request.auth.id != ''",
            "updateRule": "@request.auth.id != ''",
            "deleteRule": "@request.auth.id != ''"
        }
    ];

    for (const c of configs) {
        let collection;
        try {
            collection = app.findCollectionByNameOrId(c.name);
        } catch (_) {
            collection = new Collection({
                "id": c.id,
                "name": c.name,
                "type": c.type
            });
        }

        collection.fields = c.fields;
        collection.listRule = c.listRule;
        collection.viewRule = c.viewRule;
        collection.createRule = c.createRule;
        collection.updateRule = c.updateRule;
        collection.deleteRule = c.deleteRule;

        app.save(collection);
    }

    try {
        const col = app.findCollectionByNameOrId("bank_settings");
        app.delete(col);
    } catch (_) { }
}, (app) => { })
