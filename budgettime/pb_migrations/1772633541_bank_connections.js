migrate((app) => {
    const collection = new Collection({
        "id": "v2conn000000001",
        "name": "bank_connections",
        "type": "base",
        "system": false,
        "schema": [
            {
                "id": "v2conn_user",
                "name": "user_id",
                "type": "relation",
                "required": true,
                "options": {
                    "collectionId": "_pb_users_auth_",
                    "cascadeDelete": true,
                    "maxSelect": 1
                }
            },
            {
                "id": "v2conn_bank",
                "name": "bank_name",
                "type": "text",
                "required": true
            },
            {
                "id": "v2conn_reqid",
                "name": "requisition_id",
                "type": "text",
                "required": true,
                "unique": true
            },
            {
                "id": "v2conn_valid",
                "name": "valid_until",
                "type": "date",
                "required": true
            },
            {
                "id": "v2conn_logo",
                "name": "bank_logo",
                "type": "text",
                "required": false
            }
        ],
        "options": {}
    });

    // 1. Sauvegarde initiale pour enregistrer les champs dans la DB
    app.save(collection);

    // 2. Application des règles (le validateur reconnaîtra désormais 'user_id')
    collection.listRule = "user_id = @request.auth.id";
    collection.viewRule = "user_id = @request.auth.id";
    collection.deleteRule = "user_id = @request.auth.id";

    return app.save(collection);
}, (app) => {
    const collection = app.findCollectionByNameOrId("v2conn000000001");
    return app.delete(collection);
})
