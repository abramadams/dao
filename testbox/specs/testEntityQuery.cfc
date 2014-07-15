component displayName="I test the EntityQuery CFC" extends="testbox.system.testing.BaseSpec"{

	// executes before all tests
	function beforeTests(){
		request.dao = new com.database.dao( dsn = "dao" );

	}

	function createNewEntityQueryInstance() test{
		//var test = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );

		$assert.isTrue( isInstanceOf( request.dao, "com.database.dao" ) );
	}

	function from() test{

		var query = request.dao.from( "eventLog" );

		//var results = query.from('eventLog').run();

		// return a query object containing the full results of the given table
		$assert.typeOf( "struct", query );
		$assert.isTrue( query.getCriteria().from == "eventLog" );

	}

	function where() test{
		var query = request.dao.from( "eventLog" ).where( "ID", ">=", 5 );

		$assert.typeOf( "struct", query.getCriteria() );
		$assert.typeOf( "array", query.getCriteria().clause );
        $assert.includes( query.getCriteria().clause[1], "WHERE `ID` >=" );
	}

	function andWhere() test{
		var query = request.dao.from( "eventLog" )
					.where( "ID", "<=", 5 )
					.andWhere( "ID", ">=", 1)
					.andWhere( "event", "=", "delete")
					.orWhere( "event", "=", "insert");
		$assert.typeOf( "struct", query.getCriteria() );
        $assert.typeOf( "array", query.getCriteria().clause );

        $assert.includes( query.getCriteria().clause[1], "WHERE `ID` <=" );
        $assert.includes( query.getCriteria().clause[2], "AND `ID` >=" );
	}

	function orderBy() test{
		var query = request.dao.from( "eventLog" )
					.where( "ID", "<=", 5 )
					.andWhere( "ID", ">=", 1)
					.andWhere( "event", "=", "delete")
					.orWhere( "event", "=", "insert")
					.orderBy("eventDate desc");
		$assert.typeOf( "struct", query.getCriteria() );

        $assert.includes( query.getCriteria().orderBy, "eventDate desc" );

	}

	function limit() test{
		var query = request.dao.from( "eventLog" )
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
		var query = request.dao.from( "eventLog" )
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
		var query = request.dao.from( "eventLog" )
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
		var query = request.dao.from( "eventLog" )
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
		// writeDump(results);


	}
	// executes after all tests
	function afterTests(){

		//structClear( application );

	}

}