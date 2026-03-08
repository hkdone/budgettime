migrate((app) => {
    try {
        const conn = app.findCollectionByNameOrId("bank_connections");
        conn.updateRule = "user = @request.auth.id";
        app.save(conn);
        console.log("Updated bank_connections updateRule");
    } catch (e) {
        console.log("Error updating bank_connections: " + e);
    }

    try {
        const acc = app.findCollectionByNameOrId("bank_accounts");
        acc.updateRule = "connection_id.user = @request.auth.id";
        app.save(acc);
        console.log("Updated bank_accounts updateRule");
    } catch (e) {
        console.log("Error updating bank_accounts: " + e);
    }
}, (app) => {
    // optional revert
});
