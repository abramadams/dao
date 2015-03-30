component displayName="My test suite" extends="testbox.system.BaseSpec"{

     // executes before all tests
     function beforeTests(){
		request.dao = new com.database.dao( dsn = "dao" );

     }


     function loadExistingEntityWithChildrenToStruct() test{
     	var testEntity = new model.Pet( dao = request.dao );

     	// change event to 'test'
     	testEntity.load(93);
          var testStruct = testEntity.toStruct();
          $assert.typeOf( "struct",  testStruct );
          $assert.isTrue( structKeyExists( testStruct, 'user' ) );
		$assert.typeOf( "struct", testStruct.user );

     }
    // executes after all tests
     function afterTests(){

     	//structClear( application );

     }

}