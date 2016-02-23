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

          product.load(2381);

          $assert.isTrue( product.getName() == 'ABRAM' );
          // Now see if the child entities were loaded (dynamically by <table>_ID pattern)

          $assert.isTrue( product.getProduct_Classes().getID() == 1 );


     }

     function loadEntityAndDynamicOneToManyChildEntityUsingFKNamingConventionAndSaveChildRecord() test{
          var product = new com.database.Norm( table = "products", dao = request.dao, autoWire = true, debugMode = false );

          request.dao.execute("update product_classes set name = 'Holstein' where ID = 1");
          $assert.isTrue( isInstanceOf( product, "com.database.Norm" ) );
          $assert.isTrue( product.isNew() );

          product.load(2381);

          $assert.isTrue( product.getName() == 'ABRAM' );
          $assert.isTrue( product.getProduct_Classes().getName() == 'Holstein' );

          product.getProduct_Classes().setName( 'TEMP-TEST' );
          $assert.isTrue( product.getProduct_Classes().getName() == 'TEMP-TEST' );
          product.save();

          var prodClassNameTest = request.dao.read("select name from product_classes where ID = 1");
          $assert.isTrue( prodClassNameTest.name == 'TEMP-TEST' );

          product.getProduct_Classes().setName( 'Holstein' );

          product.save();
          prodClassNameTest = request.dao.read("select name from product_classes where ID = 1 ");
          $assert.isTrue( prodClassNameTest.name == 'Holstein' );


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

          product.load(2381);

          $assert.isTrue( product.getName() == 'ABRAM' );
          // Now see if the child entities were loaded (dynamically by <table>_ID pattern)
          // writeDump(product.getProductClass().getID());abort;
          $assert.isTrue( product.getProductClass().getID() == 1 );

     }

    function loadEntityAndDynamicManyToOneChildEntity() test{
          var company = new com.database.Norm( table = "companies", dao = request.dao );

          $assert.isTrue( isInstanceOf( company, "com.database.Norm" ) );
          $assert.isTrue( company.isNew() );

          company.load(23622);

          $assert.isTrue( company.getName() == 'K & M ATKINS' );
          // Now see if the child entities were loaded (dynamically by <table>_ID pattern)
          company.hasMany( table = "call_notes", fkColumn = "companies_ID", property = "CallNotes" );
          $assert.isTrue( company.hasCallNotes() );
          // writeDump(company.getCallNotes());

     }

    function loadEntityAndDynamicManyToOneChildEntityByConvention() test{
          var company = new com.database.Norm( table = "companies", dao = request.dao );

          $assert.isTrue( isInstanceOf( company, "com.database.Norm" ) );
          $assert.isTrue( company.isNew() );

          company.load(23622);

          $assert.isTrue( company.getName() == 'K & M ATKINS' );
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
