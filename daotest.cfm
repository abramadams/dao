<cfscript>
	// Pure dao examples:	
	dao = new com.database.dao( dsn = "dao" );

	// Insert data
	writeOutput("<h2>Insert data via table def</h2>");
	DATA = { "_id" = lcase(createUUID()), "first_name" = "Abram" , "last_name" = "Adams", "email" = "aadams@cfxchange.com", "created_datetime" = now()};
	newID = dao.insert(table = "users", data = DATA, onFinish = afterInsert );
	writeDump('Created record ID: ' & newID);

	// Insert data (using mysql specific replace into syntax )
	writeOutput("<h2>Insert data via SQL</h2>");
	newID2 = dao.execute("
		REPLACE INTO users (id, `_id`, first_name, last_name, email, created_datetime)
		VALUES ( 1
				,#dao.queryParam(lcase(createUUID()),'varchar')#
				,#dao.queryParam('john')#
				,#dao.queryParam('deere')#
				,#dao.queryParam('jdeere@tractor.com')#
				,#dao.queryParam(now(), 'timestamp')#
			   )
	");
	writeDump('Created record ID: ' & newID2);

	// read data (all users)
	writeOutput("<h2>return all users</h2>");
	results1 = dao.read('users');
	writeDump(results1);
	
	// read data (all users selective columns)
	writeOutput("<h2>return all users (selective columns)</h2>");
	results2 = dao.read('SELECT first_name, last_name FROM users');
	writeDump(results2);	

	// read data (filter user by name)
	writeOutput("<h2>return specific users</h2>");
	results3 = dao.read('SELECT first_name, last_name FROM users WHERE first_name = #dao.queryParam('john')#');
	writeDump(results3);	

	// read data from query
	writeOutput("<h2>query of query</h2>");
	results4 = dao.read(sql = 'SELECT * FROM results', QoQ = { name = "results", query = results1 });
	writeDump(results4);	

	//update data
	writeOutput("<h2>update user via table def</h2>");
	DATA.id = newID;
	DATA.last_name = "Bond";
	dao.update( table = "users", data = DATA, onFinish = afterUpdate );

	writeDump( dao.read("select * from users where ID = #dao.queryParam(newID)#") );

	writeOutput("<h2>update user via execute</h2>");
	dao.execute("
		UPDATE users
		SET first_name = #dao.queryParam('Jason')#
		WHERE id = #dao.queryParam(newID2)#
	");
	writeDump( dao.read("select * from users where ID = #dao.queryParam(newID2)#") );
	
	writeOutput("<h2>update user via table def - DRY RUN MODE</h2>");
	DATA = { "id" = newID2,  "last_name" = "Deere" };
	writeDump( dao.update( table = "users", data = DATA, dryRun = true ) );

	writeOutput("<h2>insert user via table def - DRY RUN MODE</h2>");
	DATA = { "_id" = lcase(createUUID()), "first_name" = "Johnny", "last_name" = "Dangerously", "email" = "jdangerously@coolguy.com" };
	writeDump( dao.insert( table = "users", data = DATA, dryRun = true ) );

	// Delete specific record
	dao.delete(table = 'users', recordID = newID, onFinish = afterDelete); 
	// Delete all records
	dao.delete(table = 'users', recordID = '*', onFinish = afterDelete); 

	// Callback functions for insert/update/delete
	public function afterUpdate( data ){		
		this.execute( "
				INSERT INTO eventLog( `event`, `description`, `eventDate` )
				VALUES (
				 #this.queryParam('update')#
				,#this.queryParam('updated #data.ID#')#
				,#this.queryParam(now(),'timestamp')#
				)
			" );		
	}
	public function afterInsert( data ){	
		this.execute( "
				INSERT INTO eventLog( `event`, `description`, `eventDate` )
				VALUES (
				 #this.queryParam('insert')#
				,#this.queryParam('inserted #data.ID#')#
				,#this.queryParam(now(),'timestamp')#
				)
			" );		
	}
	public function afterDelete( data ){	
		this.execute( "
				INSERT INTO eventLog( `event`, `description`, `eventDate` )
				VALUES (
				 #this.queryParam('delete')#
				,#this.queryParam('deleted #data.ID#')#
				,#this.queryParam(now(),'timestamp')#
				)
			" );		
	}


</cfscript>