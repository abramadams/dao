component displayName="I test the EntityQuery CFC" extends="testbox.system.BaseSpec"{

	// executes before all tests
	function beforeTests(){
		request.dao = new com.database.dao( dsn = "dao" );

	}

	function createNewEntityQueryInstance() test{
		//var test = new com.database.Norm( dao = request.dao, table = "eventLog" );

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

	function returnAsQuery() test{
		var query = request.dao.from( "eventLog" )
					.where( 1, "=", 1 )
					.beginGroup("and")
						.andWhere( "ID", ">=", 1)
						.beginGroup("or")
							.andWhere( "event", "=", "delete")
							.orWhere( "event", "=", "insert")
						.endGroup()
					.endGroup()
					.returnAs('query')
					.orderBy("eventDate desc");
		$assert.typeOf( "struct", query.getCriteria() );
		var results = query.run();

        $assert.typeOf( "query", results );

	}
	function returnAsArray() test{
		var query = request.dao.from( "eventLog" )
					.where( 1, "=", 1 )
					.beginGroup("and")
						.andWhere( "ID", ">=", 1)
						.beginGroup("or")
							.andWhere( "event", "=", "delete")
							.orWhere( "event", "=", "insert")
						.endGroup()
					.endGroup()
					.returnAs('array')
					.orderBy("eventDate desc");
		$assert.typeOf( "struct", query.getCriteria() );
		var results = query.run();

        $assert.typeOf( "array", results );

	}

	function returnAsJSON() test{
		var query = request.dao.from( "eventLog" )
					.where( 1, "=", 1 )
					.beginGroup("and")
						.andWhere( "ID", ">=", 1)
						.beginGroup("or")
							.andWhere( "event", "=", "delete")
							.orWhere( "event", "=", "insert")
						.endGroup()
					.endGroup()
					.returnAs('json')
					.orderBy("eventDate desc");
		$assert.typeOf( "struct", query.getCriteria() );
		var results = query.run();

        $assert.typeOf( "string", results );
        $assert.typeOf( "array", deSerializeJSON(results) );

	}


	function simpleJoin() test{

		var query = request.dao.from( table = "pets", columns = "pets.ID as petId, users.ID as userID, pets.firstname as petName, users.first_name as ownerName" )
					.join( type = "LEFT", table = "users", on = "users.id = pets.userId")
					.where( "pets.ID", "=", 93 );

		$assert.typeOf( "struct", query.getCriteria() );
		$assert.typeOf( "array", query.getCriteria().joins );
		$assert.isTrue( arrayLen( query.getCriteria().joins ) );

		var results = query.run();
		$assert.isTrue( results.recordCount != 0 );
		$assert.isTrue( results.ownerName  eq 'james' );

	}

	function shorthandJoin() test{
		var query = request.dao.from(
						table = "pets",
						columns = "pets.ID as petId, users.ID as userID, pets.firstname as petName, users.first_name as ownerName",
						joins = [{ type: "LEFT", table: "users", on: "users.id = pets.userId"}] )
					.where( "pets.ID", "=", 93 );

		$assert.typeOf( "struct", query.getCriteria() );
		$assert.typeOf( "array", query.getCriteria().joins );
		$assert.isTrue( arrayLen( query.getCriteria().joins ) );

		var results = query.run();
		$assert.isTrue( results.recordCount != 0 );
		$assert.isTrue( results.ownerName  eq 'james' );

	}

	function joinWithColumns() test{
		var query = request.dao.from( table = "pets")
					.join( type = "LEFT", table = "users", on = "users.id = pets.userId", columns = "users.ID as userID, users.first_name as ownerName" )
					.where( "pets.ID", "=", 93 );

		$assert.typeOf( "struct", query.getCriteria() );
		$assert.typeOf( "array", query.getCriteria().joins );
		$assert.isTrue( arrayLen( query.getCriteria().joins ) );

		var results = query.run();
		$assert.isTrue( results.recordCount != 0 );
		$assert.isTrue( results.ownerName  eq 'james' );

	}

	function shorthandJoinWithColumns() test{
		var query = request.dao.from(
						table = "pets",
						joins = [{ type: "LEFT", table: "users", on: "users.id = pets.userId", columns: "users.ID as userID, users.first_name as ownerName"}] )
					.where( "pets.ID", "=", 93 );

		$assert.typeOf( "struct", query.getCriteria() );
		$assert.typeOf( "array", query.getCriteria().joins );
		$assert.isTrue( arrayLen( query.getCriteria().joins ) );

		var results = query.run();
		$assert.isTrue( results.recordCount != 0 );
		$assert.isTrue( results.ownerName  eq 'james' );

	}


	// executes after all tests
	function afterTests(){

		//structClear( application );

	}

}