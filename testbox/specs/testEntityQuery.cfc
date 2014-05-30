component displayName="I test the EntityQuery CFC" extends="testbox.system.testing.BaseSpec"{

	// executes before all tests
	function beforeTests(){
		request.dao = new com.database.dao( dsn = "dao" );
		request.bmo = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );
	}

	function createNewEntityQueryInstance() test{
		var test = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );

		$assert.isTrue( isInstanceOf( test, "com.database.BaseModelObject" ) );
	}

	function from() test{

		var query = request.bmo.from( "eventLog" );

		//var results = query.from('eventLog').run();

		// return a query object containing the full results of the given table
		$assert.typeOf( "struct", query );
		$assert.isTrue( query.getCriteria().from == "eventLog" );

	}

	function where() test{
		var bmo = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );
		var query = bmo.from( "eventLog" ).where( "ID", ">=", 5 );

		$assert.typeOf( "struct", query.getCriteria() );
		$assert.typeOf( "array", query.getCriteria().where );
        $assert.includes( query.getCriteria().where[1], "WHERE `ID` >=" );
	}

	function andWhere() test{
		var bmo = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );
		var query = bmo.from( "eventLog" )
					.where( "ID", "<=", 5 )
					.andWhere( "ID", ">=", 1)
					.andWhere( "event", "=", "delete")
					.orWhere( "event", "=", "insert");
		$assert.typeOf( "struct", query.getCriteria() );
        $assert.typeOf( "array", query.getCriteria().where );

        $assert.includes( query.getCriteria().where[1], "WHERE `ID` <=" );
        $assert.includes( query.getCriteria().where[2], "AND `ID` >=" );
	}

	function orderBy() test{
		var bmo = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );
		var query = bmo.from( "eventLog" )
					.where( "ID", "<=", 5 )
					.andWhere( "ID", ">=", 1)
					.andWhere( "event", "=", "delete")
					.orWhere( "event", "=", "insert")
					.orderBy("eventDate desc");
		$assert.typeOf( "struct", query.getCriteria() );

        $assert.includes( query.getCriteria().orderBy, "eventDate desc" );

	}

	function limit() test{
		var bmo = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );
		var query = bmo.from( "eventLog" )
					.where( "ID", "<=", 5 )
					.andWhere( "ID", ">=", 1)
					.andWhere( "event", "=", "delete")
					.orWhere( "event", "=", "insert")
					.orderBy("eventDate desc")
					.limit(15);
		$assert.typeOf( "struct", query.getCriteria() );

        $assert.isTrue( query.getCriteria().limit == 15 );
	}

	function limitAll() test{
		var bmo = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );
		var query = bmo.from( "eventLog" )
					.where( "ID", "<=", 5 )
					.andWhere( "ID", ">=", 1)
					.andWhere( "event", "=", "delete")
					.orWhere( "event", "=", "insert")
					.orderBy("eventDate desc")
					.limit("*");
		$assert.typeOf( "struct", query.getCriteria() );

        $assert.isTrue( query.getCriteria().limit == "*" );
	}

	function testrun() test{
		var bmo = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );
		var query = bmo.from( "eventLog" )
					.where( "ID", "<=", 5 )
					.andWhere( "ID", ">=", 1)
					.beginGroup("or")
						.andWhere( "event", "=", "delete")
						.orWhere( "event", "=", "insert")
					.endGroup()
					.orderBy("eventDate desc")
					.limit(15);
		$assert.typeOf( "struct", query.getCriteria() );

		var results = query.run();
		// writeDump(results);

        $assert.typeOf( "query", results );
	}
	function testrunNoLimit() test{
		var bmo = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );
		var query = bmo.from( "eventLog" )
					.where( 1, "=", 1 )

					.beginGroup("and")
						.andWhere( "ID", ">=", 1)
						.beginGroup("or")
							.andWhere( "event", "=", "delete")
							.orWhere( "event", "=", "insert")
						.endGroup()
					.endGroup()
					.orderBy("eventDate desc");
		$assert.typeOf( "struct", query.getCriteria() );

		var results = query.run();


        $assert.typeOf( "query", results );

        results = query.from("TodoItem").where(1,"=",1).andWhere("isArchived","=",1).run();
		writeDump(results);


	}
	// executes after all tests
	function afterTests(){

		//structClear( application );

	}

}