migrate((app) => {
    try {
        const collection = app.findCollectionByNameOrId("transactions");
        const hasOrigin = collection.fields.getByName("origin");
        if (!hasOrigin) {
            collection.fields.add(new Field({
                name: "origin",
                type: "select",
                required: false,
                maxSelect: 1,
                values: ["manual", "bank", "anchor"],
            }));
            app.save(collection);
            console.log("Added transactions.origin field");
        }
    } catch (e) {
        console.log("Error adding transactions.origin: " + e);
    }
}, (app) => {
    try {
        const collection = app.findCollectionByNameOrId("transactions");
        const field = collection.fields.getByName("origin");
        if (field) {
            collection.fields.removeById(field.id);
            app.save(collection);
        }
    } catch (_) {}
});
