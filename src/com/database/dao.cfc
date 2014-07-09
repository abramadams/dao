<!--- **********************************************************
		Component	: dao.cfc
		Author		: Abram Adams
		Date		: 1/2/2007
		@version 0.0.57
		@updated 05/29/2014

		Description	: Generic database access object that will
		control all database interaction.  This component will
		invoke database specific functions when needed to perform
		platform specific calls.

		For instance mysql.cfc has MySQL specific syntax
		and routines to perform generic functions like obtaining
		the definition of a table, the interface here is
		define(tablename) and the MySQL function is DESCRIBE tablename.
		To implement for MS SQL you would need to create a
		mssql.cfc and have MS SQL specific syntax for the
		define(tablename) function that returns a query object.

		EXAMPLES:
			// Create global database connection
			dao = new dao(
						   dsn		= "mydsn",
						   user		= "dbuser",
						   password = "dbpass",
						   dbtype	= "mysql"
						  );

			Function read:
			query = dao.read("users");
			or:
			query = dao.read("
				select name, email
				from users
				where id = #dao.queryParam(1)#
			");

			Function write:
			NewKey = application.dao.write('insert into users (id) values(1)');

			Function update:
			dao.update("
				update users
				set name = #dao.queryParam('test','varchar')#
				where id = #dao.queryParam(12,'int')#
			");

			Function execute:
			results = dao.execute("show databases");

			Function delete:
			dao.delete("users","*");

	  ********************************************************** --->

<cfcomponent displayname="DAO" hint="This component is basically a DAO Factory that will construct the appropriate invokation for the given database type." output="true" accessors="true">

	<cfproperty name="dsn" type="string">
	<cfproperty name="dbtype" type="string">
	<cfproperty name="dbversion" type="string">
	<cfproperty name="writeTransactionLog" type="boolean">

	<cfset _resetCriteria() />
	<cfscript>

		/**
		* I initialize DAO
		* @dsn Data Source Name
		* @dbtype Database Type
		* @user Data Source User Name
		* @password Data Source Password
		* @writeTransactionLog Write transactions to log (for replication)
		* @transactionLogFile Location to write the transaction log
		* @useCFQueryParams Determines if execute queries will use cfqueryparam
		**/
		public DAO function init( required string dsn, string dbtype = "", string user = "", string password ="", boolean writeTransactionLog = false, string transactionLogFile = "#expandPath('/')#sql_transaction_log.sql", boolean useCFQueryParams = true ){

			//This is the datasource name for the system
			variables.dsn = arguments.dsn;
			variables.writeTransactionLog = arguments.writeTransactionLog;

			// auto-detect the database type.
			var d = new dbinfo( datasource = arguments.dsn );
			variables.dbversion = d.version();

			if ( !len( trim( arguments.dbtype ) ) ){
				arguments.dbtype = getConnecterType();
			}
			// This will define the type of database you are using (i.e. MySQL, MSSQL, etc)
			variables.dbType = Arguments.dbType;
			this.user=arguments.user;
			this.password=arguments.password;

			//This is the actual db specific connection.
			this.conn = createObject("component", variables.dbType);
			this.conn.init(
					dao = this,
					dsn = variables.dsn,
					user = arguments.user,
					password = arguments.password,
					dbtype = arguments.dbtype,
					transactionLogFile = arguments.transactionLogFile,
					useCFQueryParams = arguments.useCFQueryParams
					);

			variables.transactionLogFile = arguments.transactionLogFile;
			variables.useCFQueryParams = arguments.useCFQueryParams;

			variables.tabledefs = {};


			return this;
		}
		public function getConnecterType(){

			switch( variables.dbVersion.database_productname ){
				case "Microsoft SQL Server" : return "mssql";
				case "MySQL" : return "mysql";
			}
		}



		/**
		* I return the ID of the last inserted record.
		**/
		public function getLastID(){
			return this.conn.getLastID();
		}

		/**
		* I insert data into the database.  I take a tabledef object containing the tablename and column values. I return the new record's Primary Key value.
		**/
		public function write( required tabledef tabledef){
			return this.conn.write( arguments.tabledef );
		}


		/**
		* I insert data into a table in the database.
		* @table Name of table to insert data into.
		* @data Struct of name value pairs containing data.  Name must match column name.  This could be a form scope
		* @dryRun For debugging, will dump the data used to insert instead of actually inserting.
		* @onFinish Will execute when finished inserting.  Can be used for audit logging, notifications, post update processing, etc...
		**/
		public function insert( required string table, required struct data, boolean dryRun = false, any onFinish = "", any callbackArgs = {} ){
			var LOCAL = {};
			if( !structKeyExists( variables.tabledefs, arguments.table ) ){
				variables.tabledefs[ arguments.table ] = new tabledef( tablename = arguments.table, dsn = getDSN() );
			}
			var LOCAL.table = duplicate( variables.tabledefs[ arguments.table ] );
			var columns = LOCAL.table.getColumns();
			var row = LOCAL.table.addRow();

			// Iterate through each column in the table and either set the value with what's in the arguments.data struct
			// or set it to the default value defined by the table itself.
			for( var column in listToArray( columns ) ){
				param name="arguments.data.#column#" default="#LOCAL.table.getColumnDefaultValue( column )#";
				if ( structKeyExists( arguments.data, column ) ){
					if( column == LOCAL.table.getPrimaryKeyColumn()
						&&  LOCAL.table.getTableMeta().columns[ column ].type != 4
						&& !len( trim( arguments.data[ column ] ) ) ){
						LOCAL.table.setColumn( column = column, value = createUUID(), row = row );
					}else{
						 LOCAL.table.setColumn( column = column, value = arguments.data[ column ], row = row);
					}
				}
			}
			/// insert it
			if (!arguments.dryrun){
				var newRecord = this.conn.write( LOCAL.table );
			}else{
				return {
						"Data" = arguments.data,
						"Table Instance" = LOCAL.table,
						"Table Definition" = LOCAL.table.getTableMeta(),
						"Records to be Inserted" = LOCAL.table.getRows()
					};
			}
			// Insert has been performed.  If a callback was provided, fire it off.
			if( isCustomFunction( onFinish ) ){
				structAppend( arguments.callbackArgs, { "table" = arguments.table, "data" = LOCAL.table.getRows(), "id" = newRecord } );
				onFinish( argumentCollection = callbackArgs );
			}

			return newRecord;
		}

		/**
		* I update data in a table in the database.
		* @table Name of table to update data from.
		* @data Struct of name value pairs containing data.  Name must match column name.  This could be a form scope
		* @IDField The name of the Primary Key column in the table.
		* @ID The value of the Primary Key column in the table.
		* @dryRun For debugging, will dump the data used to insert instead of actually inserting.
		* @onFinish Will execute when finished updating.  Can be used for audit logging, notifications, post update processing, etc...
		**/
		public function update( required string table, required struct data, string IDField = "ID", string ID = "", boolean dryRun = false, any onFinish = "", any callbackArgs = {}  ){
			var LOCAL = {};

			LOCAL.isDirty = false;

			// Check for the tabledef object for this table, if it doesn't already exist, create it
			if( !structKeyExists( variables.tabledefs, arguments.table) ){
				variables.tabledefs[ arguments.table ] = new tabledef( tablename = arguments.table, dsn = getDSN() );
			}
			LOCAL.table = duplicate( variables.tabledefs[ arguments.table ] );

			var columns = LOCAL.table.getColumns();
			// @todo deligate read specifics to connector
			var currentData = this.read("
				SELECT #this.getSafeColumnNames( columns )#
				FROM #arguments.table#
				WHERE #LOCAL.table.getPrimaryKeyColumn()# = #this.queryParam(value=arguments.data[LOCAL.table.getPrimaryKeyColumn()],cfsqltype=local.table.instance.tablemeta.columns[LOCAL.table.getPrimaryKeyColumn()].type eq 4 ? 'int' : 'varchar')#
			");
			var row = LOCAL.table.addRow();
			var pk = LOCAL.table.getPrimaryKeyColumn();

			for( var column in listToArray( columns ) ){

				if( len( trim( currentData[ column ][ 1 ] ) ) ){

					// If the form field for this column was not passed in,
					// but the column has a value in the DB, let's use that
					param name="arguments.data.#column#" default="#currentData[ column ][ 1 ]#";
				}else if( len( trim( LOCAL.table.getColumnDefaultValue( column ) ) )
						&& LOCAL.table.getColumnDefaultValue( column ) != '0000-00-00 00:00:00'
						&& LOCAL.table.getColumnDefaultValue( column ) != 'NULL' ){

					// 	If the form field for this column was not passed in
					// 	and the column doesn't have a value, pass the default value
					param name="arguments.data.#column#" default="#LOCAL.table.getColumnDefaultValue( column )#";
				}

				if( structKeyExists( arguments.data, column )
					&& compare( currentData[ column ][ 1 ].toString(), arguments.data[ column ].toString() ) ){

					// This will cause dao.update to only update the columns that have changed.
					// This will not only make the update slightly faster, but it will cut down
					// the transaction log size for offline replication.

					LOCAL.table.setColumnIsDirty( column = column, isDirty = true );
					LOCAL.isDirty = true;
				}
			}


			// This will loop through each column and create a table object (see tabledef.cfc)
			// with the form values.
			// NOTE: The Primary Key field will be updated.  The data.ID variable will be used for
			// this value so either make sure it is the ID for the table, or pass the attribute "ID"
			// with the ID value to be used.
			for( var column in listToArray( columns ) ){

				if ( len( trim( arguments.ID ) ) && column == pk ){
					LOCAL.table.setColumn( column = column, value = arguments.id, row = row );
				}else if ( structKeyExists( arguments.data, column ) ){
					LOCAL.table.setColumn( column = column, value = arguments.data[ column ], row = row );
				}

			}
			//update it
			if (!arguments.dryrun){
				this.updateTable( LOCAL.table );
			}else{
				return {
					"Data" = arguments.data,
					"Table Definition" = LOCAL.table.getTableMeta(),
					"Records to Update" = LOCAL.table.getRows()
				};
			}

			if( isCustomFunction( onFinish ) ){
				structAppend( arguments.callbackArgs, { "table" = arguments.table, "data" = LOCAL.table.getRows(), "id" = LOCAL.table.getRows()[ IDField ] } );
				try{
					onFinish( argumentCollection = callbackArgs );
				}catch(any e){
					writeDump([callbackArgs,e]);abort;
				}
			}

			return val( arguments.ID );
		}

		/**
		* I update data in the database.  I take a tabledef object containing the tablename and column values. I return the record's Primary Key value.
		* @tabledef TableDef object containing data
		* @columns Optional list columns to be updated.
		* @IDField Optional ID field.
		**/
		public numeric function updateTable( required tabledef tabledef, string columns = "", string IDField = ""){
			var ret = "";

			if( !len( trim( arguments.IDField ) ) ){
				arguments.IDField = arguments.tabledef.getPrimaryKeyColumn();
			}
			return this.conn.update( tabledef = arguments.tabledef, columns = arguments.columns, IDField = arguments.IDField );

		}

		/**
		* I delete data in the database.  I take the table name and either the ID of the record to be deleted or a * to indicate delete all.
		* @table Table to delete from.
		* @recordID Record ID of record to be deleted. Use * to delete all.
		* @IDField ID Field of record to be deleted. Default value = table's Primary Key.
		* @onFinish Will execute when finished deleting.  Can be used for audit logging, notifications, post update processing, etc...
		**/
		public boolean function delete( required string table, required string recordID, string IDField = "", any onFinish = "", any callbackArgs = {}  ){
			var ret = true;
	 		try{
				transaction{

					if( arguments.RecordID is "*" ){
						ret = this.conn.deleteAll( tablename = arguments.table );
					}else{
						ret = this.conn.delete( tablename = arguments.table, recordid = arguments.recordid, idField = arguments.idfield );
					}
				}
			} catch( any e ){
				ret = false;
			}


			if( isCustomFunction( onFinish ) ){
				structAppend( arguments.callbackArgs, { "table" = arguments.table, "id" = arguments.recordID } );
				onFinish( argumentCollection = callbackArgs );
			}

			return ret;

		}

		public function logTransaction( required string sql, string lastID = "" ){

			//Duck out if we were told not to write the transaction log
			if( !getWriteTransactionLog() ){
				return;
			}

			var LOCAL = {};

			// Transaction logging:

			// For push style replication we need to capture each data
			// altering statement.  In the case of inserts, we need
			// to also include the ID that was created when we
			// locally inserted the record.  This will be inserted
			// on the server, and when the server replicates the data
			// back to the client, they will be skipped because they
			// already exist (per my.ini config setting:
			// "slave-skip-errors = 1062" which skips duplicate
			// record errors when replicating.)

			if( reFindNoCase( 'INSERT(.*?)INTO', arguments.sql) ){
				// Now let's inspect the sql to determine the table name
				LOCAL.tableName = reReplaceNoCase( arguments.sql, '(.*?)INSERT(.*?)INTO (.*?)\((.*)','\3', 'one' );

				// With the table name we can now find out what field is the primary key
				// field.  This is sort of a limitation of this routine, as it only supports
				// one primary key insertion.  This should be fine though as MySQL only allows
				// one auto incrementing field, which means that if we had more than one
				// primary key we would be creating it on the client side anyway and we'd
				// already know it and it would already be in the sql statement, thus no
				// need to do anything with it.

				LOCAL.PKInfo = getPrimaryKey( LOCAL.tableName );
				LOCAL.primaryKey = LOCAL.PKInfo.field;
				LOCAL.primaryKeyType = LOCAL.PKInfo.type;

				if( len( trim( LOCAL.primaryKey ) ) && !reFindNoCase( '\b#LOCAL.primaryKey#\b', arguments.sql ) ){
					LOCAL.tmpSQL = reReplaceNoCase( arguments.sql, 'INSERT(.*?)INTO (.*?)\(','REPLACE INTO \2(`' & LOCAL.primaryKey & '`, ','one' );
					LOCAL.tmpSQL = reReplaceNoCase( LOCAL.tmpSQL, 'VALUES(.*?)\(',"VALUES (" & queryParam( value = arguments.lastID, cfsqltype = 'int', list = 'false',null = 'false' ) & ", ", 'one' );
					arguments.sql = LOCAL.tmpSQL ;
				}
			}

			if( !directoryExists( getDirectoryFromPath( expandPath( transactionLogFile ) ) ) ){
				directoryCreate( getDirectoryFromPath( expandPath( transactionLogFile ) ) );
			}
			if( !fileExists( transactionLogFile ) ){
				var newFile = fileOpen( transactionLogFile, "read", "utf-8" );
				fileWriteLine( newFile, "" );

			}

			// Count lines in file to get a sequence number
		    LOCAL.file = createObject("java","java.io.File").init(javacast("string",transactionLogFile));
		    LOCAL.fileReader = createObject("java","java.io.FileReader").init(LOCAL.file);
			LOCAL.reader = createObject("java","java.io.LineNumberReader").init(LOCAL.fileReader);
			LOCAL.reader.skip(LOCAL.file.length());
			LOCAL.lines = LOCAL.reader.getLineNumber();
			LOCAL.fileReader.close();
			LOCAL.reader.close();

			// Strip out line feeds, tabs and multiple spaces
			LOCAL.content = "#trim(reReplaceNoCase(arguments.sql,chr(9),' ','all'))#";
			LOCAL.content = reReplaceNoCase(LOCAL.content,chr(10),' ','all');
			LOCAL.content = reReplaceNoCase(LOCAL.content,'[[:space:]]{2,2}',' ','all');
			LOCAL.content = "#lines+1##chr(444)##now()##chr(444)##this.getDSN()##chr(444)##createUUID()##chr(444)##trim(LOCAL.content)##chr(10)#";

			// Append transaction to file.
			fileWriteLine( newFile, '#encrypt(LOCAL.content,'0E69C1BB-BABA-4D48-A7C9D60D020485B0')##chr(555)#' );
			fileClose( newFile );
		}

		// Database Generic Functions

		/**
		* I prepare a parameter value for SQL execution when not using cfqueryparam.  Basically I try to do the same thing as cfqueryparam.
		**/
		public function prepareNonQueryParamValue( required string value, required string cfsqltype, required boolean null ){
			var LOCAL = {};

			if( arguments.cfSQLType is "cf_sql_timestamp" or arguments.cfSQLType is "cf_sql_date" ){
				if( arguments.value is "0000-00-00 00:00" ){
					LOCAL.ret = "'#arguments.value#'";
				}else if( isDate(arguments.value) ){
					LOCAL.ret = createODBCDateTime(arguments.value);
				}else{
					LOCAL.ret = "'0000-00-00 00:00'";
				}
			}else if( arguments.cfSQLType is "cf_sql_integer" ){
				LOCAL.ret = val( arguments.value );
			}else if( arguments.cfSQLType is "cf_sql_boolean" ){
				LOCAL.ret = val( arguments.value );
			}else if( isSimpleValue( arguments.value ) ){
				LOCAL.ret = "'#arguments.value#'";
			}

			return LOCAL.ret;

		}

		/**
		* I prepare a parameter value for SQL execution when not using cfqueryparam.  Basically I try to do the same thing as cfqueryparam.
		**/
		public function getNonQueryParamFormattedValue( required string value, required string cfsqltype, required string list, required boolean null ){
			var ret = "";

			if( arguments.list ){
				for( var idx in listToArray( arguments.value ) ){
					ret = listAppend( ret,
						prepareNonQueryParamValue(
							value = listGetAt( arguments.value, idx ),
							cfsqltype = arguments.cfsqltype,
							null = arguments.null
						) );
				}

			}else{
				ret = prepareNonQueryParamValue(
						value = arguments.value,
						cfsqltype = arguments.cfsqltype,
						null = arguments.null
					);
			}

			return ret;

		}

		/**
		* I determine the CFSQL type for the passd value and return the proper type as a string to be used in cfqueryparam.
		*/
		public function getCFSQLType( required string type ){

			var int_types = "int,integer,numeric,number,cf_sql_integer";
			var string_types = "varchar,char,text,memo,nchar,nvarchar,ntext,cf_sql_varchar";
			var date_types = "datetime,date,cf_sql_date";
			var decimal_types = "decimal,cf_sql_decimal";
			var money_types = "money,cf_sql_money";
			var timestamp_types = "timestamp,cf_sql_timestamp";
			var double_types = "double,cf_sql_double";
			var bit_types = "bit";
			// Default return = varchar
			var ret = "cf_sql_varchar";

			if( listFindNoCase( int_types, arguments.type ) ){
				ret = "cf_sql_integer";
			}else if( listFindNoCase( string_types, arguments.type ) ){
				ret = "cf_sql_varchar";
			}else if( listFindNoCase( date_types, arguments.type ) ){
				ret = "cf_sql_date";
			}else if( listFindNoCase( decimal_types, arguments.type ) ){
				ret = "cf_sql_decimal";
			}else if( listFindNoCase( money_types, arguments.type ) ){
				ret = "cf_sql_money";
			}else if( listFindNoCase( double_types, arguments.type ) ){
				ret = "cf_sql_double";
			}else if( listFindNoCase( timestamp_types, arguments.type ) ){
				ret = "cf_sql_timestamp";
			}else if( listFindNoCase( bit_types, arguments.type ) ){
				ret = "cf_sql_bit";
			}

			return ret;
		}

		/**
		* I return the structure of the passed table.
		**/
		public query function define( required string table ) {
			var def = this.conn.define( arguments.table );

			return def;
		}

		public void function setUseCFQueryParams( required boolean useCFQueryParams ){
			this.useCFQueryParams = arguments.useCFQueryParams;
			this.conn.useCFQueryParams = arguments.useCFQueryParams;
		}

		public boolean function getUseCFQueryParams(){
			return this.conn.getUseCFQueryParams();
		}

		/**
		* I return a list of tables for the current database
		**/
    	public query function getTables(){
			return this.conn.getTables();
		}

		/**
		* I return a list of columns for the passed table
		**/
		public function getColumns( required string table ){
			var def = new tabledef( tablename = arguments.table, dsn = variables.dsn );
			var cols = def.getColumns();

			if( !len( trim( cols ) ) ){
				cols = "*";
			}

			return cols;
		}
	/**
	* I get the primary key for the given table. To do this I envoke the getPrimaryKey from the conneted database type.
	**/
		public function getPrimaryKey( required string table ){
			return this.conn.getPrimaryKey( arguments.table );
		}
		/**
		* I take a list of columns and return it as a safe columns list with each column wrapped within the DB specific escape characters.
		**/
		public function getSafeColumnNames( required string cols ){
			return this.conn.getSafeColumnNames( arguments.cols );;
		}

		/**
		*I take a single column name and return it as a safe columns list with each column wrapped within the DB specific escape characters.
		**/
		public function getSafeColumnName( required string col ){
			return this.conn.getSafeColumnName( arguments.col );
		}

		/**
		* I return the opening escape character for a column name.
		**/
		public function getSafeIdentifierStartChar(){
			return this.conn.getSafeIdentifierStartChar();
		}

		/**
		* I return the closing escape character for a column name.
		**/
		public function getSafeIdentifierEndChar(){
			return this.conn.getSafeIdentifierEndChar();
		}

		public function addTableDef( required tabledef tabledef ){
			variables.tabledefs[ arguments.tabledef.instance.name ] = arguments.tabledef;
		}

		/**
		* I create the values to build the cfqueryparam tag.
		* @value The value to be queryparam'd
		* @cfsqltype This can be a standard RDBS datatype or a cf_sql_type (see getCFSQLType())
		* @list Whether or not to param as a list (i.e. for passing a param'd list to IN() statements )
		* @null Whether the value is null or not
		**/
		public function queryParam( required string value, string cfsqltype = "", boolean list = false, boolean null = false ){

			var returnString = {};
			var returnStruct = {};
			// best guess if
			if( ( reFindNoCase( "{ts.*?}", value ) ) && ( cfsqltype does not contain "date" || cfsqltype does not contain "time" ) ){
				arguments.cfsqltype = "cf_sql_timestamp";
			}else if( !len( trim( cfsqltype ) ) ){
				// default to varchar
				arguments.cfsqltype = "cf_sql_varchar";
			}
			returnStruct = queryParamStruct( value = trim( arguments.value ), cfsqltype = arguments.cfsqltype, list = arguments.list, null = arguments.null );
	 		returnString = '#chr(998)#list=#chr(777)##returnStruct.list##chr(777)# null=#chr(777)##returnStruct.null##chr(777)# cfsqltype=#chr(777)##returnStruct.cfsqltype##chr(777)# value=#chr(777)##returnStruct.value##chr(777)##chr(999)#';
			return returnString;
		}
		/**
		* I create the struct used to build the cfqueryparam tag.
		* @value The value to be queryparam'd
		* @cfsqltype This can be a standard RDBS datatype or a cf_sql_type (see getCFSQLType())
		* @list Whether or not to param as a list (i.e. for passing a param'd list to IN() statements )
		* @null Whether the value is null or not
		**/
		public function queryParamStruct( required string value, string cfsqltype = "", boolean list = false, boolean null = false ){
			var returnStruct = {};
			// best guess if
			if( ( reFindNoCase( "{ts.*?}", value ) ) && ( cfsqltype does not contain "date" || cfsqltype does not contain "time" ) ){
				arguments.cfsqltype = "cf_sql_timestamp";
			}else if( !len( trim( cfsqltype ) ) ){
				// default to varchar
				arguments.cfsqltype = "cf_sql_varchar";
			}
			returnStruct.cfsqltype = reReplaceNoCase( getCFSQLType( arguments.cfsqltype ), '\$queryparam', 'INVALID', 'all' );
			// strip out any queryparam calls in the value, this will prevent the ability to submit malicious code through the SQL string
			returnStruct.value = reReplaceNoCase( arguments.value, '\$queryparam', 'INVALID', 'all');
			returnStruct.list = reReplaceNoCase( arguments.list, '\$queryparam', 'INVALID', 'all');
			returnStruct.null = reReplaceNoCase( arguments.null, '\$queryparam', 'INVALID', 'all');

			return returnStruct;
		}

		/**
		* I build a struct containing all of the where clause of the SQL statement, parameterized when possible.  The returned struct will contain an array of each parameterized clause containing the data necessary to build a <cfqueryparam> tag.
		* @sql SQL statement (or partial SQL statement) which contains tokenized queryParam calls
		**/
		public function parameterizeSQL( required string sql, boolean autoParameterize = true ) output="false" {

			var LOCAL = {};
			var tmp = {};
			var tempValue = "";
			var tempList = "";
			var tempCFSQLType = "";
			var tempParam = "";
			var tmpSQL = parseQueryParams( arguments.sql );

			LOCAL.statements = [];
			if( autoParameterize && ( listLen( tmpSQL, chr( 998 ) ) LT 2 || !len( trim( listGetAt( tmpSQL, 2, chr( 998 ) ) ) ) ) ){

				// So, we didn't have the special characters (998) that indicate the parameters were created
				// using the queryParam() method, however, there may be some where clause type stuff that can
				// be "guessed".  Let's try that, and if we fail we'll just return the original sql statment
				// unharmed.
				if( tmpSQL contains "where "){

					var selectClause = findNoCase( "where ", tmpSQL ) GT 1 ? left( tmpSQL, findNoCase( "where ", tmpSQL )-1 ) : "";
					var whereClause = mid( tmpSQL, findNoCase( "where ", tmpSQL ), len( tmpSQL ) );
					whereClause = reReplaceNoCase( whereClause, "\(\)", chr(654), "all") & ";";
					var newTmpSQL = "";

					// Attempt to pull out any values used in the sql criteria and wrap them
					// in a queryParam() call.
					// @TODO: Fix to support field names ... ie.. where table.field1 = table2.field1
					// newTmpSQL = listAppend( selectClause,
					// 	reReplaceNoCase( whereClause,
					// 			"(\!\=|<>|=|<|>|in(\s*?)\(|like+?)(\s*?)(\S.*?)(\s*?)(\)|\$|group|having|order|and|or|;)",
					// 			"\1 \2 \3 $queryParam(value=""\4"")$ \5 \6 ", "all" ),
					// 			chr( 10 ) );
					newTmpSQL = listAppend( selectClause,
							reReplaceNoCase( whereClause,
								"(\b\!\=\b|\b<>\b|=|<|>|in(\s*?)\(|\blike\b)(\s*)(.*?)(\)|\$|group|having|order|and|or|where|;|\n)",
								"\1 \2 \3 $queryParam(value=""\4"")$ \5 \6 ", "all"
							),
							chr( 10 )
						);

					// Clean up any quoted values
					newTmpSQL = reReplaceNoCase( newTmpSQL, "value=""'(.*?)'(\s*)""", 'value="\1"', "all" );

					// See if we accidentally paramed a nested sql statement, then un-param it
					if( reFindNoCase( "\$queryParam\(value=""select(.*?)""\)\$", newTmpSQL ) ){
						newTmpSQL = reReplaceNoCase( newTmpSQL, "\$queryParam\(value=""(.*?)""\)\$", "\1", "all" );
					}
					// // If "in()" clause found, make sure we param as a list type.
					newTmpSQL = reReplaceNoCase( newTmpSQL, "(in(\s*?)\()(\s*?)(\$queryParam\(+)", '\1\2\3\4 list="true", ', "all" );
					// Now parse the pseudo queryParams() into dao-sql friendly queryparams
					newTmpSQL = parseQueryParams( newTmpSQL );
					// newTmpSQL = reReplaceNoCase( newTmpSQL, "&quot;&quot;", "''", "all");
					newTmpSQL = reReplaceNoCase( newTmpSQL, chr(654), "()", "all");

				}else{
					newTmpSQL = tmpSQL;
				}
				if( listLen( newTmpSQL, chr( 998 ) ) LT 2 || !len( trim( listGetAt( newTmpSQL, 2, chr( 998 ) ) ) ) ){
					// No queryParams to parse, just return the raw SQL
					return {statements = [ {"before" = tmpSQL} ] };
				}
				// If we made it this far, we have parameterized args!! continue on...
				tmpSQL = newTmpSQL;
			}
			tmpSQL = listToArray( tmpSQL, chr( 999 ) );

			for( var sqlFrag in tmpSQL ){

				tmp.before = listFirst( sqlFrag, chr( 998 ) ) ;
				// remove trailing ' from previous clause
				if( left( tmp.before, 1 ) == "'" ){
					tmp.before = mid( tmp.before, 2, len( tmp.before ) );
				}

				tmp.before = preserveSingleQuotes( tmp.before );
				tempParam = listRest( sqlFrag, chr( 998 ) );
				tempParam = preserveSingleQuotes( tempParam );

				// These will return the position and length of the name, cfsqltype and value.
				// We use these to extract the values for the actual cfqueryparam
				tempCFSQLType = reFindNoCase( 'cfsqltype\=#chr(777)#(.*?)#chr(777)#', tempParam, 1, true );

				if( arrayLen( tempCFSQLType.pos ) lte 1 ){
					arrayAppend( LOCAL.statements, tmp );
					continue;
				}

				tmp.cfSQLType = mid( tempParam, tempCFSQLType.pos[2], tempCFSQLType.len[2] );
				// Default the cfsqltype if one wasn't provided
				if( !len( trim( tmp.cfSQLType ) ) ){
					tmp.cfSQLType = "cf_sql_varchar";
				}

				tempValue = reFindNoCase( 'value\=#chr( 777 )#(.*?)#chr( 777 )#', tempParam, 1, true );
				// Strip out any loose hanging special characters used for temporary delimiters (chr(999) and chr(777))
				tmp.value = reReplaceNoCase( mid( PreserveSingleQuotes( tempParam ), tempValue.pos[2], tempValue.len[2] ), chr( 777 ), '', 'all' );
				tmp.value = reReplaceNoCase( preserveSingleQuotes( tmp.value ), chr( 999 ), '', 'all' );

				tempList = reFindNoCase( 'list\=#chr( 777 )#(.*?)#chr( 777 )#', tempParam, 1, true );
				if( !arrayLen( tempList.pos ) gte 2 || !isBoolean( mid( tempParam, tempList.pos[2], tempList.len[2] ) ) ){
					tmp.isList = false;
				}else{
					tmp.isList = mid( tempParam, tempList.pos[2], tempList.len[2] );
				}

				arrayAppend( LOCAL.statements, tmp );
				// Reset tmp struct
				tmp = {};
			}
			return LOCAL;
		}
		/**
		* I parse queryParam calls in the passed SQL string.  See queryParams() for syntax.
		**/
		public function parseQueryParams( required any str ){

			// This function wll parse the passed SQL string to replace $queryParam()$ with the evaluated
			// <cfqueryparam> tag before passing the SQL statement to cfquery (dao.read()).  This function
			// should only be used if the SQL statement is stored in static text (i.e. in a db).  If the
			// SQL is generated in-page, use dao.queryParam() directly to create query parameters.  The reason
			// is that this method is limited and could cause errors if $'s are passed in.

			// First we check to see if the string has anything to parse
			var startPos = findnocase('$queryparam(',arguments.str,1);
			var endPos = "";
			var tmpStartString = "";
			var tmpString = "";
			var tmpEndString = "";
			var evalString = "";
			var returnString = "";

			//Append a space for padding, this helps with the last iteration of recursion
			arguments.str = arguments.str & " ";

			if( startPos ){
				//If so, we'll recursively parse all CF code (code between $'s)
				startPos 	= startPos + 1;
				endPos 	= ( findnocase( ')$', arguments.str, startPos ) - startPos )+1;
				// If no end $ was found, pass back original string.
				if ( !val( endPos ) ){
					return arguments.str;
				}else if( startPos lte 1 ){
					return arguments.str;
				}
				// Now let's grab the piece of string to evaluate
				tmpStartString = mid( arguments.str, 1, startPos - 2 );
				tmpString = mid( arguments.str, startPos, endPos );
				tmpEndString = mid( arguments.str, len( tmpStartString ) + endPos + 3, len( arguments.str ) );
				// A little clean-up
				tmpString = reReplaceNoCase( tmpString, '&quot;', "'", 'all' );
				var originalString = tmpString;
				// If queryParam was passed in the SQL, lets' parse it
				if ( findNoCase( "queryParam", tmpString ) ){
					// We need to normalize the cfml and to be parsed in order to ensure error free processing.  The
					// following will extract the cfsqltype and value from the queryParam() call and reconstruct the
					// queryParam call passing variables instead of literal strings.  This is done to prevent breaking
					// when a non-closed quote or double-quote is passed in the literal string.
					// (i.e. value="this is'nt" my string") would break the code if we didn't do the following

					tmpString = reReplaceNoCase( tmpString, '^queryParam\(', '' );
					tmpString = reReplaceNoCase( tmpString, '\)$', '' );

					// literal strings would have been passed in as quoted values
					// This needs to be removed in order to be converted to JSON -> Struct.
					// The values to be param'd could be in an IN() list, so we need to parse
					// those out differently.
					// First, protect any escaped single quotes:
					tmpString = reReplaceNoCase( tmpString, "\\'","\&quote;", "all" );
					// Now protect date ojbects
					tmpString = reReplaceNoCase( tmpString, "{ts '(.*?)'}","{ts &quote;\1&quote;}", "all" );
					// Now scrube the passed in queryparam args if present (makes later regex easier)
					tmpString = reReplaceNoCase( tmpString, "cfsqltype(\s*?)="," cfsqltype\1=", "all" );
					tmpString = reReplaceNoCase( tmpString, "null(\s*?)="," null\1=", "all" );
					tmpString = reReplaceNoCase( tmpString, "list(\s*?)="," list\1=", "all" );
					// Now clean up any unquoted boolean values
					tmpString = reReplaceNoCase( tmpString, "value(\s*?)=(\s*?)(false|true)+",'value="\3"', "all" );
					tmpString = reReplaceNoCase( tmpString, "value(\s*?)=(\s*?)(\{ts .*?\})+",'value="\3"', "all" );

					tmpArr = listToArray( tmpString, "'" );
					if( !arrayLen( tmpArr ) GT 3 || !arrayLen( tmpArr ) mod 2 ){
						// Only one set of quotes were found.  Now we can simply remove those.
						tmpString = reReplaceNoCase( tmpString, "=(\s*?)""'(.*?)'""", '="\2"', "all" );
					} else{
						// More than one set of quotes found.  That means this was an IN statement and
						// all of the single quotes need to be extracted.
						tmpString = reReplaceNoCase( tmpString, "'", "", "all" );
						tmpString &= ', list="true"';
					}
					// Now restore any escaped single quotes:
					tmpString = reReplaceNoCase( tmpString, "\\&quote;","\'", "all" );
					tmpString = reReplaceNoCase( tmpString, "{ts &quote;(.*?)&quote;}","{ts '\1'}", "all" );
					// Fixes bug in parameterizeSQL() regex.
					tmpString = reReplaceNoCase( tmpString, 'value="=','value="', "all" );

					// Clean up blanks
					tmpString = reReplaceNoCase( tmpString, "''",'""', "all" );

					tmpString = "{" & reReplaceNoCase( tmpString, "\s*?(\S*?)=", """\1"":", "all" ) & "}";
					if( !isJSON( tmpString ) ){
						throw( errorcode="881", message="Invalid QueryParam",
							detail="##The query parameter passed in is not properly escaped.  Make sure to wrap literals in quotes. #originalString# ==> #tmpString#  || #arguments.str#");
					}
					// turn the JSON into a CF struct
					tmpString = deSerializeJSON( tmpString );

					// finally we can evaluate the queryParam struct.  This will scrub the values (i.e. proper cfsql types, prevent sql injection, etc...).
					evalString = queryParamStruct(
													value = structKeyExists( tmpString, 'value' ) ? tmpString.value : '',
													cfsqltype = structKeyExists( tmpString, 'cfsqltype' ) ? tmpString.cfsqltype : '',
													list= structKeyExists( tmpString, 'list' ) ? tmpString.list : false,
													null = structKeyExists( tmpString, 'null' ) ? tmpString.null : false
												);
					// This can be any kind of object, but we are hoping it is a struct (see queryParam())
					if ( isStruct( evalString ) ){
						// Now we'll pass back a pseudo cfqueryparam.  The read() function will
						// break this down and re-create it since the tag call itself has to be static
						returnString = tmpStartString & chr(998) & 'cfsqltype=#chr(777)#'
										& reReplaceNoCase(evalString.cfsqltype,'\$queryparam','INVALID','all')
										& '#chr(777)# value=#chr(777)#' & reReplaceNoCase( evalString.value, '\$queryparam','INVALID','all')
										& '#chr(777)# list=#chr(777)#' &  reReplaceNoCase( evalString.list, '\$queryparam','INVALID','all')
										& '#chr(777)# null=#chr(777)#' &  reReplaceNoCase( evalString.null, '\$queryparam','INVALID','all')
										& '#chr(777)#' & chr(999) &  tmpEndString;
						// Now the recursion.  Pass the string with the value we just parsed back to
						// this function to see if there is anything left to parse.  When there is
						// nothing left to parse it will be returned to the calling function (read())
						return parseQueryParams( returnString );
					}else{
						// The evaluated string was not a simple object and could be malicious so we'll
						// just pass back an error message so the programmer can fix it.
						return "Parsed queryParam is not a struct!";
					}
				}else{
					// There was not an instance of queryParam called, so return the unmodified sql
					return arguments.str;
				}
			}else{
				// Nothing left to parse, let's return the string back to the original calling function
				return arguments.str;
			}
		}

		/**
		* Delegates the creation of a "table" to the underlying persistence storage "connector"
		**/
		public tabledef function makeTable( required tabledef tabledef ){
			return this.conn.makeTable( arguments.tabledef );
		}

		// Entity Query API - Provides LINQ'ish style queries
		public function from( required string from ){
			_resetCriteria();
			_criteria.from = arguments.from;

			return this;
		}

		public function where( required string column, required string operator, required string value ){
			// There can be only one where.
			if ( arrayLen( _criteria.where ) && left( _criteria.where[ 1 ] , 5 ) != "WHERE" ){
				arrayPrepend( _criteria.where, "WHERE #_getSafeColumnName( column )# #operator# #queryParam(value)#" );
			}else{
				_criteria.where[ 1 ] = "WHERE #_getSafeColumnName( column )# #operator# #queryParam(value)#";
			}

			return this;
		}
		public function andWhere( required string column, required string operator, required string value ){
			return _appendToWhere( andOr = "AND", column = column, operator = operator, value = value );
		}

		public function orWhere( required string column, required string operator, required string value ){
			return _appendToWhere( andOr = "OR", column = column, operator = operator, value = value );
		}

		/**
		* Opens a parenthesis claus.  Operator should be AND or OR
		* If "AND" is passed, it will return AND (
		* Must be closed by endGroup()
		**/
		public function beginGroup( string operator = "AND"){

			arrayAppend( _criteria.where, "#operator# ( " );
			return this;
		}
		/**
		* Ends the group.  All this really does is append a closing
		* parenthesis
		**/
		public function endGroup(){

			arrayAppend( _criteria.where, " )" );
			return this;
		}

		public function orderBy( required string orderBy ){

			_criteria.orderBy = orderBy;
			return this;
		}

		public function limit( required any limit ){

			_criteria.limit = arguments.limit;
			return this;
		}

		public function run(){
			return read( table = _criteria.from,
						 where = arrayToList( _criteria.where, ' ' ),
						 limit = _criteria.limit,
						 orderBy = _criteria.orderBy );
		}

		public function getCriteria(){
			return _criteria;
		}

		// EntityQuery "helper" functions
		private function _appendToWhere( required string andOr, required string column, required string operator, required string value ){
			if ( arrayLen( _criteria.where )
				&& ( left( _criteria.where[ arrayLen( _criteria.where ) ] , 5 ) != "AND ("
				&& left( _criteria.where[ arrayLen( _criteria.where ) ] , 4 ) != "OR (" ) ){
				arrayAppend( _criteria.where, "#andOr# #_getSafeColumnName( column )# #operator# #queryParam(value)#" );
			}else{
				arrayAppend( _criteria.where, "#_getSafeColumnName( column )# #operator# #queryParam(value)#" );
			}
			return this;
		}
		private function _resetCriteria(){
			_criteria = { from = "", where = [], limit = "*", orderBy = "" };
		}

		/**
		* I return a SQL safe column name.  I will delegate to the DB specific
		* connector to return the actual safe column name based on the dao.dbtype.
		* However, if the column name not a valid column name (i.e. a number) I will
		* just return the column name unchanged
		**/
		private function _getSafeColumnName( required string column ){

			if( isValid( "variableName", column ) ){
				return getSafeColumnName( arguments.column );
			}

			return column;

		}


	</cfscript>

	<cffunction name="read" hint="I read from the database. I take either a tablename or sql statement as a parameter." returntype="any" output="false">
		<cfargument name="sql" required="false" type="string" default="" hint="Either a tablename or full SQL statement.">
		<cfargument name="name" required="false" type="string" hint="Name of Query (required for cachedwithin)" default="ret_#listFirst(createUUID(),'-')#_#getTickCount()#">
		<cfargument name="QoQ" required="false" type="struct" hint="Struct containing query object for QoQ" default="#{}#">
		<cfargument name="cachedwithin" required="false" type="any" hint="createTimeSpan() to cache this query" default="">
		<cfargument name="table" required="false" type="string" default="" hint="Table name to select from, use only if not using SQL">
		<cfargument name="columns" required="false" type="string" default="" hint="List of valid column names for select statement, use only if not using SQL">
		<cfargument name="where" required="false" type="string" hint="Where clause. Only used if sql is a tablename" default="">
		<cfargument name="limit" required="false" type="any" hint="Limit records returned.  Only used if sql is a tablename" default="">
		<cfargument name="offset" required="false" type="any" hint="Offset queried recordset.  Only used if sql is a tablename" default="">
		<cfargument name="orderby" required="false" type="string" hint="Order By columns.  Only used if sql is a tablename" default="">


		<cfset var tmpSQL = "" />
		<cfset var tempCFSQLType = "" />
		<cfset var tempValue = "" />
		<cfset var tmpName = "" />
		<cfset var idx = "" />
		<cfset var LOCAL = {} />

		<cfif !len( trim( arguments.sql ) ) && !len( trim( arguments.table ) )>
			<cfthrow message="You must pass in either a table name or sql statement." />
		</cfif>

		<cfif listlen( arguments.sql, ' ') EQ 1 && !len( trim( arguments.table ) )>
			<cfset arguments.table = arguments.sql/>
		</cfif>

		<!--- <cftry> --->
			<cfif len( trim( arguments.sql ) ) || len( trim( arguments.table ) )>
				<cftimer label="Query: #arguments.name#" type="debug">
				<cfif !structKeyExists( arguments.QoQ, 'query' ) >
						<cfif listlen(arguments.sql, ' ') GT 1>
							<cfif len(trim(arguments.cachedwithin))>
									<!---
										We need to parse the sql
										statement to find $queryParam()$ calls.  We do this by
										passing the sql to parseQueryParams, which replaces the
										$queryParam()$ function call with a pseudo cfqueryparam that
										we can digest here to build the query.  The returned pseudo
										cfqueryparam tag is structured as follows:

										<cfqueryparam
													cfsqltype="sql data type"  <--- this is converted
																					to cfsqltype using
																					getCFSQLType
													value="actual value" />
										EXAMPLE: $queryParam(value='abc',cfsqltype='varchar')$
										This can also be done prior to sending the SQL statement to this
										function by calling the queryParam() function directly.
										EXAMPLE: #dao.queryParam(value='abc',cfsqltype='varchar')#
										This direct method is recommended.
									 --->
									<!--- First thing to do is parse the queryparams from the sql statement (if any exist) --->
									<!--- <cfset tmpSQL = parseQueryParams(arguments.sql)/> --->


									<!--- Now we build the query --->
									<cfquery name="LOCAL.#arguments.name#" datasource="#variables.dsn#" result="results_#arguments.name#">
										<!---
											Parse out the queryParam calls inside the where statement
											This has to be done this way because you cannot use
											cfqueryparam tags outside of a cfquery.
											@TODO: refactor to use the query.cfc
										--->
										<cfset tmpSQL = parameterizeSQL( arguments.sql )/>
										<cfloop from="1" to="#arrayLen( tmpSQL.statements )#" index="idx">
											<cfset SqlPart = tmpSQL.statements[idx].before />
											#preserveSingleQuotes( SqlPart )#
											<cfif structKeyExists( tmpSQL.statements[idx], 'cfsqltype' )>
												<cfqueryparam
													cfsqltype="#tmpSQL.statements[idx].cfSQLType#"
													value="#tmpSQL.statements[idx].value#"
													list="#tmpSQL.statements[idx].isList#">
											</cfif>
										</cfloop>
										<!--- /Parse out the queryParam calls inside the where statement --->
									</cfquery>

							<cfelse>

									<!--- Now we build the query --->
									<cfquery name="LOCAL.#arguments.name#" datasource="#variables.dsn#" result="results_#arguments.name#">
										<!---
											Parse out the queryParam calls inside the where statement
											This has to be done this way because you cannot use
											cfqueryparam tags outside of a cfquery.
											@TODO: refactor to use the query.cfc
										--->
										<cfset tmpSQL = parameterizeSQL( arguments.sql )/>
										<cfloop from="1" to="#arrayLen( tmpSQL.statements )#" index="idx">
											<cfset SqlPart = tmpSQL.statements[idx].before />
											#preserveSingleQuotes( SqlPart )#
											<cfif structKeyExists( tmpSQL.statements[idx], 'cfsqltype' )>
												<cfqueryparam
													cfsqltype="#tmpSQL.statements[idx].cfSQLType#"
													value="#tmpSQL.statements[idx].value#"
													list="#tmpSQL.statements[idx].isList#">
											</cfif>
										</cfloop>
										<!--- /Parse out the queryParam calls inside the where statement --->
									</cfquery>

							</cfif>
						<cfelse>
							<!--- abstract --->
							<cfset LOCAL[arguments.name] = this.conn.select(
																table = arguments.table,
																columns = arguments.columns,
																name = arguments.name,
																where = arguments.where,
																orderby = arguments.orderby,
																limit = arguments.limit,
																offset = arguments.offset,
																cachedwithin = arguments.cachedwithin
															)/>
						</cfif>

				<cfelse>
					<cfset setVariable( arguments.qoq.name, arguments.qoq.query)>
					<cfquery name="LOCAL.#arguments.name#" dbtype="query">
						#PreserveSingleQuotes( sql )#
					</cfquery>
				</cfif>
				</cftimer>
			</cfif>
			<!--- <cfcatch type="any">
				<cfthrow errorcode="880" type="custom.error" detail="Unexpected Error" message="There was an unexpected error reading from the database.  Please contact your administrator. #cfcatch.message# #chr(10)# #arguments.sql#">
			</cfcatch>
		</cftry> --->

		<cfreturn LOCAL[arguments.name]  />
	</cffunction>


	<cffunction name="execute" hint="I execute database commands that do not return data.  I take an SQL execute command and return 0 for failure, 1 for success, or the last inserted ID if it was an insert." returntype="any" output="false">
		<cfargument name="sql" required="true" type="string" hint="SQL command to execute.  Can be any valid SQL command.">
		<cfargument name="writeTransactionLog" required="false" default="#this.getWriteTransactionLog() eq true#" type="boolean" hint="Do you want to write the executed statement to the transaction log?">

		<cfset var ret = 0 />
		<cfset var exec = "" />
		<cfset var LOCAL = structNew() />
		<cfset var result = {}/>
 		<cftry>

				<!---
					We need to parse the sql
					statement to find $queryParam()$ calls.  We do this by
					passing the sql to parseQueryParams, which replaces the
					$queryParam()$ function call with a pseudo cfqueryparam that
					we can digest here to build the query.  The returned pseudo
					cfqueryparam tag is structured as follows:

					<cfqueryparam
								cfsqltype="sql data type"  <--- this is converted
																to cfsqltype using
																getCFSQLType
								value="actual value" />

					EXAMPLE: $queryParam(value='abc',cfsqltype='varchar')$
					This can also be done prior to sending the SQL statement to this
					function by calling the queryParam() function directly.
					EXAMPLE: #dao.queryParam(value='abc',cfsqltype='varchar')#
					This direct method is recommended.
				 --->
				<!--- First thing to do is replace the <cfqueryparam with a delimiter chr(999) --->
				<cfset LOCAL.tmpSQL = parseQueryParams(arguments.sql)>
				<!--- Now we build the query --->

			 	<cfquery datasource="#variables.dsn#" result="LOCAL.result">
					<!--- The first position of the tmpSQL list will be the first section of SQL code --->
					#listFirst(preserveSingleQuotes(LOCAL.tmpSQL),chr(998))#
					<!--- Now, we loop through the rest of the tmpSQL to build the cfqueryparams --->
					<cfloop list="#listDeleteAt(LOCAL.tmpSQL,1,chr(998))#" delimiters="#chr(998)#" index="LOCAL.idx">
						<!---
							This will return the position and length of the cfsqltype
							We use this to extract the values for the actual cfqueryparam
						--->
						<cfset LOCAL.tempCFSQLType = reFindNoCase('cfsqltype\=#chr(777)#(.*?)#chr(777)#',LOCAL.idx,1,true)>
						<!--- A little regex to extract the value from the queryparam string  --->
						<cfset LOCAL.value = reReplaceNoCase(PreserveSingleQuotes(LOCAL.idx),'.*value\=#chr(777)#(.*?)#chr(777)#.*','\1','all')>
						<!--- Strip out any loose hanging special characters used for temporary delimiters (chr(999) and chr(777)) --->
						<cfset LOCAL.value = reReplaceNoCase(preserveSingleQuotes(LOCAL.value),chr(999),'','all')>

						<!--- We'll look for the list and null attributes to see if they exist and then extract their values --->
						<cfset LOCAL.tempList = reFindNoCase('list\=#chr(777)#(.*?)#chr(777)#',LOCAL.idx,1,true)>
						<cfif NOT arrayLen(LOCAL.tempList.pos) GTE 2 OR NOT isBoolean(mid(LOCAL.idx,LOCAL.tempList.pos[2],LOCAL.tempList.len[2]))>
							<cfset LOCAL.isList = false />
						<cfelse>
							<cfset LOCAL.isList = mid(LOCAL.idx,LOCAL.tempList.pos[2],LOCAL.tempList.len[2])/>
						</cfif>
						<cfset LOCAL.tempNull = reFindNoCase('null\=#chr(777)#(.*?)#chr(777)#',LOCAL.idx,1,true)>
						<cfif NOT arrayLen(LOCAL.tempNull.pos) GTE 2 OR NOT isBoolean(mid(LOCAL.idx,LOCAL.tempNull.pos[2],LOCAL.tempNull.len[2]))>
							<cfset LOCAL.isNull = false />
						<cfelse>
							<cfset LOCAL.isNull = mid(LOCAL.idx,LOCAL.tempNull.pos[2],LOCAL.tempNull.len[2])/>
						</cfif>

						<cfset LOCAL.cfSQLType = mid(LOCAL.idx,LOCAL.tempCFSQLType.pos[2],LOCAL.tempCFSQLType.len[2])/>

						<cfif getUseCFQueryParams()>
							<!--- Now write the cfqueryparam --->
							<cfqueryparam
								cfsqltype="#LOCAL.cfSQLType#"
								value="#LOCAL.value#"
								list="#LOCAL.isList#"
								null="#LOCAL.isNull#">
						<cfelse>
							#this.getNonQueryParamFormattedValue(
													value = LOCAL.value,
													cfsqltype = LOCAL.cfSQLType,
													list = LOCAL.isList,
													null = LOCAL.isNull)#

						</cfif>
						<!--- Now anything after the closing > should be  --->
					 	<cfif len(listLast(preserveSingleQuotes(LOCAL.idx),chr(999)))> #listLast(preserveSingleQuotes(LOCAL.idx),chr(999))#</cfif>
					</cfloop>
				</cfquery>

				<!--- Grab the last inserted ID if it was an insert --->
				<cfif refindNoCase('INSERT(.*?)INTO (.*?)\(',LOCAL.tmpSQL)>

					<cfif structkeyExists(LOCAL.result,'GENERATED_KEY')><!--- MySQL --->

						<cfset LOCAL.lastInsertedID = LOCAL.result.GENERATED_KEY/>

					<!--- Some versions of MSSQL call this 'GENERATEDKEY' (-sy) --->
					<cfelseif structkeyExists(LOCAL.result,'GENERATEDKEY')>

						<cfset LOCAL.lastInsertedID = LOCAL.result.GENERATEDKEY/>

					<cfelseif structkeyExists(LOCAL.result,'IDENTITYCOL')><!--- MSSQL --->

						<cfset LOCAL.lastInsertedID = LOCAL.result.IDENTITYCOL/>

					<cfelseif structkeyExists(LOCAL.result,'ROWID')><!--- Oracle --->

						<cfset LOCAL.lastInsertedID = LOCAL.result.ROWID/>

					<cfelseif structkeyExists(LOCAL.result,'SYB_IDENTITY')><!--- Sybase --->

						<cfset LOCAL.lastInsertedID = LOCAL.result.SYB_IDENTITY/>

					<cfelseif structkeyExists(LOCAL.result,'SERIAL_COL')><!--- Informix --->

						<cfset LOCAL.lastInsertedID = LOCAL.result.SERIAL_COL/>

					<cfelse><!--- Rely on db connector cfc to provide last ID --->

						<cfset LOCAL.lastInsertedID = getLastID()/>

					</cfif>

					<cfset ret = LOCAL.lastInsertedID/>

				<cfelse>
					<cfset LOCAL.lastInsertedID = 1/>
					<cfset ret = 1/>

				</cfif>


			<!--- Now write to the transaction log --->
			<cfif arguments.writeTransactionLog>
				<cfset this.logTransaction(arguments.sql,LOCAL.lastInsertedID)/>
			</cfif>
			<cfcatch type="database">
				<cfif findNoCase('Invalid data',cfcatch.Message)>
					<cfheader statuscode="500"/>
					<cfthrow errorcode="801" type="custom.error" detail="Invalid Data Type" message="The value: &quot;#cfcatch.value#&quot; was expected to be of type: &nbsp;#listLast(cfcatch.sql_type,'_')#.  Please correct the values and try again.">
				<cfelse>
					<cfrethrow>
				</cfif>
			</cfcatch>
			<cfcatch type="any">
				<cfthrow errorcode="802-dao.execute" type="custom.error" detail="Unexpected Error" message="There was an unexpected error updating the database.  Please contact your administrator. #cfcatch.message#">
				<cfset ret = 0/>
			</cfcatch>
		</cftry>

		<cfreturn ret />

	</cffunction>


	<cffunction name="readFromQuery" hint="I read from another query (query of query). I take a sql statement as a parameter." returntype="query" output="false">
		<cfargument name="sql" required="true" type="string" hint="Full SQL statement.">

		<cfset var ret = "" />

		<cfif len(trim(arguments.sql))>
			<cfquery name="ret" dbtype="query">
				#PreserveSingleQuotes(sql)#
			</cfquery>
		</cfif>

		<cfreturn ret />
	</cffunction>

	<cffunction name="getColumnType" hint="I return the datatype for the given table.column.." returntype="string" access="public" output="false">
		<cfargument name="table" required="true" type="string" hint="Table to define.">
		<cfargument name="column" required="true" type="string" hint="Column to define.">

		<cfset var def = define(arguments.table)>
		<cfset var col = "">
		<cfset var ret = "">

		<cfquery name="col" dbtype="query">
			SELECT * FROM def
			WHERE field = '#arguments.column#'
		</cfquery>
		<cfif find('(',col.type)>
			<cfset ret = listFirst(col.type,'(')>
		<cfelse>
			<cfset ret = col.type>
		</cfif>

		<cfreturn ret />
	</cffunction>

</cfcomponent>