<!--- <cfquery name="test" datasource="dao">
	SELECT `id`,`description`,`event`,`eventdate`
	FROM eventLog where `event` in( <cfqueryparam cfsqltype="cf_sql_varchar" list="true" value="test insert, test delete,''"> )
</cfquery>
<cfdump var="#test#" abort> --->
<cfscript>
	// Pure dao examples:

	dao = new com.database.dao( dsn = "dao" );
	/*
	 By default the dao will detect the dbtype based on the datasource
	 and will use the appropriate "connector" if available ( currently
	 only mssql and mysql are supported ). However you can optionally
	 pass it in ( i.e. if using a third party driver/JDBC driver )
	 i.e.:
		dao = new com.database.dao( dsn = "myDB", dbtype = "mysql" );
	*/
 	users = dao.read("users");
	johns = dao.read( sql = "
	        SELECT first_name, last_name
	        FROM userQuery
	        WHERE lower(first_name) like :firstName
	   ",
	   params = { firstName = 'john%' },
	   QoQ = { userQuery = users}
	);

    writeDump([users,johns]);
	array = dao.read(sql="eventLog",returnType="array", orderby = 'EVENTDATE desc', limit = 10);
	writeDump(array);
	json = dao.read(sql="eventLog",returnType="json", orderby = 'EVENTDATE desc', limit = 10);
	writeDump(json);
	// Generate the event log table used to track data interaction
	if ( dao.getDBtype()  == "mssql" ){
		// MSSQL specific
		dao.execute( "
			IF NOT EXISTS ( SELECT * FROM sysobjects WHERE name = 'eventLog' AND xtype = 'U' )
				CREATE TABLE eventLog (
					ID int NOT NULL IDENTITY (1, 1),
					userID int NULL,
					event varchar(50) NULL,
					description text NULL,
					eventDate date NULL
				)
			" );
	} else if ( dao.getDBtype() == "mysql" ){

		// MySQL specific
		 dao.execute( "
			CREATE TABLE IF NOT EXISTS `eventLog` (
			  `ID` int(11) unsigned NOT NULL AUTO_INCREMENT,
			  `userID` varchar(255) DEFAULT NULL,
			  `event` varchar(255) DEFAULT NULL,
			  `description` varchar(255) DEFAULT NULL,
			  `eventDate` datetime DEFAULT NULL,
			  PRIMARY KEY (`ID`)
			)
		" );
	}


	// Insert data
	writeOutput("<h2>Insert data via table def</h2>");
	DATA = { "_id" = lcase(createUUID()), "first_name" = "Abram" , "last_name" = "Adams", "email" = "aadams@cfxchange.com", "created_datetime" = now()};

	newID = dao.insert(table = "users", data = DATA, onFinish = afterInsert );
	writeDump('Created record ID: ' & newID);

	// Insert data
	writeOutput("<h2>Insert data via SQL</h2>");
	newID2 = dao.execute("
		INSERT INTO users (_id, first_name, last_name, email, created_datetime)
		VALUES ( #dao.queryParam(lcase(createUUID()),'varchar')#
				,#dao.queryParam('john')#
				,#dao.queryParam('deere')#
				,#dao.queryParam('jdeere@tractor.com')#
				,#dao.queryParam(now(), 'timestamp')#
			   )
	");
	writeDump('Created record ID: ' & newID2);

	// read data (filter user by name)
	writeOutput("<h2>return specific users with multiple tokenized params</h2>");
	results3a = dao.read(table="users", where = "where 1=1 and first_name = #dao.queryParam('john')#' and last_name = #dao.queryParam('deere')# and 1 in(1,2,3)" );
	writeDump(results3a);

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
	results4 = dao.read(sql = 'SELECT * FROM results', QoQ = { results = results1 });
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
	dao.delete(table = 'TodoItem', recordID = '*', onFinish = afterDelete);

	// Callback functions for insert/update/delete
	public function afterUpdate( response ){
		// Simple audit logger, could get much more detailed.
		var description = "Updated table: #response.table# ID: #response.data.ID# -- ";
		for( var change in response.changes ){
			description &= "Changed #change.column# from '#change.original#' to '#change.new#'. ";
		}
		description &= " -- at #now()#";
		this.execute( "
				INSERT INTO eventLog( event, description, eventDate )
				VALUES (
				 #this.queryParam('update')#
				,#this.queryParam(description)#
				,#this.queryParam(now(),'timestamp')#
				)
			" );
	}
	public function afterInsert( data ){
		this.execute( "
				INSERT INTO eventLog( event, description, eventDate )
				VALUES (
				 #this.queryParam('insert')#
				,#this.queryParam('inserted #data.ID#')#
				,#this.queryParam(now(),'timestamp')#
				)
			" );
	}
	public function afterDelete( data ){
		// writeDump(arguments.data);abort;
		this.execute( "
				INSERT INTO eventLog( event, description, eventDate )
				VALUES (
				 #this.queryParam('delete')#
				,#this.queryParam('deleted #data.ID#')#
				,#this.queryParam(now(),'timestamp')#
				)
			" );
	}


</cfscript>
