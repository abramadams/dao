/**
************************************************************
*
*	Copyright (c) 2007-2018, Abram Adams
*
*	Licensed under the Apache License, Version 2.0 (the "License");
*	you may not use this file except in compliance with the License.
*	You may obtain a copy of the License at
*
*		http://www.apache.org/licenses/LICENSE-2.0
*
*	Unless required by applicable law or agreed to in writing, software
*	distributed under the License is distributed on an "AS IS" BASIS,
*	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*	See the License for the specific language governing permissions and
*	limitations under the License.
*
***********************************************************
*
*	Component	: dao.cfc
*	Author		: Abram Adams
*	Date		: 1/2/2007
*	@version 0.1.3
*	@updated 1/5/2018
*	Description	: Generic database access object that will
*	control all database interaction.  This component will
*	invoke database specific functions when needed to perform
*	platform specific calls.
*
*	For instance mysql.cfc has MySQL specific syntax
*	and routines to perform generic functions like obtaining
*	the definition of a table, the interface here is
*	define(tablename) and the MySQL function is DESCRIBE tablename.
*	To implement for MS SQL you would need to create a
*	mssql.cfc and have MS SQL specific syntax for the
*	define(tablename) function that returns a query object.
*
*	EXAMPLES:
*		// Create global database connection
*		dao = new dao(
*					   dsn		= "mydsn",
*					   user		= "dbuser",
*					   password = "dbpass",
*					   dbtype	= "mysql"
*					  );
*
*		Function read:
*		query = dao.read("users");
*		or:
*		query = dao.read("
*			select name, email
*			from users
*			where id = #dao.queryParam(1)#
*		");
*
*		Function write:
*		NewKey = application.dao.write('insert into users (id) values(1)');
*
*		Function update:
*		dao.update("
*			update users
*			set name = #dao.queryParam('test','varchar')#
*			where id = #dao.queryParam(12,'int')#
*		");
*
*		Function execute:
*		results = dao.execute("show databases");
*
*		Function delete:
*		dao.delete("users","*");
*
*********************************************************** */
component displayname="DAO" hint="This component is basically a DAO Factory that will construct the appropriate invokation for the given database type." output="false" accessors="true" {

	property name="dsn" type="string";
	property name="dbtype" type="string";
	property name="dbversion";
	property name="conn";
	property name="writeTransactionLog" type="boolean";
	property name="transactionLogFile" type="string";
	property name="tableDefs" type="struct";
	property name="autoParameterize" type="boolean" hint="Causes SQL to be cfqueryparam'd even if not specified";
	property name="nullValue" hint="The value to pass in if you want the queryParam to consider it null.  Default is $null";
	property name="SINGLEQUOTE" type="string" hint="Placeholder for escaped single quote character";
	property name="DOUBLEQUOTE" type="string" hint="Placeholder for escaped double quote character";
	property name="EQUALS" type="string" hint="Placeholder for escaped equals character";
	property name="COLON" type="string" hint="Placeholder for escaped equals character";
	property name="POUND" type="string" hint="Placeholder for escaped pound sign character";

	/* *************************************************************************** */
	/* Mixins for extended functionality (i.e. linq )							   */
	/* *************************************************************************** */
	// Adds linq style query functions (i.e. from().where()...)
	include "linq.cfm";


	/**
	* I initialize DAO
	* @dsn Data Source Name - If not supplied will use the default datasource specified in Application.cfc
	* @dbtype Database Type
	* @user Data Source User Name
	* @password Data Source Password
	* @writeTransactionLog Write transactions to log (for replication)
	* @transactionLogFile Location to write the transaction log
	* @useCFQueryParams Determines if execute queries will use cfqueryparam
	**/
	public DAO function init( string dsn = "",
							  string dbtype = "",
							  string user = "",
							  string password ="",
							  boolean writeTransactionLog = false,
							  string transactionLogFile = "#expandPath('/')#sql_transaction_log.sql",
							  boolean useCFQueryParams = true,
							  boolean autoParameterize = false,
							  string nullValue = "$null"  ){
		// If DSN wasn't supplied, see if there is a default dsn.
		if( !len( trim( dsn ) ) ){
			var = appMetaData = getApplicationMetadata();
			if( !isNull( appMetaData.datasource ) ){
				arguments.dsn = isSimpleValue( appMetaData.datasource ) ? appMetaData.datasource : appMetaData.datasource.name;
			}else{
				throw( type = "DAO.MissingDSN", message = "Could not determine which DSN to use.", detail = "You must either pass in a valid DSN (Datasource Name) or set a default datasource in Application.cfc" );
			}
		}
		//This is the datasource name for the system
		setDsn( arguments.dsn );
		setWriteTransactionLog( arguments.writeTransactionLog );

		setNullValue( nullValue );

		// CONSTANTS - Used for escaping characters in query params
		setSINGLEQUOTE( chr( 901 ) );
		setDOUBLEQUOTE( chr( 902 ) );
		setEQUALS( chr( 903 ) );
		setCOLON( chr( 904 ) );
		setPOUND( chr( 905 ) );

		// auto-detect the database type.
		if ( isDefined( 'server' ) && ( structKeyExists( server, 'railo' ) || structKeyExists( server, 'lucee' ) ) ){
			// Railo does things a bit different with dbinfo.
			// We pull in railo's version of dbinfo call so ACF doesn't choke on it.
			var railoHacks = new railoHacks( arguments.dsn );
			var v = railoHacks.getDBVersion();
		}else{
			// This is Adobe CF's way to dbinfo
			var d = new dbinfo( datasource = arguments.dsn );
			var v = d.version();
		}
		// normalize returned dbversion query into a struct
		setDbVersion( {
			'database_productname' = v.database_productname,
			'database_version' = v.database_version,
			'driver_name' = v.driver_name,
			'driver_version' = v.driver_version,
			'jdbc_major_version' = v.jdbc_major_version,
			'jdbc_minor_version' = v.jdbc_minor_version
		} );

		if ( !len( trim( arguments.dbtype ) ) ){
			arguments.dbtype = getConnecterType();
		}
		// This will define the type of database you are using (i.e. MySQL, MSSQL, etc)
		setDbType( dbType );
		this.user = user;
		this.password = password;

		//This is the actual db specific connection.
		var conn = createObject( "component", variables.dbType );

		// hmmm... isInstanceOf requires the full path from root to the "type", so I'd have to know that
		// IDAOConnector would always be in com.database.IDAOConnector
		// this hackery gets around this bug.
		var _interface = getComponentMetaData("IDAOConnector").fullName;
		_interface = listToArray( _interface, '.' );
		arrayDeleteAt( _interface, arrayLen( _interface ) );
		arrayAppend( _interface, "IDAOConnector" );
		_interface = arrayToList( _interface, '.' );
		// Adobe is so stupid... isInstanceOf doesn't work on ACF
		var connMeta = getMetaData( conn );
		if( !isInstanceOf(conn,_interface) && !connMeta.implements.keyExists( "IDAOConnector" ) ){
			throw( message = "Database Connector: ""#variables.dbType#"" must implement ""#_interface#"".", type = "DAO.init.InvalidConnector" );
		}

		setTransactionLogFile( transactionLogFile );
		setAutoParameterize( autoParameterize );
		setTabledefs({});

		conn.init(
				dao = this,
				dsn = getDsn(),
				user = user,
				password = password,
				useCFQueryParams = useCFQueryParams
				);
		setConn( conn );

		return this;
	}
	public function getConnecterType(){

		switch( variables.dbVersion.database_productname ){
			case "Microsoft SQL Server" : return "mssql";
			case "MySQL" : return "mysql";
		}
	}

	/**
	* Returns a new instance of DAO.  A simple convenience method
	* to get a fully initialized dao.
	**/
	public function new(){
		var copy = duplicate( this );
		copy._resetCriteria();
		return copy;
	}

	/**
	* I return the ID of the last inserted record.
	**/
	public function getLastID(){
		return getConn().getLastID();
	}

	/**
	* I insert data into the database.  I take a tabledef object containing the tablename and column values. I return the new record's Primary Key value.
	**/
	public function write( required tabledef tabledef, boolean insertPrimaryKeys = false ){
		return getConn().write( tabledef, insertPrimaryKeys );
	}


	/**
	* I insert data into a table in the database.  If inserting a single record I return the generated ID, if an array of records I return an array of IDs
	* @table Name of table to insert data into.
	* @data Struct or array of structs or a query object with name value pairs containing data.  Name must match column name.  This could be a form scope
	* @dryRun For debugging, will dump the data used to insert instead of actually inserting.
	* @onFinish Will execute when finished inserting.  Can be used for audit logging, notifications, post update processing, etc...
	**/
	public function insert( required string table, required any data, boolean dryRun = false, any onFinish = "", boolean insertPrimaryKeys = false, any callbackArgs = {}, boolean bulkInsert = false ){
		var LOCAL = {};
		if( !isStruct( data ) && !isArray( data ) && !isQuery( data ) ){
			throw( message = "Data must be a struct or an array of structs or a query object with key/value pairs where the key matches exactly the column name." );
		}
		// Convert to array if a single struct was passed in
		var __data = isStruct( data ) ? [ data ] : data;

		if( !structKeyExists( variables.tabledefs, arguments.table ) ){
			variables.tabledefs[ arguments.table ] = new tabledef( tablename = arguments.table, dsn = getDSN() );
		}
		var LOCAL.table = duplicate( variables.tabledefs[ arguments.table ] );
		var columns = LOCAL.table.getColumns();
		var newRecord = [];
		for( var dataRow in __data ){

			var row = LOCAL.table.addRow();

			// Iterate through each column in the table and either set the value with what's in the arguments.data struct
			// or set it to the default value defined by the table itself.
			var columnList = listToArray( columns );
			for( var column in columnList ){
				param name="dataRow.#column#" default="#LOCAL.table.getColumnDefaultValue( column )#";
				if ( structKeyExists( dataRow, column ) ){
					if( column == LOCAL.table.getPrimaryKeyColumn()
						&&  LOCAL.table.getTableMeta().columns[ column ].type != 4
						&& !len( trim( dataRow[ column ] ) ) ){
						LOCAL.table.setColumn( column = column, value = createUUID(), row = row );
					}else{
						 LOCAL.table.setColumn( column = column, value = dataRow[ column ], row = row);
					}
				}
			}
		}
		/// insert it
		if (!arguments.dryrun){
			newRecord.append( getConn().write( tabledef = LOCAL.table, insertPrimaryKeys = insertPrimaryKeys, bulkInsert = bulkInsert ) );
			// Insert has been performed.  If a callback was provided, fire it off.
			if( isCustomFunction( onFinish ) ){
				structAppend( arguments.callbackArgs, { "table" = arguments.table, "data" = LOCAL.table.getRow( newRecord.len() ), "id" = newRecord[ newRecord.len() ] } );
				onFinish( argumentCollection:callbackArgs );
			}
		}else{
			newRecord.append( {
					"Data" = dataRow,
					"Table Instance" = LOCAL.table,
					"Table Definition" = LOCAL.table.getTableMeta(),
					"Records to be Inserted" = LOCAL.table.getRows()
			});
		}

		return newRecord.len() > 1 ? newRecord : newRecord[ 1 ];
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
		var changes = [];

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
				&& compare( isNull( currentData[ column ][ 1 ] ) ? "" : currentData[ column ][ 1 ].toString(), isNull( arguments.data[ column ] ) ? "" : arguments.data[ column ].toString() ) ){

				// This will cause dao.update to only update the columns that have changed.
				// This will not only make the update slightly faster, but it will cut down
				// the transaction log size for offline replication.

				LOCAL.table.setColumnIsDirty( column = column, isDirty = true );
				LOCAL.isDirty = true;
				arrayAppend( changes, { "column" = column,"original" = currentData[ column ][ 1 ].toString(), "new" = arguments.data[ column ].toString() } );
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
			}else if( structKeyExists( arguments.data, column ) ){
				// The column data could potentially be a lazy loaded child, in which case it
				// would be a closure waiting to be executed.  This will execute and store the PK
				// value into the table data.
				if( isClosure( arguments.data[ column ] ) ){
					 var hydratedColumn = arguments.data[ column ]();
					LOCAL.table.setColumn( column = column, value = hydratedColumn.getID(), row = row );
				}else{
					LOCAL.table.setColumn( column = column, value = arguments.data[ column ], row = row );
				}
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
			structAppend( arguments.callbackArgs, { "table" = arguments.table, "data" = LOCAL.table.getRows(), "id" = LOCAL.table.getRows()[ IDField ], "changes" = changes } );
			try{
				onFinish( argumentCollection:callbackArgs );
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
	public function updateTable( required tabledef tabledef, string columns = "", string IDField = ""){
		var ret = "";

		if( !len( trim( arguments.IDField ) ) ){
			arguments.IDField = arguments.tabledef.getPrimaryKeyColumn();
		}
		return getConn().update( tabledef = arguments.tabledef, columns = arguments.columns, IDField = arguments.IDField );

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
		// try{
			transaction{

				if( arguments.RecordID is "*" ){
					ret = getConn().deleteAll( tablename = arguments.table );
				}else{
					ret = getConn().delete( tablename = arguments.table, recordid = arguments.recordid, idField = arguments.idfield );
				}
			}
		// } catch( any e ){
		// 	ret = false;
		// }


		if( isCustomFunction( onFinish ) ){
			structAppend( arguments.callbackArgs, { "table" = arguments.table, "id" = arguments.recordID } );
			onFinish( argumentCollection:callbackArgs );
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
				arguments.sql = LOCAL.tmpSQL;
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
		var ret = findNoCase( "cf_sql_", type ) ? type : "cf_sql_#type#";

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
		if( !listFirst( ret, '_') == 'cf'){
		writeDump( type );abort;
		}
		return ret;
	}

	/**
	* I return the structure of the passed table.
	**/
	public query function define( required string table ) {
		var def = getConn().define( arguments.table );

		return def;
	}

	public void function setUseCFQueryParams( required boolean useCFQueryParams ){
		// this.useCFQueryParams = arguments.useCFQueryParams;
		getConn().setUseCFQueryParams( arguments.useCFQueryParams );
	}

	public boolean function getUseCFQueryParams(){
		return getConn().getUseCFQueryParams();
	}

	/**
	* I return an array of tables for the current database
	**/
	public array function getTables(){
		if ( isDefined('server') && ( structKeyExists( server, 'railo' ) || structKeyExists( server, 'lucee' ) ) ){
			// railo does things a bit different with dbinfo.
			var railoHacks = new railoHacks( variables.dsn );
			// See if the table exists, if not return false;
			var tables = railoHacks.getTables();
			if( !tables.recordCount ){
				return [];
			}

		}else{
			var d = new dbinfo( datasource = variables.dsn );
			var tables = d.tables();
			if( !tables.recordCount ){
				return [];
			}
		}
		return listToArray( valueList( tables.table_name ) );
	}

	/**
	* I return a list of columns for the passed table
	**/
	public function getColumns( required string table, string prefix = table ){
		var def = new tabledef( tablename = arguments.table, dsn = variables.dsn );
		if( !def.instance.tablemeta.columns.count() ){
			throw( message="Table #table# was not found in #this.getDSN()#" );
		}
		var cols = def.getColumns( prefix = prefix );
		if( !len( trim( cols ) ) ){
			cols = "*";
		}

		return cols;
	}
	/**
	* I get the primary key for the given table. To do this I envoke the getPrimaryKey from the conneted database type.
	**/
	public function getPrimaryKey( required string table ){
		return getConn().getPrimaryKey( arguments.table );
	}
	/**
	* I take a list of columns and return it as a safe columns list with each column wrapped within the DB specific escape characters.
	**/
	public function getSafeColumnNames( required string cols ){
		return getConn().getSafeColumnNames( arguments.cols );;
	}

	/**
	*I take a single column name and return it as a safe columns list with each column wrapped within the DB specific escape characters.
	**/
	public function getSafeColumnName( required string col ){
		return getConn().getSafeColumnName( arguments.col );
	}

	/**
	* I return the opening escape character for a column name.
	**/
	public function getSafeIdentifierStartChar(){
		return getConn().getSafeIdentifierStartChar();
	}

	/**
	* I return the closing escape character for a column name.
	**/
	public function getSafeIdentifierEndChar(){
		return getConn().getSafeIdentifierEndChar();
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
	public function queryParam( required any value, string type = "", string cfsqltype = type, boolean list = false, boolean null = false ){

		var returnString = {};
		var returnStruct = {};
		// if the value is an array, we need to convert it to a list
		if( isArray( value ) ){
			// If the value is an array, treat it as a list
			arguments.list = true;
			value = value.toList();
		}
		// best guess if
		if( ( reFindNoCase( "${ts.*?}", value ) ) && ( cfsqltype does not contain "date" || cfsqltype does not contain "time" ) ){
			arguments.cfsqltype = "cf_sql_timestamp";
		}else if( !len( trim( cfsqltype ) ) ){
			// default to varchar
			arguments.cfsqltype = "cf_sql_varchar";
		}
		returnStruct = queryParamStruct( value = arguments.value, cfsqltype = arguments.cfsqltype, list = arguments.list, null = arguments.null );
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
		if( ( reFindNoCase( "${ts.*?}", value ) ) && ( cfsqltype does not contain "date" || cfsqltype does not contain "time" ) ){
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
	public function parameterizeSQL( required string sql, struct params = {}, boolean autoParameterize = getAutoParameterize() ) output="false" {

		var LOCAL = {};
		var tmp = {};
		var tempValue = "";
		var tempList = "";
		var tempCFSQLType = "";
		var tempParam = "";
		// strip out #'s in params so we don't try to parse them later.
		arguments.params = deSerializeJSON( reReplace( serializeJSON( params ), '##',getPOUND(), 'all' ) );
		var tmpSQL = parseQueryParams( arguments.sql, arguments.params );

		LOCAL.statements = [];
		if( autoParameterize && ( listLen( tmpSQL, chr( 998 ) ) LT 2 || !len( trim( listGetAt( tmpSQL, 2, chr( 998 ) ) ) ) ) ){

			// So, we didn't have the special characters (998) that indicate the parameters were created
			// using the queryParam() method, however, there may be some where clause type stuff that can
			// be "guessed".  Let's try that, and if we fail we'll just return the original sql statement
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
				newTmpSQL = parseQueryParams( str = newTmpSQL, params = params );
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

			tmp.before = listFirst( sqlFrag, chr( 998 ) );
			// remove trailing ' from previous clause
			if( left( tmp.before, 1 ) == "'" ){
				tmp.before = mid( tmp.before, 2, len( tmp.before ) );
			}

			tmp.before = preserveSingleQuotes( tmp.before );
			tempParam = listRest( sqlFrag, chr( 998 ) );
			tempParam = preserveSingleQuotes( tempParam );
			// Put #'s back into the value (stripped out previously to prevent cfml parsing)
			tempParam = reReplace( tempParam, getPOUND(), '##', 'all' );

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

			var tempNull = reFindNoCase( 'null\=#chr( 777 )#(.*?)#chr( 777 )#', tempParam, 1, true );

			tempNull = arrayLen( tempNull.pos ) >= 2 ? mid( tempParam, tempNull.pos[2], tempNull.len[2] ) : false;
			tmp.null = isBoolean( tempNull ) ? tempNull : false;
			if( tmp.null && listLast( trim( tmp.before ), " " ) == '=' ){
				tmp.before = listDeleteAt( tmp.before, listLen( tmp.before, ' ' ), ' ' ) & " IS ";
			}
			if( tmp.null && ( listLast( trim( tmp.before ), " " ) == '!=' ||  listLast( trim( tmp.before ), " " ) == '<>' ) ){
				tmp.before = listDeleteAt( tmp.before, listLen( tmp.before, ' ' ), ' ' ) & " IS NOT ";
			}
			arrayAppend( LOCAL.statements, tmp );
			// Reset tmp struct
			tmp = {};
		}
		return LOCAL;
	}

	private function parseNamedParamValues( required string str, required struct params  ){
		try{
			var startPos = findnocase(chr(35),str,1);
			if ( startPos ){
				startPos = startPos + 1;
				var endPos = findnocase(chr(35),str,startPos) - startPos;
				if ( !endPos ){
					throw("Closing ## Not specified!");
				}
				var tmpStartString = mid(str,1,startPos - 2);
				var tmpString = mid(str,startPos,endPos);
				var tmpEndString = mid(str, len(tmpStartString) + endPos + 3,len(str));

				tmpString = reReplaceNoCase( tmpString,'&quot;',"'",'all' );
				tmpString = reReplaceNoCase( tmpString, '\"', getDOUBLEQUOTE(), 'all' );
				tmpString = reReplaceNoCase( tmpString, '\:', getCOLON(), 'all' );
				// var eval_string = evaluate(tmpString);
				var eval_string = isDefined("#tmpString#") ? arguments.params[ tmpString.listLast('.') ] : '';
				// if eval_string is an array, convert it to a list.
				if( isArray( eval_string ) ){
					eval_string = arrayToList( eval_string );
				}
				var returnString = tmpStartString & eval_string & tmpEndString;
				return parseNamedParamValues( returnString, params );
			}else{
				return str;
			}
		} catch( "coldfusion.runtime.UndefinedVariableException" e ){
			throw( message = "Expected named parameter: #e.name#, but only got #structKeyList( arguments.params )#.", detail = e, type = "DAO.parseQueryParams.MissingNamedParameter" );
		} catch( any e ){
			// For Railo's sake....
			if( reFindNoCase( "key \[.*?\] does(\snot|n't) exist", e.message ) ){
				e.name = rEReplaceNoCase( e.message, "key \[(.*?)\] does(\snot|n't) exist", '\1', 'all' );
				throw( message = "Expected named parameter: #e.name#, but only got #structKeyList( arguments.params )#.", detail = e, type = "DAO.parseQueryParams.MissingNamedParameter" );
			}else{
				rethrow;
			}
		}
	}
	/**
	* I parse queryParam calls in the passed SQL string.  See queryParam() for syntax.
	**/
	public function parseQueryParams( required any str, struct params = {} ){
		for( var param in params ){
			if( isSimpleValue( params[param] ) ){
				params[param] = reReplaceNoCase( params[param], '"', getDOUBLEQUOTE() );
				params[param] = reReplaceNoCase( params[param], "'", getSINGLEQUOTE() );
				params[param] = reReplaceNoCase( params[param], "=", getEQUALS() );
				params[param] = reReplaceNoCase( params[param], ":", getCOLON() );
			}
		}
		str &= " ";// pad with trailing space for simpler regex.
		// This function wll parse the passed SQL string to replace $queryParam()$ with the evaluated
		// <cfqueryparam> tag before passing the SQL statement to cfquery (dao.read(),execute()).  If the
		// SQL is generated in-page, you can use dao.queryParam()$ directly to create query parameters.
		// the $queryParam()$ will delay evaluation of its arguments until query is executed. This is an old
		// approach, and should be avoided.  The new approach is to use the named params as described below:
		//*******
		// Parse any named params.  These are a shorthand for $queryParam() and have the syntax of:
		// :paramName{[optional type="data type"], [optional null="true/false"], [optional list="true/false"]}
		// The paramName portion must match a key in the arguments.params struct.
		// examples:
		// :firstName{ type="varchar" }
		// :isAdmin{ type="bit", null=false }
		// :userIds{ type="int", list=true }
		// You can also pass in just the named param without options such as:
		// :email or :email{}
		// In these cases the type will be guessed based on the value.
		// An example in a SQL query:
		// dao.read("
		// 		SELECT * FROM users
		//		WHERE isAdmin = :isAdmin{ type="bit", null=false }
		//		OR ( first_name LIKE :firstName{ type="varchar" }
		//			AND email = :email
		// 			)
		//		OR ID IN (:userIds{ type="int", list=true })
		//		",
		//		{ firstName = 'Jim%', email = session.user.email isAdmin = session.user.isAdmin, userIds = "1,2,4,77" }
		// );

		// Let's inspect the possible named parameters to see if they are really parameters or just the existence
		// of :somevalue in the value string.  If the parameter variable exists we're assuming :somevalue was a
		// named parameter, otherwise we'll treat it as a literal string.
		var possibleParams = str.refind( '(:(?![0-9|\s])\w[^\{]*?)(?=\s|\)|,|$)', 0, true );
		if( possibleParams.keyExists('pos') && possibleParams.pos[1] > 0 ){
			// possible parameter found, let's inspect each one
			possibleParams.pos.each( function( pos, index ){
				// Match results will find each instance twice because of regex grouping. We only need to inspect once each
				if( index mod 2 ){
					var tmpParamPrestine = str.mid( pos, possibleParams.len[ index ] );
					var tmpParam = str.mid( pos, possibleParams.len[ index ] );
					tmpParam = " " & tmpParam;
					var tmpParam = tmpParam.listRest(':');
					tmpParam = trim( tmpParam );
					// If the parameter exists in the params struct, we'll normalize the param syntax to :name{}
					if( len( trim( tmpParam ) ) && params.keyExists( tmpParam ) ){
						str = reReplaceNoCase( str, tmpParamPrestine,'#tmpParamPrestine#{}', 'all' );
					}
				}
			});
		}


		// pull out : in values.
		str = reReplaceNoCase( str, 'value=\#chr( 777 )#(.*?)(:+)(.*?)\#chr( 777 )#', 'value=#chr( 777 )#\1#chr(765)#\3#chr( 777 )#','all' );
		// pull out the : in date object values that can break the named param regex
		str = reReplaceNoCase( str, "{ts '(.*?):(.*?)'}","{ts '\1#chr(765)#\2'}", "all" );
		// now parse named params
		str = reReplaceNoCase( str, '((\s|\t|\(|,):)(?![0-9|\s])(\w[^\{]*?)(?=\s|\)|,|$)','\1\3{}','all');
		str = reReplaceNoCase( str, '(\s|\t|\(|,):(\w*?)\{(.*?)\}','\1$queryParam(%%%="##arguments.params.\2##",\3)$','all');

		str = reReplace(str,',\)',')','all');
		if( findNoCase( '##arguments.params', str) ){
			str = parseNamedParamValues( str, params );
			str = reReplaceNoCase( str, 'value+(\s*?)=(\s|''|"\s)(.*?)(''|"\s)', '', 'all' );
			str = reReplaceNoCase( str, '\%\%\%=', 'value=', 'all' );
			str = reReplaceNoCase( str, '(,+[\s]*,)', ',', 'all' );
			str = reReplace( str, "=+(\s*)'(.*?)'", '="\2"', 'all' );
		}

		// put the : back into date values
		str = reReplace( str, chr(765), ":", "all" );
		// get rid of empty curlies
		str = reReplace( str, "{}", "", "all" );

		// First we check to see if the string has anything to parse
		var startPos = findNoCase('$queryparam(',arguments.str,1);
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
			endPos 	= ( find( ')$', arguments.str, startPos ) - startPos )+1;
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

				tmpString = reReplaceNoCase( tmpString, '^queryParam\(', '', 'all' );
				tmpString = reReplaceNoCase( tmpString, '\)$', '', 'all' );

				// literal strings would have been passed in as quoted values
				// This needs to be removed in order to be converted to JSON -> Struct.
				// The values to be param'd could be in an IN() list, so we need to parse
				// those out differently.
				// First, protect any escaped single quotes:
				tmpString = reReplaceNoCase( tmpString, "\\'",getSINGLEQUOTE(), "all" );
				// tmpString = reReplaceNoCase( tmpString, '\\"',getDOUBLEQUOTE(), "all" );
				// Now protect date ojbects
				tmpString = reReplaceNoCase( tmpString, "{ts '(.*?)'}","{ts #getSINGLEQUOTE()#\1#getSINGLEQUOTE()#}", "all" );
				// Now scrube the passed in queryparam args if present (makes later regex easier)
				tmpString = reReplaceNoCase( tmpString, "cfsqltype(\s*?)="," cfsqltype=", "all" );
				tmpString = reReplaceNoCase( tmpString, "null(\s*?)="," null=", "all" );
				tmpString = reReplaceNoCase( tmpString, "list(\s*?)="," list=", "all" );
				// Now clean up any unquoted boolean values
				tmpString = reReplaceNoCase( tmpString, "value(\s*?)=(\s*?)(false|true)+",'value="\3"', "all" );
				tmpString = reReplaceNoCase( tmpString, "value(\s*?)=(\s*?)(\{ts .*?\})+",'value="\3"', "all" );

				tmpArr = listToArray( tmpString, "'" );
				if( !arrayLen( tmpArr ) GT 3 || !arrayLen( tmpArr ) mod 2 ){
					// Only one set of quotes were found.  Now we can simply remove those.
					tmpString = reReplaceNoCase( tmpString, "=(\s*?)'(.*?)'", '="\2"', "all" );
				} else{
					// More than one set of quotes found.  That means this was an IN statement and
					// all of the single quotes need to be extracted.
					tmpString = reReplaceNoCase( tmpString, "'", "", "all" );
					tmpString &= ', list="true"';
				}

				// Now restore any quotes or doublequotes as escaped characters:
				tmpString = reReplaceNoCase( tmpString, getSINGLEQUOTE(),"\'", "all" );
				tmpString = reReplaceNoCase( tmpString, getDOUBLEQUOTE(),'\"', "all" );
				// tmpString = reReplaceNoCase( tmpString, '[^=|\s]"("|\s+)','\"\1', "all" );

				tmpString = reReplaceNoCase( tmpString, "{ts #getSINGLEQUOTE()#(.*?)#getSINGLEQUOTE()#}","{ts '\1'}", "all" );
				// Fixes bug in parameterizeSQL() regex.
				tmpString = reReplaceNoCase( tmpString, 'value="=','value="', "all" );

				// Clean up blanks
				tmpString = reReplaceNoCase( tmpString, "''",'\"\"', "all" );
				// Clean up empty {}s
				tmpString = reReplaceNoCase( tmpString, '}"{}','}"', "all" );


				// wrap the keys in quotes to preserve case
				tmpString = "{" & reReplaceNoCase( tmpString, "(\s*)(\w*)(\s|,*?)=", """\2"":", "all" ) & "}";

				// Now restore any equals signs or colon characters
				tmpString = reReplaceNoCase( tmpString, getEQUALS(),'=', "all" );
				tmpString = reReplaceNoCase( tmpString, getCOLON(),':', "all" );

				if( !isJSON( tmpString ) ){
					throw( errorcode="881", message="Invalid QueryParam", type="DAO.parseQueryParams.InvalidQueryParam",
						detail="The query parameter passed in is not properly escaped.  Make sure to wrap literals in quotes. ""#originalString#"" ==> ""#tmpString#""  || ""#arguments.str#""");
				}
				// turn the JSON into a CF struct
				tmpString = deSerializeJSON( tmpString );
				if( structKeyExists( tmpString, 'type' ) ){
					tmpString.cfsqltype = tmpString.type;
				}
				// If the value is an array, and list == true we'll convert the array to a list.
				if( structKeyExists( tmpString, 'list' ) && tmpString.list && isArray( tmpString.value ) ){
					tmpString.value = arrayToList( tmpString.value );
				}
				// finally we can evaluate the queryParam struct.  This will scrub the values (i.e. proper cfsql types, prevent sql injection, etc...).
				evalString = queryParamStruct(
												value = structKeyExists( tmpString, 'value' ) ? tmpString.value : '',
												cfsqltype = structKeyExists( tmpString, 'cfsqltype' ) ? tmpString.cfsqltype : '',
												list= structKeyExists( tmpString, 'list' ) ? tmpString.list : false,
												null = structKeyExists( tmpString, 'null' ) ? tmpString.null :
													reReplace( tmpString.value, '"|''', '', 'all') eq this.getNullValue()
													? true : false
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

					return parseQueryParams( str = returnString, params = params );
				}else{
					// The evaluated string was not a simple object and could be malicious so we'll
					// just pass back an error message so the programmer can fix it.
					throw( message = "Parsed queryParam is not a struct!", type = "DAO.parseQueryParams.InvalidQueryParam" );
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
		return getConn().makeTable( arguments.tabledef );
	}

	/**
	* Delegates the dropping of a "table" to the underlying persistence storage "connector"
	**/
	public void function dropTable( required string table ){
		getConn().dropTable( arguments.table );
	}


	/**
	* I return a SQL safe column name.  I will delegate to the DB specific
	* connector to return the actual safe column name based on the dao.dbtype.
	* However, if the column name not a valid column name (i.e. a number) I will
	* just return the column name unchanged
	**/
	public function _getSafeColumnName( required string column ){

		if( isValid( "variableName", column ) ){
			if( listLen( arguments.column, '.' ) GT 1 ){
				return getSafeColumnName( listFirst( arguments.column, '.' ) ) & '.' & getSafeColumnName( listRest( arguments.column, '.' ) );
			}
			return getSafeColumnName( arguments.column );
		}

		return column;

	}

	/**
	* I return the query as an array of structs.  Not super efficient with large recordsets,
	* but returns a useable data set as apposed to the aweful job serializeJSON does with queries.
	* @qry is the query object we wish to convert to an array of structs
	* @map is an optional function that will be executed against every record in the qry results ( basically an array map function )
	* @forceLowercaseKeys true or false.  If false will try to retain the original case, but often derived queries will have uppercase keys because ColdFusion
	* @returnEmptyStruct true or false.  If false will return empty array if qry.recordcount is zero.  If true will return a single item array containing a struct mirroring the query columns with empty data.
	**/
	public function queryToArray( required query qry, any map, boolean forceLowercaseKeys = false, returnEmptyStruct = false ){
		var queryArray = [];

		// Using getMetaData instead of columnList to preserve case. Using qry.getMetaData().getColumnLabels()
		// retains case of the original SQL used to generate the query. So if a list of columns were provided
		// dynamically, chances are they are uppercase and not the actual case used in the table definition.
		// Also, notice the hack to convert to a list then back to array.
		// This is because getMetaData doesn't return real arrays (as far as CF is concerned)
		if ( isDefined( 'server' ) && ( structKeyExists( server, 'railo' ) || structKeyExists( server, 'lucee' ) ) ){
			var sqlString = qry.getSQL().getSQLString();
		}else{
			var sqlString = qry.getMetadata().getExtendedMetaData().sql;
		}

		var tablesInQry = reMatchNoCase( "FROM\s+[\[|`|.]*(\w+)[\]|`]*\s+", sqlString & " " );
		if( !tablesInQry.len() ){
			throw("Unable to determine table name(s) in query");
		}
		var tableName = listLast( tablesInQry[ 1 ], ' ' );

		// Check for the tabledef object for this table, if it doesn't already exist, create it
		if( !structKeyExists( variables.tabledefs, tableName) ){
			variables.tabledefs[ tableName ] = new tabledef( tablename = tableName, dsn = getDSN() );
		}

		// Grabs column names preserving case.
		// This could have been used on a table based query
		// but it relies on the case of the typed in columns in
		// the sql statement, not necessarily the true column name case.
		var colList = _getQueryColumnNames( qry );

		if( !arrayLen( colList ) ){
			// KNOWN ISSUE: This does not retain the column order of the original sql string
			colList = listToArray( structKeyList( variables.tabledefs[ tableName ].getTableMeta().columns ) );
		}
		// Support for JOIN tables
		if( findNoCase( "JOIN ", sqlString ) ){
			// When ACF10 support is no longer needed, replace this with member & reduce functions.
			var sqlJoinTables = listToArray( reReplaceNoCase( sqlString, "JOIN ", chr( 999 ), 'all' ), chr( 999 ) );
			arrayDeleteAt( sqlJoinTables, 1 );
			for( var sqlJoin in sqlJoinTables ){
				var tmpSQLJoinTable = trim( listFirst( sqlJoin, ' ' ) );
				if( !structKeyExists( variables.tabledefs, tmpSQLJoinTable) ){
					variables.tabledefs[ tmpSQLJoinTable ] = new tabledef( tableName = tmpSQLJoinTable, dsn = getDSN() );
				}
			}
			arrayAppend( colList, listToArray( structKeyList( variables.tabledefs[ tmpSQLJoinTable ].getTableMeta().columns ) ), true );
			// Since joined tables typically have aliased columns we'll merge all the query columns;
			arrayAppend( colList, _getQueryColumnNames( qry ), true );
		}
		var i = 0;
		var isNullisClosureValue = !isNull( map ) && isClosure( map );
		var tempListToArray = listToArray( qry.columnList );
		if( qry.recordCount ){
			for( var rec in qry ){
				i++;
				var cols = {};
				// if supplied, run query through map closure for custom processing

				if( isNullisClosureValue ){
					var tmpRec = map( row = rec, index = i, cols = colList );
					// If the return value is not a row struct, it means it was deleted.
					// This really should be abstracted to a "reduce" function, but I think
					// it's worth adding to map in this context
					if( !isDefined( 'tmpRec' ) || !isStruct( tmpRec ) ) {
						queryDeleteRow( qry, i );
						continue;
					}
					rec = tmpRec;

					// rec = map( rec, i, tempListToArray );
					// Add any cols that may have been added during the map transformation
					var newCols = listToArray( structKeyList( rec ) );
					for( var newCol in newCols ){
						if( !arrayFindNoCase( colList, newCol ) ){
							arrayAppend( colList, newCol );
						}
					}
				}

				for( var col in colList ){
					if( structKeyExists( rec, col ) ){
						if( forceLowercaseKeys ){
							structAppend( cols, {'#lcase(col)#' = rec[col] } );
						}else{
							structAppend( cols, {'#col#' = rec[col] } );
						}
					}
				}
				arrayAppend( queryArray, cols );
			}
		}else if( returnEmptyStruct ){
			var cols = {};
			for( var col in colList ){
				if( structKeyExists( qry, col ) ){
					if( forceLowercaseKeys ){
						structAppend( cols, {'#lcase(col)#' = "" } );
					}else{
						structAppend( cols, {'#col#' = "" } );
					}
				}
			}
			arrayAppend( queryArray, cols );
		}
		return queryArray;
	}

	/**
	* Returns an array of column names included in the given query (preserves case)
	**/
	public function _getQueryColumnNames( required query qry ){
		// NOTE: getColumnNames() returns a native Java array, which does
		// not inherently work like a CF array; so we must convert to a CF
		// array.  In Railo/Lucee we can use arrayMerge to convert to array
		// but this does not exist in ACF.  ACF's array functions fail (i.e. arrayAppend)
		// on this type of array, so the only way I've found to make it native in
		// ACF is to serialize then deserialize the array.  Unfortunately this hack
		// doesn't seem to work in Railo/Lucee, thus the logic below.
		// NOTE: ACF doesn't support queryObject.getColumn()... It also doesn't return a real CF array
		// so we have to serialize/deserialize to make it an array of structs that ACF can handle
		if( isDefined( 'server' ) && ( structKeyExists( server, 'railo' ) || structKeyExists( server, 'lucee' ) ) ){
			return arrayMerge( [], qry.getColumns() );
		}else{
			return deSerializeJSON( serializeJSON( qry.getColumnNames() ) );
		}
	}
	/**
	* I return the query as an JSON array of structs.  Not super efficient with large recordsets,
	* but returns a useable data set as apposed to the aweful job serializeJSON does with queries.
	**/
	public function queryToJSON( required query qry, any map, boolean forceLowercaseKeys = false ){
		return serializeJSON( queryToArray( argumentCollection:arguments ) );
	}

	/**
	* Applies a limit and offset to a given query object to provide
	* server side paging.  Optionally adds a column to include the
	* full non-paged recordcount (i.e. for "1 to 5 of x" type counts)
	**/
	public function pageRecords(
		required query qry,
		numeric offset = 0,
		numeric limit = 0,
		boolean returnFullCount = true,
		string fullCountName = "__fullCount"
	){
		var recordCount = qry.recordCount;
		if( returnFullCount ){
			var fullCount = qry.recordCount;
			queryAddColumn( qry, fullCountName, listToArray( repeatString( recordCount & ",", fullCount ) ) );
		}

		if ( offset > 0 ){
			// remove first n rows
			qry.removeRows( javaCast( "int", 0 ), javaCast( "int", ( offset < recordCount ) ? offset : recordCount ) );
		}
		if( limit > 0 && qry.recordCount && limit <= qry.recordCount ){
			// remove last n rows
			qry.removeRows( javaCast( "int", limit ), javaCast( "int", qry.recordCount - limit ) );
		}

		return qry;
	}

	/**
	* @hint I read from the database. I take either a tablename or sql statement as a parameter.
	*
	* @sql required="false" type="string" default="" hint="Either a tablename or full SQL statement."
	* @params required="false" type="struct" hint="Struct containing named query param values used to populate the parameterized values in the query (see parameterizeSQL())" default="#{}#"
	* @name required="false" type="string" hint="Name of Query (required for cachedwithin)" default="ret_#listFirst(createUUID(),'-')#_#getTickCount()#"
	* @QoQ required="false" type="struct" hint="Struct containing query object for QoQ" default="#{}#"
	* @cachedwithin required="false" type="any" hint="createTimeSpan() to cache this query" default=""
	* @table required="false" type="string" default="" hint="Table name to select from, use only if not using SQL"
	* @columns required="false" type="string" default="" hint="List of valid column names for select statement, use only if not using SQL"
	* @where required="false" type="string" hint="Where clause. Only used if sql is a tablename"
	* @limit required="false" type="any" hint="Limit records returned." default=""
	* @offset required="false" type="any" hint="Offset queried recordset." default=""
	* @orderby required="false" type="string" hint="Order By columns.  Only used if sql is a tablename" default=""
	* @returnType required="false" type="string" hint="Return query object or array of structs. Possible options: query|array|json" default="query"
	* @returnEmptyStruct required="false" type="boolean" hint="If false will return empty array if qry.recordcount is zero.  If true will return a single item array containing a struct mirroring the query columns with empty data.  Only used if returnType == array or json" default="false"
	* @file required="false" type="string" hint="Full path to a script file to be read in as the SQL string. If this value is passed it will override any SQL passed in." default=""
	* @map required="false" type="any" hint="A function to be executed for each row in the results ( only used if returnType == array )" default=""
	* @forceLowercaseKeys required="false" type="boolean" hint="Forced struct keys to lowercase ( only used if returnType == array )" default="false"
	*
	**/
	public any function read(
			 string sql = "",
			 struct params = {},
			 string name = "ret_#listFirst(createUUID(),'-')#_#getTickCount()#",
			 struct QoQ = {},
			 any cachedwithin = "",
			 string table = "",
			 string columns = "",
			 string where = "",
			 any limit = "",
			 any offset = "",
			 string orderby = "",
			 string returnType = "query",
			 boolean returnEmptyStruct = false,
			 string file = "",
			 any map = "",
			 boolean forceLowercaseKeys = false
	){

		var tmpSQL = "";
		var tempCFSQLType = "";
		var tempValue = "";
		var tmpName = "";
		var idx = "";
		var LOCAL = {};
		// where is also a function name in this cfc, so let''s localize the arg
		var _where = isNull( arguments.where ) ? "" : arguments.where;

		if( !len( trim( arguments.sql ) ) && !len( trim( arguments.table ) ) ){
			throw message="You must pass in either a table name or sql statement.";
		}

		if( listlen( arguments.sql, ' ') EQ 1 && !len( trim( arguments.table ) ) ){
			arguments.table = arguments.sql;
		}

		if( len( trim( arguments.sql ) ) || len( trim( arguments.table ) ) ){
			if( listLen( arguments.sql, ' ') > 1 ){

				// We need to parse the sql
				// statement to find $queryParam()$ calls.  We do this by
				// passing the sql to parseQueryParams, which replaces the
				// $queryParam()$ function call with a pseudo cfqueryparam that
				// we can digest here to build the query.  The returned pseudo
				// cfqueryparam tag is structured as follows:

				// cfqueryparam
				// 			cfsqltype="sql data type"  <--- this is converted
				// 											to cfsqltype using
				// 											getCFSQLType
				// 			value="actual value";
				// EXAMPLE: $queryParam(value='abc',cfsqltype='varchar')$
				// This can also be done prior to sending the SQL statement to this
				// function by calling the queryParam() function directly.
				// EXAMPLE: #dao.queryParam(value='abc',cfsqltype='varchar')#
				// This direct method is recommended.


				// Now we build the query
				var tmpSQL = parameterizeSQL( arguments.sql, arguments.params );
				var sql = "";
				var paramMap = [];
				/*
					Parse out the queryParam calls inside the where statement
					This has to be done this way because you cannot use
					cfqueryparam tags outside of a cfquery.
				 */
				// Parse out the queryParam calls inside the where statement
				savecontent variable="sql"{
					for( var statement in tmpSQL.statements ){
							var SqlPart = statement.before;
							writeOutput(preserveSingleQuotes( SqlPart ));
							if( statement.keyExists( 'cfsqltype' ) ){
								paramMap.append({ cfsqltype: statement.cfsqltype, value: statement.value, list: statement.isList });
								writeOutput('?');
							}
					}
					// Honor the order by if passed in
					if( len( trim( arguments.orderby ) ) ){
						writeOutput( 'ORDER BY #orderby#' );
					}
				};

				var options = {
					"datasource": variables.dsn,
					"result": "results_#arguments.name#"
				};
				if( len( trim( arguments.cachedWithin ) ) ){
					options["cachedWithin"] = cachedWithin;
				}
				if( QoQ.size() ){
					// Query of Query
					var fullCount = QoQ[ listFirst( QoQ.keyList() ) ].recordCount;
					options["dbtype"] = "query";
					options["maxrows"] = val(limit) && (!structKeyExists( arguments, 'offset' ) || offset eq 0) ? limit : 2147483647;
					variables.append( arguments.QoQ );
				}
				local[ name ] = queryExecute( sql, paramMap, options );
				if( !isDefined( 'fullCount' ) ){
					var fullCount = local[ name ].recordCount;
				}
				//  DB Agnostic Limit/Offset for server-side paging
				if( QoQ.size() && val( limit ) && ( !arguments.keyExists( 'offset' ) || offset == 0 ) && !LOCAL[ name ].keyExists( '__fullCount ' ) ){
					queryAddColumn( LOCAL[ name ], '__fullCount', listToArray( repeatString( fullCount & ",", LOCAL[ name ].recordCount ) ) );
				}else
				if( !QoQ.size() && len( trim( limit ) ) && len( trim( offset ) ) ){
					LOCAL[ name ] = pageRecords( LOCAL[ name ], offset, limit );
				}

			}else{
				// Query by table
				// abstract
				LOCAL[arguments.name] = getConn().select(
													table = table,
													columns = columns,
													name = name,
													where = _where,
													orderby = orderby,
													limit = limit,
													offset = offset,
													cachedwithin = cachedwithin
												);
			}


			if( !structKeyExists( LOCAL, arguments.name ) ){
				throw( errorcode="882", type="DAO.Read.InvalidQueryType", detail="Invalid Query Type for ""DAO.read()""", message="The query was either invalid or was an insert statement.  Use DAO.Execute() for insert statements." );
			}
			if( arguments.returnType == 'array' ){
				return queryToArray( qry = LOCAL[arguments.name], map = map, forceLowercaseKeys = forceLowercaseKeys, returnEmptyStruct = returnEmptyStruct );
			}else if( arguments.returnType eq 'json' ){
				return queryToJSON( qry = LOCAL[arguments.name], map = map, forceLowercaseKeys = forceLowercaseKeys, returnEmptyStruct = returnEmptyStruct );
			}else{
				var isNullisClosureValue = !isNull( map ) && isClosure( map );
				LOCAL.columns = listToArray( LOCAL[ arguments.name ].columnList );
				if( isNullisClosureValue ){
					var i = 0;
					for( var rec in LOCAL[ arguments.name ] ){
						i++;
						var tmpRec = map( row = rec, index = i, cols = LOCAL.columns );
						// If the return value is not a row struct, it means it was deleted.
						// This really should be abstracted to a "reduce" function, but I think
						// it's worth adding to map in this context
						if( !isDefined( 'tmpRec' ) || !isStruct( tmpRec ) ) {
							queryDeleteRow( LOCAL[ arguments.name ], i );
							continue;
						}
						rec = duplicate(tmpRec);
						// Add any cols that may have been added during the map transformation
						var newCols = rec.keyList().listToArray();
						for( var newCol in newCols ){
							if( !queryColumnExists( LOCAL[ arguments.name ], newCol ) ){
								queryAddColumn( LOCAL[ arguments.name ], newCol, rec );
							}
							var col = forceLowercaseKeys ? newCol.lcase() : newCol;
							querySetCell( LOCAL[ arguments.name ], col, rec[ col ], i );
						}
					}
				}
				return LOCAL[ arguments.name ];
			}
		}
	}

	/**
	* @hint I execute database commands that do not return data.  I take an SQL execute command and return 0 for failure, 1 for success, or the last inserted ID if it was an insert.
	* @sql required="true" type="string" hint="SQL command to execute.  Can be any valid SQL command."
	* @params required="false" type="struct" hint="" default="#{}#"
	* @writeTransactionLog required="false" default="#this.getWriteTransactionLog() eq true#" type="boolean" hint="Do you want to write the executed statement to the transaction log?"
	**/
	public any function execute( required string sql, struct params = {}, boolean writeTransactionLog = this.getWriteTransactionLog() ){

		var ret = 0;
		var exec = "";
		var LOCAL = {};
		var result = {};
		var options = { datasource: variables.dsn };
		var paramMap = [];
		try{


			// We need to parse the sql
			// statement to find $queryParam()$ calls.  We do this by
			// passing the sql to parseQueryParams, which replaces the
			// $queryParam()$ function call with a pseudo cfqueryparam that
			// we can digest here to build the query.  The returned pseudo
			// cfqueryparam tag is structured as follows:

			// cfqueryparam
			// 			cfsqltype="sql data type"  <--- this is converted
			// 											to cfsqltype using
			// 											getCFSQLType
			// 			value="actual value";

			// EXAMPLE: $queryParam(value='abc',cfsqltype='varchar')$
			// This can also be done prior to sending the SQL statement to this
			// function by calling the queryParam() function directly.
			// EXAMPLE: #dao.queryParam(value='abc',cfsqltype='varchar')#
			// This direct method is recommended.

			// First thing to do is replace the cfqueryparam with a delimiter chr(999)
			LOCAL.tmpSQL = parseQueryParams( str = arguments.sql, params = params );
			// Now we build the query
			var execSQL = "";
			savecontent variable="execSQL"{
				// The first position of the tmpSQL list will be the first section of SQL code
				writeOutput( listFirst( preserveSingleQuotes( LOCAL.tmpSQL ), chr(998) ) )
				// Now, we loop through the rest of the tmpSQL to build the cfqueryparams
				var listifiedSQL = listDeleteAt(LOCAL.tmpSQL,1,chr(998));
				var sqlFrags = listifiedSQL.listToArray( chr(998 ) );
				for( var frag in sqlFrags ){
					/*
						This will return the position and length of the cfsqltype
						We use this to extract the values for the actual cfqueryparam
					 */
					LOCAL.tempCFSQLType = reFindNoCase('cfsqltype\=#chr(777)#(.*?)#chr(777)#',frag,1,true);
					// A little regex to extract the value from the queryparam string
					LOCAL.value = reReplaceNoCase( PreserveSingleQuotes(frag),'.*value\=#chr(777)#(.*?)#chr(777)#.*','\1','all');
					// Strip out any loose hanging special characters used for temporary delimiters (chr(999) and chr(777))
					LOCAL.value = reReplaceNoCase(preserveSingleQuotes(LOCAL.value),chr(999),'','all');

					// We'll look for the list and null attributes to see if they exist and then extract their values
					LOCAL.tempList = reFindNoCase('list\=#chr(777)#(.*?)#chr(777)#',frag,1,true);
					if( !LOCAL.tempList.pos.len() >= 2 || !isBoolean(mid(frag,LOCAL.tempList.pos[2],LOCAL.tempList.len[2])) ){
						LOCAL.isList = false;
					}else{
						LOCAL.isList = mid(frag,LOCAL.tempList.pos[2],LOCAL.tempList.len[2]);
					}
					LOCAL.tempNull = reFindNoCase('null\=#chr(777)#(.*?)#chr(777)#',frag,1,true);
					if( !LOCAL.tempNull.pos.len() >= 2 || !isBoolean(mid(frag,LOCAL.tempNull.pos[2],LOCAL.tempNull.len[2])) ){
						LOCAL.isNull = false;
					}else{
						LOCAL.isNull = mid(frag,LOCAL.tempNull.pos[2],LOCAL.tempNull.len[2]);
					}
					LOCAL.cfSQLType = mid(frag,LOCAL.tempCFSQLType.pos[2],LOCAL.tempCFSQLType.len[2]);

					if( getUseCFQueryParams() ){
						// Now write the cfqueryparam
						paramMap.append({ cfsqltype: LOCAL.cfSQLType, value: LOCAL.value, list: LOCAL.isList, null: LOCAL.isNull });
						writeOutput( '?' );
					}else{
						writeOutput( this.getNonQueryParamFormattedValue(
												value = LOCAL.value,
												cfsqltype = LOCAL.cfSQLType,
												list = LOCAL.isList,
												null = LOCAL.isNull) );
					}

					// Now anything after the closing > should be
					if( len(listLast(preserveSingleQuotes(frag),chr(999))) ){
						writeOutput( listLast(preserveSingleQuotes(frag),chr(999)) );
					}
				}
			};

			// Execute the query
			LOCAL.result = queryExecute( execSQL, paramMap, options );

			// Grab the last inserted ID if it was an insert
			if( refindNoCase('(INSERT|REPLACE)(.*?)INTO (.*?)\(', execSQL ) ){

				if( LOCAL.result.keyExists( 'GENERATED_KEY' ) ){ // MySQL
					LOCAL.lastInsertedID = LOCAL.result.GENERATED_KEY;
				// Some versions of MSSQL call this 'GENERATEDKEY' (-sy)
				}else if( LOCAL.result.keyExists( 'GENERATEDKEY' ) ){
					LOCAL.lastInsertedID = LOCAL.result.GENERATEDKEY;
				}else if( LOCAL.result.keyExists( 'IDENTITYCOL' ) ) { // MSSQL
					LOCAL.lastInsertedID = LOCAL.result.IDENTITYCOL;
				}else if( LOCAL.result.keyExists( 'ROWID' ) ){ // Oracle
					LOCAL.lastInsertedID = LOCAL.result.ROWID;
				}else if( LOCAL.result.keyExists( 'SYB_IDENTITY' ) ){ // Sybase
					LOCAL.lastInsertedID = LOCAL.result.SYB_IDENTITY;
				}else if( LOCAL.result.keyExists( 'SERIAL_COL' ) ){ // Informix
					LOCAL.lastInsertedID = LOCAL.result.SERIAL_COL;
				}else{ // Rely on db connector cfc to provide last ID
					LOCAL.lastInsertedID = getLastID();
				}

				ret = LOCAL.lastInsertedID;

			}else{
				LOCAL.lastInsertedID = 1;
				ret = 1;
			}


			// Now write to the transaction log
			if( arguments.writeTransactionLog ){
				this.logTransaction(arguments.sql,LOCAL.lastInsertedID);
			}
		}catch( database d ){
				if( findNoCase('Invalid data',cfcatch.Message) ) {
					throw(
						errorcode="801",
						type="DAO.Execute.InvalidDataType",
						detail="Invalid Data Type",
						message="The value: &quot;#d.value#&quot; was expected to be of type: &nbsp;#listLast(d.sql_type,'_')#.  Please correct the values and try again."
					);
				}else{
					rethrow;
				}
		}catch( any e ){
				if( e.message contains "0000-00-00 00:00:00 is an invalid date or time string" ){
					throw(
						type="DAO.Execute.ZeroDateTimeException",
						message="There was an error updating the database.  In order to save '0000-00-00 00:00:00' as a date/time you must enable this behavior in your JDBC connection string by adding: ""zeroDateTimeBehavior=convertToNull"".  See: http://helpx.adobe.com/coldfusion/kb/mysql-error-java-sql-sqlexception.html for Adobe CF.",
						detail="In order to save '0000-00-00 00:00:00' as a date you must add ""zeroDateTimeBehavior=convertToNull"" to your JDBC connection string.  See: http://helpx.adobe.com/coldfusion/kb/mysql-error-java-sql-sqlexception.html for Adobe CF. Attempted Query: #renderSQLforView(sql)# :: #e.message#"
					);
				}else{
					throw(
						errorcode="802",
						type="DAO.Execute.UnexpectedError",
						detail="Unexpected Error: #renderSQLforView(sql)#:::Params:#serializeJSON(arguments.params)#",
						message="There was an unexpected error updating the database.  Please contact your administrator. #e.message# : #execSQL#"
					);
				}
				ret = 0;
		}

		return ret;
	}
	/**
	* @hint I return the sql statement with the special characters used internally replaced with print friendly characters.  Use this for displaying attempted sql in error messages.
	**/
	private string function renderSQLforView( required string sql ){

		sql = reReplace( sql, chr(999), "}", "all");
		sql = reReplace( sql, chr(998), "{", "all");
		sql = reReplace( sql, chr(777), "'", "all");
		return sql;
	}
	/**
	* @hint I read from another query (query of query). I take a sql statement as a parameter.
	**/
	public query function readFromQuery( required string sql ){
		var ret = "";

		if( len(trim(arguments.sql)) ){
			ret = queryExecute( preserveSingleQuotes(sql), {}, { dbtype:"query" } );
		}

		return ret;
	}
	/**
	* @hint I return the datatype for the given table.column..
	**/
	public string function getColumnType( required string table, required string column ){
		var def = define(arguments.table);
		var col = "";
		var ret = "";

		col = queryExecute( "
			SELECT * FROM def
			WHERE field = :column",
			{column:column},
			{ dbtype:"query" }
		);

		if( find('(',col.type) ){
			ret = listFirst(col.type,'(');
		}else{
			ret = col.type;
		}

		return ret;
	}
}