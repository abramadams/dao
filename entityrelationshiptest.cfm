<cfscript>

    dao = new com.database.dao( dsn = "dao", autoParameterize = true );

    testEntity = new com.database.BaseModelObject( dao = dao, table = "pets" );
    testEntity.load( 93 );
    testEntity.belongsTo( table = "users", fkcolumn = "userID", property = "user" );
    writeDump(testEntity.toStruct() );

    // order = new com.database.BaseModelObject( table = "orders", dao = dao );
    // order.load(66901);
    // order.hasMany( table = "order_items", fkColumn = "orders_ID", property = "OrderItems" );

    // writeDump( order.toStruct() );


    // orderItems = new com.database.BaseModelObject( table = "order_items", dao = dao );
    // orderItems.load(148991);
    // orderItems.belongsTo( table = "orders", fkColumn = "orders_ID", pkColumn = "ID" );

    // writeDump(orderItems.toStruct());

    // message = new com.database.BaseModelObject( table = "messages", dao = dao );
    // message.load(76);
    // message.belongsTo( table = "users", fkColumn = "sender_ID", pkColumn = "ID" );

    // writeDump(message.toStruct(top=2));

    abort;

</cfscript>
