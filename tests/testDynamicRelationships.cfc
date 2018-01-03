component displayName="I test NORM's Dynamic Relationships" extends="testbox.system.BaseSpec"{

	// executes before all tests
	function beforeTests(){
		request.dao = new com.database.dao( dsn = "dao" );
	}

	function createNewEntityInstance() test{
		var testEntity = new model.EventLog( dao = request.dao );

		$assert.isTrue( isInstanceOf( testEntity, "com.database.Norm" ) );
	}

	function loadEntityAndDynamicOneToManyChildEntityUsingFKNamingConvention() test{
		var product = new com.database.Norm( table = "products", dao = request.dao, autoWire = true );

		$assert.isTrue( isInstanceOf( product, "com.database.Norm" ) );
		$assert.isTrue( product.isNew() );

		product.load(1);

		$assert.isTrue( product.getName() == 'Gloves' );
		// Now see if the child entities were loaded (dynamically by <table>_ID pattern)

		$assert.isTrue( product.getProduct_Classes().getID() == 1 );


	}

	function loadEntityAndDynamicOneToManyChildEntityUsingFKNamingConventionAndSaveChildRecord() test{
		var product = new com.database.Norm( table = "products", dao = request.dao, autoWire = true, debugMode = false );

		request.dao.execute("update product_classes set name = 'Apparel' where ID = 1");
		$assert.isTrue( isInstanceOf( product, "com.database.Norm" ) );
		$assert.isTrue( product.isNew() );

		product.load(1);

		$assert.isTrue( product.getName() == 'Gloves' );
		$assert.isTrue( product.getProduct_Classes().getName() == 'Apparel' );

		product.getProduct_Classes().setName( 'TEMP-TEST' );
		$assert.isTrue( product.getProduct_Classes().getName() == 'TEMP-TEST' );
		product.save();

		var prodClassNameTest = request.dao.read("select name from product_classes where ID = 1");
		$assert.isTrue( prodClassNameTest.name == 'TEMP-TEST' );

		product.getProduct_Classes().setName( 'Apparel' );

		product.save();
		prodClassNameTest = request.dao.read("select name from product_classes where ID = 1 ");
		$assert.isTrue( prodClassNameTest.name == 'Apparel' );


	}

	function loadEntityAndDynamicOneToManyChildEntityUsingDynamicMappings() test{
		var product = new com.database.Norm(
									table = "products",
									dao = request.dao,
									autowire = true,
									dynamicMappings = { "product_classes_ID" = { table = "product_classes", property = "productClass", key = "product_classes_ID" } }
								  );


		$assert.isTrue( isInstanceOf( product, "com.database.Norm" ) );
		$assert.isTrue( product.isNew() );

		product.load(1);

		$assert.isTrue( product.getName() == 'Gloves' );
		// Now see if the child entities were loaded (dynamically by <table>_ID pattern)
		// writeDump(product.getProductClass().getID());abort;
		$assert.isTrue( product.getProductClass().getID() == 1 );

	}

    function loadEntityAndDynamicManyToOneChildEntity() test{
		var company = new com.database.Norm( table = "companies", dao = request.dao );

		$assert.isTrue( isInstanceOf( company, "com.database.Norm" ) );
		$assert.isTrue( company.isNew() );

		company.load(5);

		$assert.isTrue( company.getName() == 'MR R SHANKS' );
		// Now see if the child entities were loaded (dynamically by <table>_ID pattern)
		company.hasMany( table = "call_notes", fkColumn = "companies_ID", property = "CallNotes" );
		$assert.isTrue( company.hasCallNotes() );
		// writeDump(company.getCallNotes().toStruct());

	}

    function loadEntityByCFCAndDynamicManyToOneChildEntity() test{
		var company = new Company();

		$assert.isTrue( isInstanceOf( company, "com.database.Norm" ) );
		$assert.isTrue( company.isNew() );

		company.load(5);

		$assert.isTrue( company.getName() == 'MR R SHANKS' );

		// Now see if the child entities were loaded (dynamically by <table>_ID pattern)
		$assert.isTrue( company.hasCallNotes() );
		// writeDump( company.getCallNotes().toStruct() );
		$assert.isTrue( company.getCallNotes().len() == 7 );
		$assert.isTrue( company.getCallNotes()[5].getID() == 5 );

	}

    function loadEntityByCFCAndDynamicManyToOneChildEntityAsArray() test{
		var company = new CompanyArray();

		$assert.isTrue( isInstanceOf( company, "com.database.Norm" ) );
		$assert.isTrue( company.isNew() );

		company.load(5);

		$assert.isTrue( company.getName() == 'MR R SHANKS' );

		// Now see if the child entities were loaded (dynamically by <table>_ID pattern)
		$assert.isTrue( company.hasCallNotes() );
		// writeDump( company.getCallNotes().toStruct() );
		$assert.isTrue( company.getCallNotes().len() == 7 );
		$assert.isTrue( company.getCallNotes()[5].Id == 5 );

	}

    function loadEntityAndDynamicManyToOneChildEntityByConvention() test{
		var company = new com.database.Norm( table = "companies", dao = request.dao );

		$assert.isTrue( isInstanceOf( company, "com.database.Norm" ) );
		$assert.isTrue( company.isNew() );

		company.load(5);

		$assert.isTrue( company.getName() == 'MR R SHANKS' );
		// Now see if the child entities were loaded (dynamically by <table>_ID pattern)
		company.hasManyCall_Notes();
		// writeDump(company.toStruct());abort;
		$assert.isTrue( company.hasCall_Notes() );
		// writeDump(company.getCall_Notes());

	}

	function lazyLoadChildren() test{

	}

	// executes after all tests
	function afterTests(){

		//structClear( application );

	}

}
