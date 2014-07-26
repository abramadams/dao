<cfscript>

    dao = new com.database.dao( dsn = "bullseye_dev", autoParameterize = true );
    id = 1021;
    sent = 1;
    for( a = 1; a lte 20; a++){
        LOCAL.aaData = [];
        // messages = dao.read("
        //             SELECT m.ID,mr.read,u.first_name, u.last_name, u.user_name, concat(sender.first_name, ' ', sender.last_name) as senderName, mr.status, subject, body, sent_datetime
        //             From messages m
        //             JOIN message_recipients mr on (mr.messages_ID = m.ID AND mr.status = 99)
        //             JOIN users u on u.id = mr.users_ID
        //             JOIN users sender on sender.ID = m.sender_ID
        //             WHERE m.status = 1
        //             AND mr.users_ID = #dao.queryParam(ID)#
        //             ORDER BY m.sent_datetime desc
        //         ");
        dynamicMappings = { "sender" = "users" };
        messages = new com.database.BaseModelObject( table = "messages", dao = dao, dynamicMappings = dynamicMappings )
            .loadAllBySender_IDAndStatusAsArray(sender_ID = id, status = 1, orderby = "sent_datetime desc" );
        // writeDump(messages);abort;
        for ( message in messages ){
            LOCAL.tmpStruct = { "cbx" = '<input type="checkbox" class="uniform"/>', "read" = val(!sent ? message.read : 1), "message_status" = val(message.status)};

            // CF9 doesn't like implicit structs passed in as args to the init method....
            messageObj = new com.database.BaseModelObject( table = "messages", dao = dao, dynamicMappings = dynamicMappings );
            structAppend( LOCAL.tmpStruct, messageObj.load( message.ID ).toStruct( top = 4 ), true );
            arrayAppend(LOCAL.aaData, LOCAL.tmpStruct);
            if( !structKeyExists( messageObj, 'sender' ) ){
                writeDump(['FAIL','Sender did not exist in messageObj',messageObj.toStruct( top = 4 )]);
            }
        }
        writeDump(LOCAL.aaData);
    }

    // testEntity = new com.database.BaseModelObject( dao = dao, table = "pets" );
    // testEntity.load( 93 );
    // testEntity.belongsTo( table = "users", fkcolumn = "userID", property = "user" );
    // writeDump(testEntity.toStruct() );

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
