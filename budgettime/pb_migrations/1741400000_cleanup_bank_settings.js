migrate((app) => {
    try {
        const collection = app.findCollectionByNameOrId("bank_settings");
        if (collection) {
            app.delete(collection);
        }
    } catch (e) {
        // Silencieusement ignorer si déjà supprimée
    }

    // Petite correction pour bank_connections si besoin (user, bank_name, requisition_id, valid_until)
    // Mais on garde le schéma utilisateur actuel pour la stabilité.
}, (app) => {
    // Reverse non nécessaire pour un nettoyage
});
