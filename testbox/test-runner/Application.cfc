/**
* Copyright Since 2005 Ortus Solutions, Corp
* www.coldbox.org | www.luismajano.com | www.ortussolutions.com | www.gocontentbox.org
**************************************************************************************
*/
component{
	this.name = "A TestBox Runner " & hash( getCurrentTemplatePath() );
	// any other application.cfc stuff goes below:
	this.sessionManagement = true;

	// any mappings go here, we create one that points to the root called test.
	this.mappings[ "/test" ] = getDirectoryFromPath( getCurrentTemplatePath() );
	this.mappings[ "/com" ] = expandPath( '/src/com' );
	this.mappings[ "/testbox" ] = expandPath( '/testbox' );

	// any orm definitions go here.

	// request start
	public boolean function onRequestStart( String targetPage ){
		request.dao = new com.database.dao( dsn = "dao" );
		// @TODO: Make database setup for each supported database engine

		// MySQL
		local.start = getTickCount();
 		request.dao.execute("DROP TABLE IF EXISTS `eventLog`");
		request.dao.execute("
		   CREATE TABLE `eventLog` (
		     `ID` int(11) NOT NULL AUTO_INCREMENT,
		     `event` varchar(100) DEFAULT NULL,
		     `description` text,
		     `eventDate` datetime DEFAULT NULL,
		     PRIMARY KEY (`ID`)
		   ) ENGINE=MyISAM AUTO_INCREMENT=0 DEFAULT CHARSET=latin1;
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
		request.dao.execute("DROP TABLE IF EXISTS `pets`");
		request.dao.execute("
		   CREATE TABLE `pets` (
		     `ID` int(11) unsigned NOT NULL AUTO_INCREMENT,
		     `_id` varchar(45) NOT NULL,
		     `userID` varchar(255) DEFAULT NULL,
		     `firstName` varchar(255) DEFAULT NULL,
		     `lastName` varchar(255) DEFAULT NULL,
		     `createdDate` datetime DEFAULT NULL,
		     `modifiedDate` datetime DEFAULT NULL,
		     PRIMARY KEY (`ID`,`_id`)
		   ) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;
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
		                  ('94', 'fbf08c9d-e8de-01f7-7c89d8b41b258aac', '8', 'dog', 'frog', CURRENT_DATE,CURRENT_DATE),
		                  ('95', 'fc059ee0-96ce-a99b-7c0f26be24e3271a', '12', 'dog', 'mog', CURRENT_DATE,CURRENT_DATE),
		                  ('96', 'fc0601c7-9f0b-fae9-0eb0b9ad5ac0ea93', '15', 'corn', 'dag', CURRENT_DATE,CURRENT_DATE),
		                  ('97', 'fc070c5c-9943-6503-a10e73bd72ab1125', '18', 'chicken', 'cat', CURRENT_DATE,CURRENT_DATE),
		                  ('98', 'fc0f2f26-efb3-fd03-1fb7a5e794be17f2', '21', 'beef', 'rat', CURRENT_DATE,CURRENT_DATE),
		                  ('99', 'fc108acf-0c05-7303-62273152f581f444', '24', 'dog', '', CURRENT_DATE,CURRENT_DATE)
		");

		request.dao.execute("DROP TABLE IF EXISTS `users`");
		request.dao.execute("CREATE TABLE `users` (
		     `ID` int(11) unsigned NOT NULL AUTO_INCREMENT,
		     `user_name` varchar(50) CHARACTER SET latin1 DEFAULT NULL,
		     `password` varchar(50) CHARACTER SET latin1 DEFAULT NULL,
		     `first_name` varchar(60) CHARACTER SET latin1 DEFAULT NULL,
		     `last_name` varchar(60) CHARACTER SET latin1 DEFAULT NULL,
		     `status` int(11) unsigned DEFAULT NULL,
		     `created_datetime` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
		     `modified_datetime` datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
		     `_id` varchar(200) DEFAULT NULL,
		     `email` varchar(255) DEFAULT NULL,
		     PRIMARY KEY (`ID`)
		   ) ENGINE=InnoDB AUTO_INCREMENT=0 DEFAULT CHARSET=utf8;
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
		   VALUES ('1', 'jbond', '7d5a2669cf9d8338eeb29f4e67c1b0af', 'james', 'bond', '1', '2008-03-26 10:21:43', '2013-11-22 17:25:05', '170d1f48-b141-80a8-2a9a9e252d69d2cd', 'jbond@spymail.com')"
		);
		local.end = getTickCount();
		writeLog('DB Setup took: ' & (local.end - local.start)/100 & " seconds..." );
		return true;
	}
}