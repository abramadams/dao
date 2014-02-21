<cfscript>
    // if MSSQL datasource - use the dao below
    //dao = new com.database.dao( dsn = "daoSQL", dbtype = "mssql" );    
    // if MySQL datasource - use the dao below
    dao = new com.database.dao( dsn = "dao" );

	// test the breezejs integration:
    todoItem = new examples.breezejs.model.TodoItem( dao = dao );
    filter = "(isArchived eq false) and (description ne '')";
    orderby = "description";
	breezeData = todoItem.listAsBreezeData( 
						filter = filter, 
						orderby = orderby
					);
	writeDump(breezeData);
   /**  
    * eventLog = new model.EventLog( dao = dao );
    * The above code should esentially be equivalent to the below line
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
    //writeDump(pet);
    pet.save();

    users = user.lazyloadAllByLastName( 'Bond' ); 
    //writeDump(users);
    //users = user.loadAll();
    //writeDump( user.loadAll() );

    writeOutput("user.toJSON()");
    writeOutput("<pre>#user.toJSON()#</pre>");
    writeOutput("user.listAsJSON()");
    writeOutput("<pre>#user.listAsJSON()#</pre>");
    
</cfscript> 