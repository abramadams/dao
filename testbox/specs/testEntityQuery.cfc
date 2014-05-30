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
		var query = request.bmo.from( "eventLog" ).where( "ID", ">=", 5 );

          $assert.typeOf( "struct", query.getCriteria() );
          $assert.typeOf( "array", query.getCriteria().where );
          $assert.isTrue( query.getCriteria().where[1] == "WHERE `ID` >= 5" );
	}

	function andWhere() test{
		var query = request.bmo.from( "eventLog" )
					.where( "ID", ">=", 5 )
					.andWhere( "ID", "<=", 1)
					.andWhere( "event", "=", "delete")
					.orWhere( "event", "=", "insert");
		$assert.typeOf( "struct", query.getCriteria() );
          $assert.typeOf( "array", query.getCriteria().where );
          writeDump( query.getCriteria().where );
          $assert.isTrue( query.getCriteria().where[1] == "WHERE `ID` >= 5" );
          $assert.isTrue( query.getCriteria().where[2] == "AND `ID` <= 1" );
	}

	function orderBy() test{
		$assert.fail('test not implemented yet');
	}

	function limit(){
		$assert.fail('test not implemented yet');
	}
	// executes after all tests
	function afterTests(){

		//structClear( application );

	}

}