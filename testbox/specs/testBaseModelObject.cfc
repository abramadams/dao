component displayName="My test suite" extends="testbox.system.BaseSpec"{

     // executes before all tests
     function beforeTests(){
		request.dao = new com.database.dao( dsn = "dao" );
     }

     function createNewEntityInstance() test{
     	var testEntity = new model.EventLog( dao = request.dao );

     	$assert.isTrue( isInstanceOf( testEntity, "com.database.BaseModelObject" ) );
     }

     function loadRecordByID() test{
     	var testEntity = new model.EventLog( dao = request.dao );

     	testEntity.load(208);
          if( testEntity.getID() != 208 ){
               // writeDump(testEntity);abort;
          }
     	$assert.isTrue( testEntity.getID() GT 0 );
     }

    function getRecordByIDZero() test{
     	var testEntity = new model.EventLog( dao = request.dao );

     	var qry = testEntity.getRecord( 0 );
     	//Should return an empty query
     	$assert.typeOf( "query", qry );
     	$assert.isTrue( qry.recordCount eq 0 );
	}

    function getRecordSingleID() test{
     	var testEntity = new model.EventLog( dao = request.dao );
     	// call getRecord with ID
     	qry = testEntity.getRecord( 208 );
     	// should return a single record
		$assert.typeOf( "query", qry );
     	$assert.isTrue( qry.recordCount eq 1 );
	}

    function getRecordSingleFromInstantiatedObject() test{
     	var testEntity = new model.EventLog( dao = request.dao );
     	// call getRecord on instantiated object without ID
     	testEntity.load( 208 );
     	qry = testEntity.getRecord();

     	// should return a single record
		$assert.typeOf( "query", qry );

     	$assert.isTrue( qry.recordCount eq 1 );
     }

     function loadRecordByIDAndEvent() test{
     	var testEntity = new model.EventLog( dao = request.dao );

     	testEntity.loadByIDAndEvent(208,'delete');

     	$assert.isTrue( testEntity.getID() GT 0 );
     }

     function populateNewEntityWithStruct() test{
     	var testEntity = new model.EventLog( dao = request.dao );
     	var testStruct = { event = 'test', eventdate = now() };

     	testEntity.populate( testStruct );

     	$assert.isTrue( testEntity.getEvent() eq 'test' );
     }

     function populateExistingEntityWithStruct() test{
     	var testEntity = new model.EventLog( dao = request.dao );
     	var testStruct = { event = 'delete', id = 208 };

     	testEntity.populate( testStruct );

     	$assert.isTrue( testEntity.getEvent() eq 'delete' && !testEntity.isNew() );
     }

     function loadChangeAndSaveEntity() test{
          // var testEntity = new model.EventLog( dao = request.dao );
     	var testEntity = new com.database.BaseModelObject( table = "eventLog", dao = request.dao );

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
     	var testEntity = new model.EventLog( dao = request.dao, cacheEntities = true, debugMode = false );

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
     	var testEntity = new model.EventLog( dao = request.dao );

     	// change event to 'test'
     	testEntity.loadFirstByEvent( 'test insert' );

     	// now entity's getEvent should return 'test'
		$assert.isTrue( testEntity.getEvent() eq 'test insert' && testEntity.getID() gt 0 );
		// isNew should be false now
		$assert.isFalse( testEntity.isNew() );

		$assert.typeOf( "struct", testEntity.toStruct() );

     }

     function loadExistingEntityToJSON() test{
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
     	var testEntity = new model.EventLog( dao = request.dao );

     	// change event to 'test'
     	var list = testEntity.listAsArray( where = "where `event` = 'test insert'" );

     	// now list should contain an array of records (structs)
		$assert.typeOf( "array", list );

		$assert.typeOf( "struct", list[1] );
		$assert.isTrue( structKeyExists( list[1], 'event' ) );

     }

     function listRecords() test{
     	var testEntity = new model.EventLog( dao = request.dao );

     	// change event to 'test'
     	var list = testEntity.list( where = "where `event` = 'test insert'" );

     	// now list should contain an array of records (structs)
		$assert.typeOf( "query", list );

		$assert.isTrue( list.recordCount );

     }

     function getSingleRecordByID() test{
     	var testEntity = new model.EventLog( dao = request.dao );

     	// change event to 'test'
     	var list = testEntity.get( 208 );

     	// now list should contain an array of records (structs)
		$assert.typeOf( "query", list );

		$assert.isTrue( list.recordCount eq 1 );

     }

     function getRecordFromCurrentEntityInstance() test{
     	var testEntity = new model.EventLog( dao = request.dao );

     	testEntity.load( 208 );
     	// change event to 'test'
     	var list = testEntity.get();

     	// now list should contain an array of records (structs)
		$assert.typeOf( "query", list );

		$assert.isTrue( list.recordCount );

     }

     function validateEntityState() test{
     	var testEntity = new model.EventLog( dao = request.dao );

     	testEntity.load( 208 );
     	// validate initial state of entity
     	var errors = testEntity.validate();
     	// now list should contain an array of records (structs)
		$assert.typeOf( "array", errors );
		$assert.isTrue( arrayLen( errors ) == 0 );
		// load bogus data
		testEntity.populate( {ID = 'abc', eventDate = now() } );

		// now validate the invalid state of the entity
		errors = testEntity.validate();
		//writeDump([errors, testEntity]);abort;
		$assert.typeOf( "array", errors );
		$assert.isTrue( arrayLen( errors ) == 1 );
     }
///////////// Implicit Invocation
     function createImplicitEntity() test{
     	var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );

     	$assert.isTrue( isInstanceOf( testEntity, "com.database.BaseModelObject" ) );
     }

	function ImplicitloadRecordByID() test{
     	var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );

     	testEntity.load(208);

     	$assert.isTrue( testEntity.getID() GT 0 );
     }

    function ImplicitgetRecordByIDZero() test{
     	var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );

     	var qry = testEntity.getRecord( 0 );
     	//Should return an empty query
     	$assert.typeOf( "query", qry );
     	$assert.isTrue( qry.recordCount eq 0 );
	}

    function ImplicitgetRecordSingleID() test{
     	var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );
     	// call getRecord with ID
     	qry = testEntity.getRecord( 208 );
     	// should return a single record
		$assert.typeOf( "query", qry );
     	$assert.isTrue( qry.recordCount eq 1 );
	}

    function ImplicitgetRecordSingleFromInstantiatedObject() test{
     	var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );
     	// call getRecord on instantiated object without ID
     	testEntity.load( 208 );
     	qry = testEntity.getRecord();
     	// should return a single record
		$assert.typeOf( "query", qry );
     	$assert.isTrue( qry.recordCount eq 1 );
     }

     function ImplicitloadRecordByIDAndEvent() test{
     	var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );

     	testEntity.loadByIDAndEvent(208,'delete');

     	$assert.isTrue( testEntity.getID() GT 0 );
     }

     function ImplicitpopulateNewEntityWithStruct() test{
     	var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );
     	var testStruct = { event = 'test', eventdate = now() };

     	testEntity.populate( testStruct );

     	$assert.isTrue( testEntity.getEvent() eq 'test' );
     }

     function ImplicitpopulateExistingEntityWithStruct() test{
     	var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );
     	var testStruct = { event = 'delete', id = 208 };

     	testEntity.populate( testStruct );
          // writeDump( testEntity );abort;
     	$assert.isTrue( testEntity.getEvent() eq 'delete' && !testEntity.isNew() );
     }

     function ImplicitloadChangeAndSaveEntity() test{
     	var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );

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
     	var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );

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
     	var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );

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
     	var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );

     	// change event to 'test'
     	testEntity.loadFirstByEvent( 'test insert' );

     	// now entity's getEvent should return 'test'
		$assert.isTrue( testEntity.getEvent() eq 'test insert' && testEntity.getID() gt 0 );
		// isNew should be false now
		$assert.isFalse( testEntity.isNew() );
		// now delete the entity
		testEntity.delete();

		$assert.isTrue( testEntity.getEvent() eq '' && testEntity.getID() lte 0 );

     }

     function ImplicitloadExistingEntityToStruct() test{
     	var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );

     	// change event to 'test'
     	testEntity.loadFirstByEvent( 'test insert' );

     	// now entity's getEvent should return 'test'
		$assert.isTrue( testEntity.getEvent() eq 'test insert' && testEntity.getID() gt 0 );
		// isNew should be false now
		$assert.isFalse( testEntity.isNew() );

		$assert.typeOf( "struct", testEntity.toStruct() );

     }

     function ImplicitloadExistingEntityToJSON() test{
     	var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );

     	// change event to 'test'
     	testEntity.loadFirstByEvent( 'test insert' );

     	// now entity's getEvent should return 'test'
		$assert.isTrue( testEntity.getEvent() eq 'test insert' && testEntity.getID() gt 0 );
		// isNew should be false now
		$assert.isFalse( testEntity.isNew() );

		$assert.typeOf( "struct", deSerializeJSON( testEntity.toJSON() ) );

     }

     function ImplicitlistAsArray() test{
     	var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );

     	// change event to 'test'
     	var list = testEntity.listAsArray( where = "where `event` = 'test insert'" );

     	// now list should contain an array of records (structs)
		$assert.typeOf( "array", list );

		$assert.typeOf( "struct", list[1] );
		$assert.isTrue( structKeyExists( list[1], 'event' ) );

     }

     function ImplicitlistRecords() test{
     	var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );

     	// change event to 'test'
     	var list = testEntity.list( where = "where `event` = 'test insert'" );

     	// now list should contain an array of records (structs)
		$assert.typeOf( "query", list );

		$assert.isTrue( list.recordCount );

     }

     function ImplicitgetSingleRecordByID() test{
     	var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );

     	// change event to 'test'
     	var list = testEntity.get( 208 );

     	// now list should contain an array of records (structs)
		$assert.typeOf( "query", list );

		$assert.isTrue( list.recordCount eq 1 );

     }

     function ImplicitgetRecordFromCurrentEntityInstance() test{
     	var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );

     	testEntity.load( 208 );
     	// change event to 'test'
     	var list = testEntity.get();

     	// now list should contain an array of records (structs)
		$assert.typeOf( "query", list );
          // if( !list.recordcount ){
          //      writeDump([testEntity, list]);abort;
          // }
		$assert.isTrue( list.recordCount );

     }

     function ImplicitvalidateEntityState() test{
     	var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "eventLog" );

     	testEntity.load( 208 );
     	// validate initial state of entity
     	var errors = testEntity.validate();
     	// now list should contain an array of records (structs)
		$assert.typeOf( "array", errors );

		$assert.isTrue( arrayLen( errors ) == 0 );

		// load bogus data
		testEntity.populate( {ID = 'abc', eventDate = "not a date people" } );


		// now validate the invalid state of the entity
		errors = testEntity.validate();
		//writeDump([errors, testEntity]);abort;
		$assert.typeOf( "array", errors );
		$assert.isTrue( arrayLen( errors ) == 2 );
     }


     function testDynamicHasRelatedEntities() test{
          var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "pets", autowire = true );

          testEntity.load( 93 );
          testEntity.belongsTo( table = "users", fkcolumn = "userID", property = "user" );
          // writeDump( [ testEntity.hasUser(), testEntity.getUser() ] );
          // // $assert.isTrue( testEntity.hasUser() );
          // writeDump( testEntity );abort;
          $assert.isFalse( testEntity.User.getID() == "" );


     }


     function testInjectProperty() test{
           var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "pets" );

           testEntity.setFakeProperty( 'test' );
           $assert.isTrue( testEntity.getFakeProperty() == 'test' );
     }


     function testNewWithData() test{
          var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "pets" );

          testEntity.load( 93 );
          $assert.isTrue( testEntity.getId() == 93 );

          var data = testEntity.toStruct();
          data.modifiedDate = now();
          data.createdDate = now();

          var testEntity2 = testEntity.new( data );
          // writeDump( [data, testEntity2 ] );abort;
          $assert.isTrue( testEntity2.isNew() );
          testEntity2.save();
          $assert.isTrue( testEntity2.getId() != 93 );
          $assert.isFalse( testEntity2.isNew() );

     }
     function testNewWithoutData() test{
          var testEntity = new com.database.BaseModelObject( dao = request.dao, table = "pets" );

          testEntity.load( 93 );
          $assert.isTrue( testEntity.getId() == 93 );

          var testEntity2 = testEntity.new();

          $assert.isTrue( testEntity2.isNew() );
          testEntity2.save();
          $assert.isTrue( testEntity2.getId() != 93 );
          $assert.isFalse( testEntity2.isNew() );

     }

     // executes after all tests
     function afterTests(){

     	//structClear( application );

     }

}