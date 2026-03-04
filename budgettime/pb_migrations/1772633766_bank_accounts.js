migrate((app) => {
    const collection = new Collection({
        "id": "v2acc0000000001",
        "name": "bank_accounts",
        "type": "base",
        "system": false,
        "schema": [
            {
                "id": "v2acc_conn",
                "name": "connection_id",
                "type": "relation",
                "required": true,
                "options": {
                    "collectionId": "v2conn000000001",
                    "cascadeDelete": true,
                    "maxSelect": 1
                }
            },
            {
                "id": "v2acc_remote",
                "name": "remote_account_id",
                "type": "text",
                "required": true,
                "unique": true
            },
            {
                "id": "v2acc_iban",
                "name": "iban",
                "type": "text",
                "required": true
            },
            {
                "id": "v2acc_localacc",
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
        "options": {}
    });

    // 1. Sauvegarde initiale pour enregistrer les champs
    app.save(collection);

    // 2. Application des règles (le validateur reconnaîtra désormais 'connection_id')
    collection.listRule = "connection_id.user_id = @request.auth.id";
    collection.viewRule = "connection_id.user_id = @request.auth.id";
    collection.deleteRule = "connection_id.user_id = @request.auth.id";

    return app.save(collection);
}, (app) => {
    const collection = app.findCollectionByNameOrId("v2acc0000000001");
    return app.delete(collection);
})
