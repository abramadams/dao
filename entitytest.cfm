<cfscript>

    dao = new com.database.dao( dsn = "dao", autoParameterize = true );
    /*
     By default the dao will detect the dbtype based on the datasource
     and will use the appropriate "connector" if available ( currently
     only mssql and mysql are supported ). However you can optionally
     pass it in ( i.e. if using a third party driver/JDBC driver )
     i.e.:
        dao = new com.database.dao( dsn = "myDB", dbtype = "mysql" );
    */

    testEntity = new com.database.BaseModelObject( table = "eventLog", dao = dao, cachedWithin = createTimeSpan(0,0,0,20) );


    list = testEntity.listAsArray( where = "where `event` = 'test insert'" );

    list2 = testEntity.listAsArray( where = "where `event` in( 'test insert', 'test delete', 'fred\'s list' )");

    writeDump(var=list, label="EventLog List where event == 'test insert'");
    writeDump(var=list2, label="EventLog List where event IN in( 'test insert', 'test delete', 'fred\'s list' )");


    todoItem = new examples.breezejs.model.TodoItem( dao = dao );
    todoItem.setDescription('Food');
    todoItem.setIsArchived(false);
    todoItem.setIsDone(false);
    todoItem.save();

	writeDump(var=todoItem, label="todoItem Food");

	// test the breezejs integration:
    todoItem = new examples.breezejs.model.TodoItem( dao = dao );
    filter = "(isArchived eq false) and (description ne '')";
    orderby = "description";
	breezeData = todoItem.listAsBreezeData(
						filter = filter,
						orderby = orderby
					);
	writeDump(var=breezeData, label="breezeData");
   /**
    * eventLog = new model.EventLog( dao = dao );
    * The above code should essentially be equivalent to the below line
    * eventLog = new com.database.BaseModelObject( dao = dao, table = "eventLog");
    *
    * NOTE that the eventLog table must exist when instantiating the object this way.
    * when instantiating using the entity's cfc directly (i.e. new EventLog) it will
    * automatically create the table based on the properties if the table does not
    * exist
    **/

    user = new model.User( dao = dao );
    user.setFirstName('James');
    user.setLastName('Bond');
    user.save();

    todoItem = new examples.breezejs.model.TodoItem( dao = dao );
    todoItem.setDescription('Food');
    todoItem.setIsArchived(false);
    todoItem.setIsDone(false);
    todoItem.save();

    user2 = new model.User( dao = dao );
    user2.setFirstName('Johnny');
    user2.setLastName('Bond');
    user2.save();

	user3 = new model.User( dao = dao );
    user3.setFirstName('Johnny');
    user3.setLastName('Dangerously');
    user3.save();

    pet = new model.Pet( dao = dao, dropcreate = false );
    pet.setFirstName('dog');
    pet.setUser( user );
    writeDump(pet);
    pet.save();

    eventLog = new model.EventLog( dao = dao );
    eventLog.setevent('event');
    eventLog.setDescription('Long description goes here');
    eventLog.setUser(user);
    eventLog.save();
	writeDump(var=eventLog, label="eventLog Item");

    // users = user.lazyloadAllByLastName( 'Bond' );
    // writeDump(users);
    users = user.loadAll();
    writeDump( user.loadAll() );

    writeOutput("user.toJSON()");
    writeOutput("<pre>#user.toJSON()#</pre>");
    writeOutput("user.listAsJSON()");
    writeOutput("<pre>#user.listAsJSON()#</pre>");

</cfscript>
