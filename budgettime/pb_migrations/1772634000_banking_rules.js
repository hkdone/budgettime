migrate((app) => {
    // 1. Bank Connections
    const conn = app.findCollectionByNameOrId("v2conn000000001");
    if (conn) {
        conn.listRule = "user = @request.auth.id";
        conn.viewRule = "user = @request.auth.id";
        conn.deleteRule = "user = @request.auth.id";
        app.save(conn);
    }

    // 2. Bank Accounts
    const acc = app.findCollectionByNameOrId("v2acc0000000001");
    if (acc) {
        acc.listRule = "connection_id.user = @request.auth.id";
        acc.viewRule = "connection_id.user = @request.auth.id";
        acc.deleteRule = "connection_id.user = @request.auth.id";
        app.save(acc);
    }

    // 3. Bank Sync Logs
    const logs = app.findCollectionByNameOrId("v2logs000000001");
    if (logs) {
        logs.listRule = "connection_id.user = @request.auth.id";
        logs.viewRule = "connection_id.user = @request.auth.id";
        app.save(logs);
    }
}, (app) => {
    // Revert: Supprimer les règles
    const collections = ["v2conn000000001", "v2acc0000000001", "v2logs000000001"];
    collections.forEach(id => {
        const c = app.findCollectionByNameOrId(id);
        if (c) {
            c.listRule = null;
            c.viewRule = null;
            c.deleteRule = null;
            app.save(c);
        }
    });
})
