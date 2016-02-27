component displayName="My test suite" extends="testbox.system.BaseSpec"{

		 // executes before all tests
		 function beforeTests(){
		request.dao = new com.database.dao( dsn = "dao" );

		 }
		 function beforeEach(){
					// Some setup data
					request.dao.execute("delete from eventLog where event = 'test insert'");
					request.dao.execute("
							 INSERT INTO eventLog (event,description,eventDate)
							 VALUES
							 ('test insert', '#hash(createUUID())#', #createODBCDateTime(now())#),
							 ('test insert', '#hash(createUUID())#', #createODBCDateTime(now())#),
							 ('test insert', '#hash(createUUID())#', #createODBCDateTime(now())#),
							 ('test insert', '#hash(createUUID())#', #createODBCDateTime(now())#)

							 ");
		 }

		 function createNewEntityInstance() test{
					beforeEach();
					var testEntity = new model.EventLog( dao = request.dao );

					$assert.isTrue( isInstanceOf( testEntity, "com.database.Norm" ) );
		 }

		 function createNewEntityInstanceWithoutProvidingDAO() test{
					beforeEach();
					var testEntity = new com.database.Norm( table = "users" );

					$assert.isTrue( isInstanceOf( testEntity, "com.database.Norm" ) );
		 }
		 function createNewEntityInstanceWithoutProvidingDAOOrTable() test{
					beforeEach();

			 var testEntity = createObject("component", "com.database.Norm");
					$assert.throws( target = function(){ testEntity.init();} , type = "NORM.setTable" );

		 }

		 function loadRecordByID() test{
					beforeEach();
			 var testEntity = new model.EventLog( dao = request.dao );

			 testEntity.load(208);
					if( testEntity.getID() != 208 ){
							 // writeDump(testEntity);abort;
					}
			 $assert.isTrue( testEntity.getID() GT 0 );
		 }

		function getRecordByIDZero() test{
		 beforeEach();
			 var testEntity = new model.EventLog( dao = request.dao );

			 var qry = testEntity.getRecord( 0 );
			 //Should return an empty query
			 $assert.typeOf( "query", qry );
			 $assert.isTrue( qry.recordCount eq 0 );
	}

		function getRecordSingleID() test{
		 beforeEach();
			 var testEntity = new model.EventLog( dao = request.dao );
			 // call getRecord with ID
			 qry = testEntity.getRecord( 208 );
			 // should return a single record
		$assert.typeOf( "query", qry );
			 $assert.isTrue( qry.recordCount eq 1 );
	}

		function getRecordSingleFromInstantiatedObject() test{
		 beforeEach();
			 var testEntity = new model.EventLog( dao = request.dao );
			 // call getRecord on instantiated object without ID
			 testEntity.load( 208 );
			 qry = testEntity.getRecord();

			 // should return a single record
		$assert.typeOf( "query", qry );

			 $assert.isTrue( qry.recordCount eq 1 );
		 }

		 function loadRecordByIDAndEvent() test{
					beforeEach();
			 var testEntity = new model.EventLog( dao = request.dao );

			 testEntity.loadByIDAndEvent(208,'delete');

			 $assert.isTrue( testEntity.getID() GT 0 );
		 }

		 function populateNewEntityWithStruct() test{
					beforeEach();
			 var testEntity = new model.EventLog( dao = request.dao );
			 var testStruct = { event = 'test', eventdate = now() };

			 testEntity.populate( testStruct );

			 $assert.isTrue( testEntity.getEvent() eq 'test' );
		 }

		 function populateExistingEntityWithStruct() test{
					beforeEach();
			 var testEntity = new model.EventLog( dao = request.dao );
			 var testStruct = { event = 'delete', id = 208 };

			 testEntity.populate( testStruct );

			 $assert.isTrue( testEntity.getEvent() eq 'delete' && !testEntity.isNew() );
		 }

		 function loadChangeAndSaveEntity() test{
					beforeEach();
					// var testEntity = new model.EventLog( dao = request.dao );
			 var testEntity = new com.database.Norm( table = "eventLog", dao = request.dao );

					testEntity.load( 208 );

					$assert.isTrue( testEntity.getID() == 208 );
					// proove that "event" == delete
					$assert.isTrue( testEntity.getEvent() eq 'delete' );
					// change event to 'test'
					testEntity.setEvent('test');
					// save changes
					testEntity.save();

					// now entity's getEvent should return 'test'
		$assert.isTrue( testEntity.getEvent() eq 'test' && testEntity.getID() == 208 );

			 testEntity.setEvent('delete');
		testEntity.save();

		$assert.isTrue( testEntity.getEvent() eq 'delete' && testEntity.getID() == 208 );
		 }

		 function loadBlankEntityChangeAndSave() test{
					beforeEach();
					var testEntity = new model.EventLog( dao = request.dao );

					// loaded blank entity
					$assert.isTrue( testEntity.isNew() );
					// change event to 'test'
					testEntity.setEvent('test insert');
					testEntity.setEventDate(now());
					// save changes
					testEntity.save();
					// now entity's getEvent should return 'test'
					$assert.isTrue( testEntity.getEvent() eq 'test insert' && testEntity.getID() gt 0 );

		 }

		 function loadBlankEntityChangeAndSaveThenChangeAndSaveAgain() test {
			 var testEntity = new model.EventLog( dao = request.dao );

			 // loaded blank entity
			 $assert.isTrue( testEntity.isNew() );
			 // change event to 'test'
			 testEntity.setEvent('test insert');
			 testEntity.setEventDate(now());
			 // save changes
					testEntity.save();
					// now entity's getEvent should return 'test'
					$assert.isTrue( testEntity.getEvent() eq 'test insert' && testEntity.getID() gt 0 );

					// change event to 'test'
					testEntity.setEvent('not a test insert');
					testEntity.setEventDate(now());

					// save changes
			 testEntity.save();

					// now entity's getEvent should return 'test'
		$assert.isTrue( testEntity.getEvent() eq 'not a test insert' && testEntity.getID() gt 0 );

		 }

		 function loadBlankEntityChangeAndSaveThenDelete() test{
				beforeEach();
				var testEntity = new model.EventLog( dao = request.dao );

				// loaded blank entity
				$assert.isTrue( testEntity.isNew() );
				// change event to 'test'
				testEntity.setEvent('loadBlankEntityChangeAndSaveThenDelete');
				testEntity.setEventDate(now());
				// save changes
				testEntity.save();
				// now entity's getEvent should return 'test'
				$assert.isTrue( testEntity.getEvent() eq 'loadBlankEntityChangeAndSaveThenDelete' && testEntity.getID() gt 0 );
				// isNew should be false now
				$assert.isFalse( testEntity.isNew() );
				// now delete the entity
				//writeDump(testEntity);
				testEntity.delete();

				$assert.isTrue( testEntity.getEvent() eq '' && testEntity.getID() lte 0 );

		 }

		 function loadExistingEntityThenDelete() test{
					beforeEach();
			 var testEntity = new model.EventLog( dao = request.dao );

			 // change event to 'test'
			 testEntity.loadFirstByEvent( 'test insert' );
					// writeDump( testEntity );abort;
			 // now entity's getEvent should return 'test'
		$assert.isTrue( testEntity.getEvent() eq 'test insert' && testEntity.getID() gt 0 );
		// isNew should be false now
		$assert.isFalse( testEntity.isNew() );
		// now delete the entity
		testEntity.delete();

		$assert.isTrue( testEntity.getEvent() eq '' && testEntity.getID() lte 0 );

		 }

		 function loadExistingEntityToStruct() test{
					beforeEach();
					var testEntity = new model.EventLog( dao = request.dao );

					// change event to 'test'
					testEntity.loadFirstByEvent( 'test insert' );

					// now entity's getEvent should return 'test'
					$assert.isTrue( testEntity.getEvent() eq 'test insert' );
					$assert.isTrue(	testEntity.getID() gt 0 );

					// isNew should be false now
					$assert.isFalse( testEntity.isNew() );

					$assert.typeOf( "struct", testEntity.toStruct() );

		 }
		 function loadExistingEntityWithChildrenToStruct() test{
			beforeEach();
			var testEntity = new model.Pet( dao = request.dao );

			// change event to 'test'
			testEntity.load(93);
			var testStruct = testEntity.toStruct( );
			$assert.typeOf( "struct",	testStruct );
			/*writeDUmp([testStruct,testEntity]);abort;*/
			$assert.isTrue( structKeyExists( testStruct, 'user' ) );
			$assert.typeOf( "struct", testStruct.user );

		 }

		 function loadExistingEntityToJSON() test{
					beforeEach();
			 var testEntity = new model.EventLog( dao = request.dao );

			 // change event to 'test'
			 testEntity.loadFirstByEvent( 'test insert' );
			 // now entity's getEvent should return 'test'
		$assert.isTrue( testEntity.getEvent() eq 'test insert' && testEntity.getID() gt 0 );
		// isNew should be false now
		$assert.isFalse( testEntity.isNew() );

		$assert.typeOf( "struct", deSerializeJSON( testEntity.toJSON() ) );

		 }

		 function listAsArray() test{
					beforeEach();
					var testEntity = new model.EventLog( dao = request.dao );

			 // change event to 'test'
			 var list = testEntity.listAsArray( where = "where 1=1" );

			 // now list should contain an array of records (structs)
		$assert.typeOf( "array", list );
					$assert.isTrue( arrayLen( list ) >= 1 );
		$assert.typeOf( "struct", list[1] );
					$assert.isTrue( structKeyExists( list[1], 'event' ) );
					// if( list[1].id == list[arrayLen(list)].id ){
					//			writeDump(list);abort;
					// }
		$assert.isTrue( list[1].id != list[arrayLen(list)].id );


		 }

		 function listRecords() test{
					beforeEach();
			 var testEntity = new model.EventLog( dao = request.dao );

			 // change event to 'test'
			 var list = testEntity.list( where = "where `event` = 'test insert'" );

			 // now list should contain a query object containing records
		$assert.typeOf( "query", list );

		$assert.isTrue( list.recordCount );

		 }

		 function getSingleRecordByID() test{
					beforeEach();
			 var testEntity = new model.EventLog( dao = request.dao );

			 // change event to 'test'
			 var list = testEntity.get( 208 );

			 // now list should contain an array of records (structs)
		$assert.typeOf( "query", list );

		$assert.isTrue( list.recordCount eq 1 );

		 }

		 function getRecordFromCurrentEntityInstance() test{
					beforeEach();
			 var testEntity = new model.EventLog( dao = request.dao );

			 testEntity.load( 208 );
			 // change event to 'test'
			 var list = testEntity.get();

			 // now list should contain an array of records (structs)
		$assert.typeOf( "query", list );

		$assert.isTrue( list.recordCount );

		 }

		 function validateEntityState() test{
					beforeEach();
			 var testEntity = new model.EventLog( dao = request.dao );

			 testEntity.load( 208 );
			 // validate initial state of entity
			 var errors = testEntity.validate();
			 // now list should contain an array of records (structs)
			$assert.typeOf( "array", errors );
			$assert.isTrue( arrayLen( errors ) == 0 );
			// load bogus data
			testEntity.setEventDate( now() );
			// now validate the invalid state of the entity
			errors = testEntity.validate();
			//writeDump([errors, testEntity]);abort;
			$assert.typeOf( "array", errors );
			$assert.isTrue( arrayLen( errors ) == 0 );
		 }
///////////// Implicit Invocation
		 function createImplicitEntity() test{
					beforeEach();
			 var testEntity = new com.database.Norm( dao = request.dao, table = "eventLog" );

			 $assert.isTrue( isInstanceOf( testEntity, "com.database.Norm" ) );
		 }

	function ImplicitloadRecordByID() test{
					beforeEach();
			 var testEntity = new com.database.Norm( dao = request.dao, table = "eventLog" );

			 testEntity.load(208);

			 $assert.isTrue( testEntity.getID() GT 0 );
		 }

		function ImplicitgetRecordByIDZero() test{
		 beforeEach();
			 var testEntity = new com.database.Norm( dao = request.dao, table = "eventLog" );

			 var qry = testEntity.getRecord( 0 );
			 //Should return an empty query
			 $assert.typeOf( "query", qry );
			 $assert.isTrue( qry.recordCount eq 0 );
	}

		function ImplicitgetRecordSingleID() test{
		 beforeEach();
			 var testEntity = new com.database.Norm( dao = request.dao, table = "eventLog" );
			 // call getRecord with ID
			 qry = testEntity.getRecord( 208 );
			 // should return a single record
		$assert.typeOf( "query", qry );
			 $assert.isTrue( qry.recordCount eq 1 );
	}

		function ImplicitgetRecordSingleFromInstantiatedObject() test{
		 beforeEach();
			 var testEntity = new com.database.Norm( dao = request.dao, table = "eventLog" );
			 // call getRecord on instantiated object without ID
			 testEntity.load( 208 );
			 qry = testEntity.getRecord();
			 // should return a single record
		$assert.typeOf( "query", qry );
			 $assert.isTrue( qry.recordCount eq 1 );
		 }

		 function ImplicitloadRecordByIDAndEvent() test{
					beforeEach();
			 var testEntity = new com.database.Norm( dao = request.dao, table = "eventLog" );

			 testEntity.loadByIDAndEvent(208,'delete');

			 $assert.isTrue( testEntity.getID() GT 0 );
		 }

		 function ImplicitpopulateNewEntityWithStruct() test{
					beforeEach();
			 var testEntity = new com.database.Norm( dao = request.dao, table = "eventLog", debugMode = false );
			 var testStruct = { event = 'test', eventdate = now() };

			 testEntity.populate( testStruct );
					// writeDump( [testentity,testEntity.getEvent()] );abort;
			 $assert.isTrue( testEntity.getEvent() eq 'test' );
		 }

		 function ImplicitpopulateExistingEntityWithStruct() test{
					beforeEach();
			 var testEntity = new com.database.Norm( dao = request.dao, table = "eventLog" );
			 var testStruct = { event = 'delete', id = 208 };

			 testEntity.populate( testStruct );
					// writeDump( testEntity );abort;
			 $assert.isTrue( testEntity.getEvent() eq 'delete' && !testEntity.isNew() );
		 }

		 function ImplicitloadChangeAndSaveEntity() test{
					beforeEach();
			 var testEntity = new com.database.Norm( dao = request.dao, table = "eventLog" );

			 testEntity.load( 208 );
			 // loaded record ID 208
			 $assert.isTrue( testEntity.getID() == 208 );
			 // proove that "event" == delete
			 $assert.isTrue( testEntity.getEvent() eq 'delete' );
			 // change event to 'test'
			 testEntity.setEvent('test');
			 // save changes
			 testEntity.save();
			 // now entity's getEvent should return 'test'
		$assert.isTrue( testEntity.getEvent() eq 'test' && testEntity.getID() == 208 );

			 testEntity.setEvent('delete');
		testEntity.save();

		$assert.isTrue( testEntity.getEvent() eq 'delete' && testEntity.getID() == 208 );
		 }

		 function ImplicitloadBlankEntityChangeAndSave() test{
					beforeEach();
			 var testEntity = new com.database.Norm( dao = request.dao, table = "eventLog" );

			 // loaded record ID 208
			 $assert.isTrue( testEntity.isNew() );
			 // change event to 'test'
			 testEntity.setEvent('test insert');
			 testEntity.setEventDate(now());
			 // save changes
			 testEntity.save();
			 // now entity's getEvent should return 'test'
		$assert.isTrue( testEntity.getEvent() eq 'test insert' && testEntity.getID() gt 0 );

		 }

		 function ImplicitloadBlankEntityChangeAndSaveThenDelete() test{
					beforeEach();
			 var testEntity = new com.database.Norm( dao = request.dao, table = "eventLog" );

			 // loaded blank entity
			 $assert.isTrue( testEntity.isNew() );
			 // change event to 'test'
			 testEntity.setEvent('loadBlankEntityChangeAndSaveThenDelete');
			 testEntity.setEventDate(now());
			 // save changes
			 testEntity.save();
			 // now entity's getEvent should return 'test'
		$assert.isTrue( testEntity.getEvent() eq 'loadBlankEntityChangeAndSaveThenDelete' && testEntity.getID() gt 0 );
		// isNew should be false now
		$assert.isFalse( testEntity.isNew() );
		// now delete the entity
		//writeDump(testEntity);
		testEntity.delete();

		$assert.isTrue( testEntity.getEvent() eq '' && testEntity.getID() lte 0 );

		 }

		 function ImplicitloadExistingEntityThenDelete() test{
				beforeEach();
				var testEntity = new com.database.Norm( dao = request.dao, table = "eventLog" );

				// change event to 'test'
				testEntity.loadFirstByEvent( 'test insert' );

				// now entity's getEvent should return 'test'
				$assert.isTrue( testEntity.getEvent() eq 'test insert' && testEntity.getID() gt 0 );
				// isNew should be false now
				$assert.isFalse( testEntity.isNew() );
				// now delete the entity
				testEntity.delete();
				/*writeDump( [ testEntity, testEntity.getEvent(), testEntity.getID() ]);abort;*/
				$assert.isTrue( testEntity.getEvent() eq '' && testEntity.getID() lte 0 );

		 }

		 function ImplicitloadExistingEntityToStruct() test{
					beforeEach();
			 var testEntity = new com.database.Norm( dao = request.dao, table = "eventLog" );

			 // change event to 'test'
			 testEntity.loadFirstByEvent( 'test insert' );

			 // now entity's getEvent should return 'test'
		$assert.isTrue( testEntity.getEvent() eq 'test insert' && testEntity.getID() gt 0 );
		// isNew should be false now
		$assert.isFalse( testEntity.isNew() );

		$assert.typeOf( "struct", testEntity.toStruct() );

		 }

		 function ImplicitloadExistingEntityToJSON() test{
					beforeEach();
			 var testEntity = new com.database.Norm( dao = request.dao, table = "eventLog" );

			 // change event to 'test'
			 testEntity.loadFirstByEvent( 'test insert' );

			 // now entity's getEvent should return 'test'
					$assert.isTrue( testEntity.getEvent() eq 'test insert' );
		$assert.isTrue( testEntity.getID() gt 0 );

		// isNew should be false now
		$assert.isFalse( testEntity.isNew() );

		$assert.typeOf( "struct", deSerializeJSON( testEntity.toJSON() ) );

		 }

		 function ImplicitlistAsArray() test{
					beforeEach();
			 var testEntity = new com.database.Norm( dao = request.dao, table = "eventLog" );

			 // change event to 'test'
			 var list = testEntity.listAsArray( where = "where `event` = 'test insert'" );

			 // now list should contain an array of records (structs)
		$assert.typeOf( "array", list );
					$assert.isTrue( arrayLen( list ) );
		$assert.typeOf( "struct", list[1] );
		$assert.isTrue( structKeyExists( list[1], 'event' ) );

		 }

		 function ImplicitlistRecords() test{
					beforeEach();
			 var testEntity = new com.database.Norm( dao = request.dao, table = "eventLog" );

			 // change event to 'test'
			 var list = testEntity.list( where = "where `event` = 'test insert'" );

			 // now list should contain an array of records (structs)
		$assert.typeOf( "query", list );

		$assert.isTrue( list.recordCount );

		 }

		 function ImplicitgetSingleRecordByID() test{
					beforeEach();
			 var testEntity = new com.database.Norm( dao = request.dao, table = "eventLog" );

			 // change event to 'test'
			 var list = testEntity.get( 208 );

			 // now list should contain an array of records (structs)
		$assert.typeOf( "query", list );

		$assert.isTrue( list.recordCount eq 1 );

		 }

		 function ImplicitgetRecordFromCurrentEntityInstance() test{
					beforeEach();
			 var testEntity = new com.database.Norm( dao = request.dao, table = "eventLog" );

			 testEntity.load( 208 );
			 // change event to 'test'
			 var list = testEntity.get();

			 // now list should contain an array of records (structs)
		$assert.typeOf( "query", list );
					// if( !list.recordcount ){
					//			writeDump([testEntity, list]);abort;
					// }
		$assert.isTrue( list.recordCount );

		 }

		 function ImplicitvalidateEntityState() test{
					beforeEach();
			 var testEntity = new com.database.Norm( dao = request.dao, table = "eventLog" );

			 testEntity.load( 208 );
			 // validate initial state of entity
			 var errors = testEntity.validate();
			 // now list should contain an array of records (structs)
			 $assert.typeOf( "array", errors );
			 $assert.isTrue( arrayLen( errors ) == 0 );

			// load bogus data
			/*testEntity.setID( 'abc' );*/
			testEntity.setEventDate( "not a date people" );

			// now validate the invalid state of the entity
			errors = testEntity.validate();
			/*writeDump([errors, testEntity]);abort;*/
			$assert.typeOf( "array", errors );
			/*writeDump( errors );abort;*/
			$assert.isTrue( arrayLen( errors ) == 1 );
		 }


		 function testDynamicHasRelatedEntities() test{
					beforeEach();
					var testEntity = new com.database.Norm( dao = request.dao, table = "pets", autowire = true );

					testEntity.load( 93 );
					testEntity.belongsTo( table = "users", pkColumn = "id", fkcolumn = "userID", property = "user" );
					// writeDump( [ testEntity.hasUser(), testEntity.getUser() ] );
					// // $assert.isTrue( testEntity.hasUser() );
					// writeDump( testEntity.User.getID() );abort;
					$assert.isFalse( testEntity.User.getID() == "" );


		 }


		 function testInjectProperty() test{
					beforeEach();
					 var testEntity = new com.database.Norm( dao = request.dao, table = "pets" );

					 testEntity.setFakeProperty( 'test' );
					 $assert.isTrue( testEntity.getFakeProperty() == 'test' );
		 }


		 function testNewWithData() test{
					beforeEach();
					var testEntity = new com.database.Norm( dao = request.dao, table = "pets" );

					testEntity.load( 93 );
					// writeDump( [ testEntity ] );abort;
					$assert.isTrue( testEntity.getId() == 93 );

					var data = testEntity.toStruct();
					data.modifiedDate = now();
					data.createdDate = now();

					var testEntity2 = testEntity.$new( data );
					// writeDump( [data, testEntity2 ] );abort;
					$assert.isTrue( testEntity2.isNew() );
					testEntity2.save();
					$assert.isTrue( testEntity2.getId() != 93 );
					$assert.isFalse( testEntity2.isNew() );

		 }
		 function testNewWithoutData() test{
					beforeEach();
					var testEntity = new com.database.Norm( dao = request.dao, table = "pets" );

					testEntity.load( 93 );
					$assert.isTrue( testEntity.getId() == 93 );

					var testEntity2 = testEntity.$new();

					$assert.isTrue( testEntity2.isNew() );
					testEntity2.save();
					$assert.isTrue( testEntity2.getId() != 93 );
					$assert.isFalse( testEntity2.isNew() );

		 }


		 function testInjectedPreLoadEvent() test{
					beforeEach();
					var testEntity = new com.database.Norm( dao = request.dao, table = "pets" );
					var truthy = false;
					testEntity.beforeLoad = function( entity ){
							 entity.setId( 99999 );
							 writeLog('testInjectedPreLoadEvent has access to the entity''s getID():: #entity.getId()#');
							 $assert.isTrue( entity.getId() == 99999 );
							 truthy = true;
					};
					// testEntity.preLoad = preLoad;
					testEntity.load( 93 );
					$assert.isTrue( testEntity.getId() == 93 );
					$assert.isTrue( truthy );

		 }

		 function testIsDirty() test{
					beforeEach();
					var testEntity = new com.database.Norm( dao = request.dao, table = "eventLog" );

					testEntity.loadByIDAndEvent(208,'delete');
					$assert.isFalse( testEntity.isDirty() );
					testEntity.setEvent('this is a new value');
					$assert.isTrue( testEntity.isDirty() );

		 }

		 function testQueryAsOData() test{
			beforeEach();

			var testEntity = new com.database.Norm( dao = request.dao, table = "orders" );

			var data = testEntity.serializeODataRows( request.dao.read(sql="select o.ID, oi.* from orders o join order_items oi on oi.orders_ID = o.ID limit 10",limit=10,returnType="array") );

			var meta = { "base": "orders", "page": 1, "filter": "" };
			var ret = testEntity.serializeODataResponse( 4, data, meta );

			writeDump(serializeJSON(ret));abort;
					// $assert.isTrue( testEntity.isDirty() );

		 }

		 // executes after all tests
		 function afterTests(){

			 //structClear( application );

		 }

}
