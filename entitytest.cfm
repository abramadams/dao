<cfscript>

    dao = new com.database.dao( dsn = "dao" );

    user = new model.User( dao = dao );
    user.setFirstName('James');
    user.setLastName('Bond');
    user.save();

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

    users = user.lazyloadAllByLastName( 'Bond' ); 
    //users = user.loadAll();
    writeDump(users);
    writeDump( user.loadAll() );
    
</cfscript> 