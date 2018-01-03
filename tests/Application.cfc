component{
	this.name = "A TestBox Runner Suite" & hash( getCurrentTemplatePath() );
	// any other application.cfc stuff goes below:
	this.sessionManagement = true;

	// any mappings go here, we create one that points to the root called test.
	this.mappings[ "/test" ] = getDirectoryFromPath( getCurrentTemplatePath() );
	this.mappings[ "/com" ] = expandPath( '/' );
	this.mappings[ "/testbox" ] = expandPath( '/testbox' );
	this.mappings[ "/model" ] = expandPath( '/model' );

	this.datasource = "dao";
	// any orm definitions go here.
	/*this.ormenabled = !!( isDefined( 'server' ) && ( structKeyExists( server, 'railo' ) || structKeyExists( server, 'lucee' ) ) );
	this.ormsettings={datasource="dao"};*/

	public function onApplicatoinStart(){
		setupDatabase();
	}
	// request start
	public function onRequestStart( String targetPage ){
		request.dao = new com.database.dao( dsn = "dao" );
		setupDatabase();
		return true;
	}

	private function setupDatabase(){

		var start = getTickCount();
		if ( request.dao.getDBtype()  == "mssql" ){
			// MSSQL specific
			request.dao.execute( "
				IF NOT EXISTS ( SELECT * FROM sysobjects WHERE name = 'pets' AND xtype = 'U' )
					TRUNCATE TABLE [pets]
				" );
			request.dao.execute( "
				IF NOT EXISTS ( SELECT * FROM sysobjects WHERE name = 'users' AND xtype = 'U' )
					CREATE TABLE users (
						ID int NOT NULL IDENTITY (1, 1),
						_id varchar(45) NOT NULL,
					    user_name varchar(50) DEFAULT NULL,
					    password varchar(50) DEFAULT NULL,
					    first_name varchar(60) DEFAULT NULL,
					    last_name varchar(60) DEFAULT NULL,
					    email varchar(255) DEFAULT NULL,
					    status int(11) DEFAULT NULL,
					    crated_datetime datetime DEFAULT NULL,
					    modified_datetime datetime DEFAULT NULL
					)
				" );
			request.dao.execute("TRUNCATE TABLE [users]");
				var userInsertArray = [
					"('0', 'system', '7d5a2669cf9d8338eeb29f4e67c1b0af', 'system', 'bonduser', '1', '2008-03-26 10:21:43', '2013-11-22 17:25:05', '#createUUID()#', 'sys@spymail.com')",
					"('1', 'jbond', '7d5a2669cf9d8338eeb29f4e67c1b0af', 'james', 'bond', '1', '2008-03-26 10:21:43', '2013-11-22 17:25:05', '#createUUID()#', 'jbond@spymail.com')",
				   	"('2', 'hbond', '7d5a2669cf9d8338eeb29f4e67c1b0af', 'harry', 'bond', '1', '2008-03-26 10:21:43', '2013-11-22 17:25:05', '#createUUID()#', 'hbond@spymail.com')",
			   		"('3', 'ssmith', '7d5a2669cf9d8338eeb29f4e67c1b0af', 'sarah', 'smith', '1', '2008-03-26 10:21:43', '2013-11-22 17:25:05', '#createUUID()#', 'ssmith@spymail.com')"
			   	];
			for( var insert in userInsertArray ){
				request.dao.execute("
					INSERT INTO users(
				       `ID`,
				       `user_name`,
				       `password`,
				       `first_name`,
				       `last_name`,
				       `status`,
				       `created_datetime`,
				       `modified_datetime`,
				       `_id`,
				       `email`)
				   VALUES #insert#
				");
			}

			request.dao.execute( "
				IF NOT EXISTS ( SELECT * FROM sysobjects WHERE name = 'eventLog' AND xtype = 'U' )
					CREATE TABLE eventLog (
						ID int NOT NULL IDENTITY (1, 1),
						userID int NULL,
						event varchar(50) NULL,
						description text NULL,
						eventDate date NULL
					)
				" );
			request.dao.execute("TRUNCATE TABLE [eventLog]");
			var eventLogData = [
							{ID:'208', event: 'delete', description: 'deleted 243', eventDate: '2014-01-29 01:26:51'},
							{ID:'1', event: 'not a test insert', description: '', eventDate: '2014-12-30 08:36:01'},
							{ID:'20', event: 'not a test insert', description: '', eventDate: '2014-12-30 08:38:45'},
							{ID:'215', event: 'test insert', description: '', eventDate: '2014-12-30 08:38:44'},
							{ID:'219', event: 'test named params', description: 'This is a description from a named param', eventDate: '2014-12-30 08:38:46'},
							{ID:'220', event: 'test insert', description: '', eventDate: '2014-12-30 08:38:46'}
						];
			request.dao.insert( "eventLog", eventLogData );

			request.dao.execute( "
				IF NOT EXISTS ( SELECT * FROM sysobjects WHERE name = 'pets' AND xtype = 'U' )
					CREATE TABLE pets (
						ID int NOT NULL IDENTITY (1, 1),
						_id varchar(45) NOT NULL,
					    userID varchar(255) DEFAULT NULL,
					    firstName varchar(255) DEFAULT NULL,
					    lastName varchar(255) DEFAULT NULL,
					    createdDate datetime DEFAULT NULL,
					    modifiedDate datetime DEFAULT NULL
					)
				" );
			request.dao.execute("TRUNCATE TABLE [pets]");

			var petsData = [
							  {ID:'93',_id: '7d5a4d53-0a80-6eaf-db2acdaf5ed86568', userId:'1',  firstName:'dog', lastName: '', createdDate: now(),now()},
			                  {ID:'94',_id: 'fbf08c9d-e8de-01f7-7c89d8b41b258aac', userId:'8',  firstName:'dog', lastName: 'frog', createdDate:now(),now()},
			                  {ID:'95',_id: 'fc059ee0-96ce-a99b-7c0f26be24e3271a', userId:'12', firstName: 'dog', lastName: 'mog', createdDate:now(),now()},
			                  {ID:'96',_id: 'fc0601c7-9f0b-fae9-0eb0b9ad5ac0ea93', userId:'15', firstName: 'corn', lastName: 'dag', createdDate:now(),now()},
			                  {ID:'97',_id: 'fc070c5c-9943-6503-a10e73bd72ab1125', userId:'18', firstName: 'chicken', lastName: 'cat', createdDate:now(),now()},
			                  {ID:'98',_id: 'fc0f2f26-efb3-fd03-1fb7a5e794be17f2', userId:'21', firstName: 'beef', lastName: 'rat', createdDate:now(),now()},
			                  {ID:'99',_id: 'fc108acf-0c05-7303-62273152f581f444', userId:'24', firstName: 'dog', lastName: '', createdDate: now(),now()}
			                ];
			request.dao.insert( "pets", petsData );

			request.dao.execute( "
				IF NOT EXISTS ( SELECT * FROM sysobjects WHERE name = 'test' AND xtype = 'U' )
					CREATE TABLE test (
						ID int NOT NULL IDENTITY (1, 1),
						test varchar(50) NULL,
						testDate date NULL
					)
				" );
			request.dao.execute("TRUNCATE TABLE [test]");

			// TODO: Add MSSQL specific create tables for orders, order_items, companies, call_notes, products and product_clasess (See mysql create statements for definitions/data)

		} else if ( request.dao.getDBtype() == "mysql" ){

			// MySQL specific

			request.dao.execute("DROP TABLE IF EXISTS `pets`");

			request.dao.execute("DROP TABLE IF EXISTS `users`");
			request.dao.execute("
				 CREATE TABLE `users` (
				   `ID` int(11) NOT NULL AUTO_INCREMENT,
				   `user_name` varchar(50) DEFAULT NULL,
				   `password` varchar(50) DEFAULT NULL,
				   `first_name` varchar(60) DEFAULT NULL,
				   `last_name` varchar(60) DEFAULT NULL,
				   `status` int(11) unsigned DEFAULT NULL,
				   `created_datetime` datetime NOT NULL DEFAULT current_timestamp,
				   `modified_datetime` datetime NULL,
				   `_id` varchar(200) DEFAULT NULL,
				   `email` varchar(255) DEFAULT NULL,
				   PRIMARY KEY (`ID`)
				 ) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8;

			");
			request.dao.execute("REPLACE INTO users(
			       `ID`,
			       `user_name`,
			       `password`,
			       `first_name`,
			       `last_name`,
			       `status`,
			       `created_datetime`,
			       `modified_datetime`,
			       `_id`,
			       `email`)
			   VALUES
			   	('-1', 'system', '7d5a2669cf9d8338eeb29f4e67c1b0af', 'system', 'user', '1', '2008-03-26 10:21:43', '2013-11-22 17:25:05', '#createUUID()#', 'sys@spymail.com'),
			   	('1', 'jbond', '7d5a2669cf9d8338eeb29f4e67c1b0af', 'james', 'bond', '1', '2008-03-26 10:21:43', '2013-11-22 17:25:05', '#createUUID()#', 'jbond@spymail.com'),
			   	('2', 'hbond', '7d5a2669cf9d8338eeb29f4e67c1b0af', 'harry', 'bond', '1', '2008-03-26 10:21:43', '2013-11-22 17:25:05', '#createUUID()#', 'hbond@spymail.com'),
			   	('3', 'ssmith', '7d5a2669cf9d8338eeb29f4e67c1b0af', 'sarah', 'smith', '1', '2008-03-26 10:21:43', '2013-11-22 17:25:05', '#createUUID()#', 'ssmith@spymail.com')
			   "
			);
			request.dao.execute("update users set ID = 0 where id = -1");
			request.dao.execute("DROP TABLE IF EXISTS `eventLog`");
			request.dao.execute("
			   CREATE TABLE `eventLog` (
			     `ID` int(11) NOT NULL AUTO_INCREMENT,
			     `event` varchar(100) DEFAULT NULL,
			     `description` text,
			     `eventDate` datetime DEFAULT NULL,
			     PRIMARY KEY (`ID`)
			   ) ENGINE=MyISAM AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;
			");
			request.dao.execute("REPLACE INTO eventLog(
			                            `ID`,
			                            `event`,
			                            `description`,
			                            `eventDate`)
			                  VALUES ('208', 'delete', 'deleted 243', '2014-01-29 01:26:51'),
							('1', 'not a test insert', '', '2014-12-30 08:36:01'),
							('20', 'not a test insert', '', '2014-12-30 08:38:45'),
							('215', 'test insert', '', '2014-12-30 08:38:44'),
							('219', 'test named params', 'This is a description from a named param', '2014-12-30 08:38:46'),
							('220', 'test insert', '', '2014-12-30 08:38:46')
			");
			request.dao.execute("
			   CREATE TABLE `pets` (
				   `ID` int(11) unsigned NOT NULL AUTO_INCREMENT,
				   `_id` varchar(45) NOT NULL,
				   `userID` int(11) NOT NULL,
				   `firstName` varchar(255) DEFAULT NULL,
				   `lastName` varchar(255) DEFAULT NULL,
				   `createdDate` datetime DEFAULT NULL,
				   `modifiedDate` datetime DEFAULT NULL,
				   PRIMARY KEY (`ID`,`_id`),
				   KEY `userID` (`userID`),
				  FOREIGN KEY (`userID`) REFERENCES `users`(`ID`)
				 ) ENGINE=InnoDB AUTO_INCREMENT=501 DEFAULT CHARSET=utf8;
			");
			request.dao.execute("REPLACE INTO pets(
			                            `ID`,
			                            `_id`,
			                            `userID`,
			                            `firstName`,
			                            `lastName`,
			                            `createdDate`,
			                            `modifiedDate`)
			                  VALUES
			                  ('93', '7d5a4d53-0a80-6eaf-db2acdaf5ed86568', '1', 'dog', '', CURRENT_DATE,CURRENT_DATE),
			                  ('94', 'fbf08c9d-e8de-01f7-7c89d8b41b258aac', '1', 'dog', 'frog', CURRENT_DATE,CURRENT_DATE),
			                  ('95', 'fc059ee0-96ce-a99b-7c0f26be24e3271a', '1', 'dog', 'mog', CURRENT_DATE,CURRENT_DATE),
			                  ('96', 'fc0601c7-9f0b-fae9-0eb0b9ad5ac0ea93', '1', 'corn', 'dag', CURRENT_DATE,CURRENT_DATE),
			                  ('97', 'fc070c5c-9943-6503-a10e73bd72ab1125', '1', 'chicken', 'cat', CURRENT_DATE,CURRENT_DATE),
			                  ('98', 'fc0f2f26-efb3-fd03-1fb7a5e794be17f2', '1', 'beef', 'rat', CURRENT_DATE,CURRENT_DATE),
			                  ('99', 'fc108acf-0c05-7303-62273152f581f444', '1', 'dog', '', CURRENT_DATE,CURRENT_DATE)
			");


			request.dao.execute("DROP TABLE IF EXISTS `test`");
			request.dao.execute("CREATE TABLE `test` (
			     `ID` int(11) unsigned NOT NULL AUTO_INCREMENT,
			     `test` varchar(50) CHARACTER SET utf8 DEFAULT NULL,
			     `testDate` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
			     PRIMARY KEY (`ID`)
			   ) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;
			");


			request.dao.execute("DROP TABLE IF EXISTS `products`");
			request.dao.execute(
				sql = "CREATE TABLE `products` (
						`ID` int(11) unsigned NOT NULL AUTO_INCREMENT,
						`product_classes_ID` int(11) unsigned NOT NULL DEFAULT '0',
						`name` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
						`description` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
						`price` double DEFAULT NULL,
						`cost` double DEFAULT NULL,
						PRIMARY KEY (`ID`) USING BTREE
						) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;"
			);
			request.dao.execute(
				sql = "
					INSERT INTO products( ID, product_classes_ID, name, description, price, cost )
					VALUES
						( 1, 1, 'Gloves', 'Leather work gloves', 15.00, 3.50 ),
						( 2, 1, 'Pants', 'Heavy work pants', 45.00, 13.40 ),
						( 3, 2, 'Jackhammer', 'Jackhammer', 345.00, 116.00 ),
						( 4, 2, 'Drill', 'Drill', 150.00, 40.00 ),
						( 5, 3, 'Demolition', 'Demolition', 50.00, 30.00 )
			       "
			);

			request.dao.execute("DROP TABLE IF EXISTS `product_classes`");
			request.dao.execute(
				sql = "CREATE TABLE `product_classes` (
						`ID` int(11) unsigned NOT NULL AUTO_INCREMENT,
						`name` varchar(45) CHARACTER SET utf8 DEFAULT NULL,
						`description` varchar(100) CHARACTER SET utf8 DEFAULT NULL,
						PRIMARY KEY (`ID`)
						) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;"
			);

			request.dao.execute(
				sql = "
					INSERT INTO product_classes( ID, name, description)
					VALUES
						( 1, 'Apparel', 'Clothing' ),
						( 2, 'Equipment', 'Equipment' ),
						( 3, 'Services', 'Non-taxable services' );
			       "
			);


			request.dao.execute("DROP TABLE IF EXISTS `companies`");
			request.dao.execute(
				sql = "CREATE TABLE `companies` (
						`ID` int(11) unsigned NOT NULL AUTO_INCREMENT,
						`name` varchar(255) CHARACTER SET utf8 DEFAULT NULL,
						`account_reference` varchar(100) CHARACTER SET utf8 DEFAULT NULL,
						`email_address` varchar(100) CHARACTER SET utf8 DEFAULT NULL,
						PRIMARY KEY (`ID`)
						) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;"
			);
			request.dao.execute(
				sql = "
				INSERT INTO companies ( name, account_reference )
				VALUES
					('M and D Coars and Co', 'C01099'),
					('ALASTAIR FERGUSON', 'C01100'),
					('E T Tomlinson & Son', 'C01101'),
					('A N Other', 'C01102'),
					('MR R SHANKS', 'C01103'),
					('R MCCRACKEN', 'C01104'),
					('R J V Kelso & Son', 'C01105'),
					('OWEN MARTIN', 'C01106'),
					('Ballyedmond Castle Farms Ltd', 'C01107'),
					('W G Johnston', 'C01108'),
					('G & S E McNiece', 'C01109'),
					('James McAuley', 'C01110'),
					('R.M. & R.A. Shepherd', 'C01111'),
					('D & J Armstrong', 'C01113'),
					('W Walker & Sons', 'C01115'),
					('F G Jones & Son', 'C01119'),
					('RICHARD CHARLES', 'C01120'),
					('T N Beeston & Son', 'C01122'),
					('Webber Dairying', 'C01124'),
					('ST & EE Nickles', 'C01125'),
					('M L Farming', 'C01127'),
					('Fluscopike Farms', 'C01129'),
					('Earl of Plymouth Estates Ltd', 'C01130'),
					('D L & H & I R Davies', 'C01131'),
					('Meinbank Farm', 'C01132'),
					('H & E W Harrison', 'C01133')

			       "
			);

			request.dao.execute("DROP TABLE IF EXISTS `orders`");
			request.dao.execute(
				sql = "
					CREATE TABLE `orders` (
						`ID` int(11) unsigned NOT NULL AUTO_INCREMENT,
						`companies_ID` int(11) unsigned DEFAULT NULL,
						`order_datetime` datetime DEFAULT NULL,
						`total` double NOT NULL DEFAULT '0',
						`users_ID` int(11) DEFAULT NULL,
						PRIMARY KEY (`ID`)
						) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;
					"
			);
			request.dao.execute(
				sql = "
					INSERT INTO orders ( companies_ID, order_datetime,  users_ID )
					VALUES
						(1, '2017-01-12', 1 ),
						(3, '2017-01-22', 1 ),
						(5, '2017-05-12', 1 ),
						(7, '2017-08-01', 1 ),
						(5, '2017-08-05', 1 ),
						(2, '2016-11-12', 1 ),
						(6, '2016-12-12', 1 ),
						(7, '2017-01-12', 1 ),
						(8, '2017-01-12', 1 ),
						(10, '2017-01-12', 1 ),
						(15, '2017-01-12', 1 ),
						(9, '2017-01-12', 1 ),
						(12, '2017-01-12', 1 ),
						(3, '2017-01-12', 1 ),
						(2, '2017-01-12', 1 ),
						(6, '2017-01-12', 1 )
				"
			);

			request.dao.execute("DROP TABLE IF EXISTS `order_items`");
			request.dao.execute(
				sql = "CREATE TABLE `order_items` (
						`ID` int(11) NOT NULL AUTO_INCREMENT,
						`orders_ID` int(11) unsigned DEFAULT NULL,
						`companies_ID` int(10) unsigned DEFAULT NULL,
						`products_ID` int(11) unsigned DEFAULT NULL,
						`item_price` double NOT NULL DEFAULT '0',
						PRIMARY KEY (`ID`)
						) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;"
			);
			var orders = request.dao.read("orders");
			var companies = request.dao.read("companies");
			var products = request.dao.read("products");
			for( var order in orders ){
				var productId = randRange(1, products.recordCount );
				request.dao.insert( "order_items", {orders_ID: order.id, companies_ID: randRange(1,companies.recordCount ), products_ID:productId, price:products.price[ productId ] } )
			}

			request.dao.execute("DROP TABLE IF EXISTS `call_notes`");
			request.dao.execute(
				sql = "
					CREATE TABLE `call_notes` (
					`ID` int(10) unsigned NOT NULL AUTO_INCREMENT,
					`companies_ID` int(10) unsigned DEFAULT NULL,
					`note` text,
					`created_datetime` datetime DEFAULT NULL,
					PRIMARY KEY (`ID`)
					) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;
				"
			);
			var callNotes = [
				{companies_ID:5,note: 'abc', created_datetime:now() },
				{companies_ID:5,note: createUUID(), created_datetime:now() },
				{companies_ID:5,note: createUUID(), created_datetime:now() },
				{companies_ID:5,note: createUUID(), created_datetime:now() },
				{companies_ID:5,note: createUUID(), created_datetime:now() },
				{companies_ID:5,note: createUUID(), created_datetime:now() },
				{companies_ID:5,note: createUUID(), created_datetime:now() }
			];
			request.dao.insert( "call_notes", callNotes );


		}

		// Model tables
		var todoItem = new model.TodoItem( dao = request.dao, dropcreate = true, createTableIfNotExist = true );



		var end = getTickCount();
		writeLog('DB Setup took: ' & (end - start)/1000 & " seconds..." );
	}
}
