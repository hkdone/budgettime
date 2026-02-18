/// <reference path="../pb_data/types.d.ts" />

migrate((db) => {
    const dao = new Dao(db);

    // 1. accounts
    try {
        const collection = dao.findCollectionByNameOrId("accounts");
    } catch (_) {
        const collection = new Collection({
            name: "accounts",
            type: "base",
            schema: [
                { name: "user", type: "relation", required: true, options: { collectionId: "_pb_users_auth_", maxSelect: 1, cascadeDelete: false } },
                { name: "name", type: "text", required: true },
                { name: "type", type: "select", required: true, options: { maxSelect: 1, values: ["checking", "savings", "cash"] } },
                { name: "currency", type: "text", required: false },
                { name: "initial_balance", type: "number", required: false }
            ],
            listRule: "user = @request.auth.id",
            viewRule: "user = @request.auth.id",
            createRule: "user = @request.auth.id",
            updateRule: "user = @request.auth.id",
            deleteRule: "user = @request.auth.id",
        });
        dao.saveCollection(collection);
    }

    // 2. recurrences
    try {
        const collection = dao.findCollectionByNameOrId("recurrences");
    } catch (_) {
        const collection = new Collection({
            name: "recurrences",
            type: "base",
            schema: [
                { name: "user", type: "relation", required: true, options: { collectionId: "_pb_users_auth_", maxSelect: 1, cascadeDelete: false } },
                { name: "account", type: "relation", required: true, options: { collectionId: "accounts", maxSelect: 1, cascadeDelete: false } },
                { name: "amount", type: "number", required: true },
                { name: "label", type: "text", required: true },
                { name: "type", type: "select", required: true, options: { maxSelect: 1, values: ["income", "expense", "transfer"] } },
                { name: "frequency", type: "select", required: true, options: { maxSelect: 1, values: ["daily", "weekly", "monthly", "yearly"] } },
                { name: "day_of_month", type: "number", required: false }, // For monthly
                { name: "next_due_date", type: "date", required: true },
                { name: "active", type: "bool", required: false }
            ],
            listRule: "user = @request.auth.id",
            viewRule: "user = @request.auth.id",
            createRule: "user = @request.auth.id",
            updateRule: "user = @request.auth.id",
            deleteRule: "user = @request.auth.id",
        });
        dao.saveCollection(collection);
    }

    // 3. transactions
    try {
        const collection = dao.findCollectionByNameOrId("transactions");
    } catch (_) {
        const collection = new Collection({
            name: "transactions",
            type: "base",
            schema: [
                { name: "user", type: "relation", required: true, options: { collectionId: "_pb_users_auth_", maxSelect: 1, cascadeDelete: false } },
                { name: "account", type: "relation", required: true, options: { collectionId: "accounts", maxSelect: 1, cascadeDelete: false } },
                { name: "recurrence", type: "relation", required: false, options: { collectionId: "recurrences", maxSelect: 1, cascadeDelete: false } },
                { name: "amount", type: "number", required: true },
                { name: "label", type: "text", required: true },
                { name: "type", type: "select", required: true, options: { maxSelect: 1, values: ["income", "expense", "transfer"] } },
                { name: "status", type: "select", required: true, options: { maxSelect: 1, values: ["effective", "projected"] } },
                { name: "date", type: "date", required: true },
                { name: "category", type: "text", required: false }
            ],
            listRule: "user = @request.auth.id",
            viewRule: "user = @request.auth.id",
            createRule: "user = @request.auth.id",
            updateRule: "user = @request.auth.id",
            deleteRule: "user = @request.auth.id",
        });
        dao.saveCollection(collection);
    }

    // 4. settings
    try {
        const collection = dao.findCollectionByNameOrId("settings");
    } catch (_) {
        const collection = new Collection({
            name: "settings",
            type: "base",
            schema: [
                { name: "user", type: "relation", required: true, options: { collectionId: "_pb_users_auth_", maxSelect: 1, cascadeDelete: false } },
                { name: "fiscal_day_start", type: "number", required: false, options: { min: 1, max: 31 } }
            ],
            listRule: "user = @request.auth.id",
            viewRule: "user = @request.auth.id",
            createRule: "user = @request.auth.id",
            updateRule: "user = @request.auth.id",
            deleteRule: "user = @request.auth.id",
        });
        dao.saveCollection(collection);
    }

    // 5. raw_inbox
    try {
        const collection = dao.findCollectionByNameOrId("raw_inbox");
    } catch (_) {
        const collection = new Collection({
            name: "raw_inbox",
            type: "base",
            schema: [
                { name: "user", type: "relation", required: true, options: { collectionId: "_pb_users_auth_", maxSelect: 1, cascadeDelete: false } },
                { name: "content", type: "text", required: true },
                { name: "source", type: "text", required: false },
                { name: "received_at", type: "date", required: true },
                { name: "is_processed", type: "bool", required: false },
                { name: "error_message", type: "text", required: false }
            ],
            listRule: "user = @request.auth.id",
            viewRule: "user = @request.auth.id",
            createRule: null,
            updateRule: "user = @request.auth.id",
            deleteRule: "user = @request.auth.id",
        });
        dao.saveCollection(collection);
    }

}, (db) => {
    // down logic (optional)
});
