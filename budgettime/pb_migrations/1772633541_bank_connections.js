migrate((app) => {
    // 1. Suppression préventive si une ancienne version cassée existe
    try {
        const existing = app.findCollectionByNameOrId("v2conn000000001");
        if (existing) app.dao().deleteCollection(existing);
    } catch (_) { }

    const collection = new Collection({
        "id": "v2conn000000001",
        "name": "bank_connections",
        "type": "base",
        "system": false,
        "schema": [
            {
                "id": "v2conn_user",
                "name": "user",
                "type": "relation",
                "required": true,
                "options": {
                    "collectionId": "_pb_users_auth_",
                    "cascadeDelete": true,
                    "maxSelect": 1
                }
            },
            { "id": "v2conn_bank", "name": "bank_name", "type": "text", "required": true },
            { "id": "v2conn_reqid", "name": "requisition_id", "type": "text", "required": true, "unique": true },
            { "id": "v2conn_valid", "name": "valid_until", "type": "date", "required": true },
            { "id": "v2conn_logo", "name": "bank_logo", "type": "text", "required": false }
        ],
        "options": {}
    });

    // 2. Sauvegarde initiale du Schéma via le DAO (Direct)
    // Cela évite la validation des règles gourmande en cache de app.save()
    app.dao().saveCollection(collection);

    // 3. Récupération forcée pour rafraîchir le cache interne du validateur
    const fresh = app.findCollectionByNameOrId("v2conn000000001");
    fresh.listRule = "user = @request.auth.id";
    fresh.viewRule = "user = @request.auth.id";
    fresh.deleteRule = "user = @request.auth.id";

    return app.dao().saveCollection(fresh);
}, (app) => {
    const collection = app.findCollectionByNameOrId("v2conn000000001");
    if (collection) app.dao().deleteCollection(collection);
})
