migrate((db) => {
    const settings = db.findCollectionByNameOrId("settings000000");
    const rawinbox = db.findCollectionByNameOrId("rawinbox000000");

    // 1. Update settings to add active_parsers
    settings.schema.addField(new SchemaField({
        "system": false,
        "id": "set_parsers",
        "name": "active_parsers",
        "type": "json",
        "required": false,
        "presentable": false,
        "unique": false,
        "options": {}
    }));

    // 2. Update raw_inbox to add is_processed, raw_payload, metadata
    rawinbox.schema.addField(new SchemaField({
        "system": false,
        "id": "rawinbox_proc",
        "name": "is_processed",
        "type": "bool",
        "required": false,
        "presentable": false,
        "unique": false,
        "options": {}
    }));

    rawinbox.schema.addField(new SchemaField({
        "system": false,
        "id": "rawinbox_payl",
        "name": "raw_payload",
        "type": "text",
        "required": false,
        "presentable": false,
        "unique": false,
        "options": {
            "min": null,
            "max": null,
            "pattern": ""
        }
    }));

    rawinbox.schema.addField(new SchemaField({
        "system": false,
        "id": "rawinbox_meta",
        "name": "metadata",
        "type": "json",
        "required": false,
        "presentable": false,
        "unique": false,
        "options": {}
    }));

    return db.saveCollection(settings) && db.saveCollection(rawinbox);
}, (db) => {
    const settings = db.findCollectionByNameOrId("settings000000");
    const rawinbox = db.findCollectionByNameOrId("rawinbox000000");

    settings.schema.removeField("set_parsers");
    rawinbox.schema.removeField("rawinbox_proc");
    rawinbox.schema.removeField("rawinbox_payl");
    rawinbox.schema.removeField("rawinbox_meta");

    return db.saveCollection(settings) && db.saveCollection(rawinbox);
})
