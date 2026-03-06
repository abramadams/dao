/**
 * SQLite connector tests.
 * These tests run only when the configured "dao" datasource is SQLite (dbtype="sqlite").
 * When running with MySQL or MSSQL, each test is skipped.
 */
component displayName="SQLite connector test suite" extends="testbox.system.BaseSpec" {

	function beforeTests() {
		// request.dao is set by Application.cfc onRequestStart; fallback to selected datasource
		if ( !structKeyExists( request, "dao" ) ) {
			request.dao = new com.database.dao( dsn = ( structKeyExists( application, "datasource" ) ? application.datasource : "dao_sqlite" ) );
		}
	}

	private boolean function isSqlite() {
		return structKeyExists( request, "dao" ) && request.dao.getDBtype() == "sqlite";
	}

	function createDaoWithExplicitSqliteDbtype() test {
		if ( !isSqlite() ) return;
		var dao = new com.database.dao( dsn = request.dao.getDsn(), dbtype = "sqlite" );
		$assert.isTrue( isInstanceOf( dao, "com.database.dao" ) );
		$assert.isEqual( "sqlite", dao.getDBtype() );
	}

	function connectorImplementsIDAOConnector() test {
		if ( !isSqlite() ) return;
		var conn = request.dao.getConn();
		$assert.isTrue( isInstanceOf( conn, "com.database.IDAOConnector" ) );
	}

	function getLastIDReturnsLastInsertRowId() test {
		if ( !isSqlite() ) return;
		request.dao.execute( "DELETE FROM ""test""" );
		var id = request.dao.insert( table = "test", data = { test: "getLastID check", testDate: now() } );
		$assert.isTrue( isNumeric( id ) );
		$assert.isEqual( id, request.dao.getLastID() );
	}

	function defineReturnsTableInfoFromPragma() test {
		if ( !isSqlite() ) return;
		var def = request.dao.define( "users" );
		$assert.typeOf( "query", def );
		$assert.isTrue( def.recordCount > 0 );
		$assert.isTrue( listFindNoCase( def.columnList, "name" ) );
		$assert.isTrue( listFindNoCase( def.columnList, "type" ) );
		$assert.isTrue( listFindNoCase( def.columnList, "pk" ) );
	}

	function getPrimaryKeyReturnsSinglePrimaryKey() test {
		if ( !isSqlite() ) return;
		var pk = request.dao.getPrimaryKey( "users" );
		$assert.isTrue( isStruct( pk ) );
		$assert.isTrue( structKeyExists( pk, "field" ) );
		$assert.isTrue( structKeyExists( pk, "type" ) );
		$assert.isEqual( "ID", pk.field );
	}

	function getPrimaryKeysReturnsArrayOfPrimaryKeys() test {
		if ( !isSqlite() ) return;
		var pks = request.dao.getPrimaryKeys( "users" );
		$assert.isTrue( isArray( pks ) );
		$assert.isTrue( arrayLen( pks ) >= 1 );
		$assert.isEqual( "ID", pks[ 1 ].field );
	}

	function readByTableNameReturnsQuery() test {
		if ( !isSqlite() ) return;
		var records = request.dao.read( "users" );
		$assert.typeOf( "query", records );
		$assert.isTrue( records.recordCount >= 1 );
	}

	function readByRawSQLReturnsQuery() test {
		if ( !isSqlite() ) return;
		var records = request.dao.read( "SELECT * FROM ""users"" LIMIT 2" );
		$assert.typeOf( "query", records );
		$assert.isTrue( records.recordCount <= 2 );
	}

	function readWithQueryParamReturnsQuery() test {
		if ( !isSqlite() ) return;
		var records = request.dao.read( "SELECT * FROM ""eventLog"" WHERE ID = #request.dao.queryParam( value = 1, cfsqltype = 'cf_sql_integer' )#" );
		$assert.typeOf( "query", records );
	}

	function insertReturnsNewId() test {
		if ( !isSqlite() ) return;
		request.dao.execute( "DELETE FROM ""test""" );
		var newId = request.dao.insert( table = "test", data = { test: "sqlite insert", testDate: now() } );
		$assert.isTrue( isNumeric( newId ) );
		$assert.isTrue( newId >= 1 );
		var rows = request.dao.read( "SELECT * FROM ""test"" WHERE ID = #request.dao.queryParam( value = newId, cfsqltype = 'cf_sql_integer' )#" );
		$assert.isTrue( rows.recordCount == 1 );
		$assert.isEqual( "sqlite insert", rows.test );
	}

	function updateModifiesRecord() test {
		if ( !isSqlite() ) return;
		request.dao.execute( "DELETE FROM ""test""" );
		var id = request.dao.insert( table = "test", data = { test: "original", testDate: now() } );
		request.dao.update( table = "test", data = { test: "updated", testDate: now() }, id = id );
		var rows = request.dao.read( "SELECT * FROM ""test"" WHERE ID = #request.dao.queryParam( value = id, cfsqltype = 'cf_sql_integer' )#" );
		$assert.isTrue( rows.recordCount == 1 );
		$assert.isEqual( "updated", rows.test );
	}

	function deleteRemovesRecord() test {
		if ( !isSqlite() ) return;
		var id = request.dao.insert( table = "test", data = { test: "to delete", testDate: now() } );
		request.dao.delete( table = "test", idField = "ID", recordID = id );
		var rows = request.dao.read( "SELECT * FROM ""test"" WHERE ID = #request.dao.queryParam( value = id, cfsqltype = 'cf_sql_integer' )#" );
		$assert.isTrue( rows.recordCount == 0 );
	}

	function deleteAllRemovesAllRecords() test {
		if ( !isSqlite() ) return;
		request.dao.execute( "DELETE FROM ""test""" );
		request.dao.insert( table = "test", data = { test: "one", testDate: now() } );
		request.dao.insert( table = "test", data = { test: "two", testDate: now() } );
		request.dao.delete( table = "test", recordID = "*" );
		var rows = request.dao.read( "test" );
		$assert.isTrue( rows.recordCount == 0 );
	}

	function makeTableCreatesTable() test {
		if ( !isSqlite() ) return;
		var tableName = "test_sqlite_make_table";
		var tabledef = new com.database.tabledef( dsn = request.dao.getDsn(), tableName = tableName );
		tabledef.addColumn( column = "id", type = "numeric", isPrimaryKey = true, generator = "increment" );
		tabledef.addColumn( column = "name", type = "string", length = "100" );
		request.dao.getConn().dropTable( tableName );
		request.dao.getConn().makeTable( tabledef );
		var def = request.dao.define( tableName );
		$assert.isTrue( def.recordCount >= 2 );
		request.dao.getConn().dropTable( tableName );
	}

	function dropTableRemovesTable() test {
		if ( !isSqlite() ) return;
		request.dao.execute( 'CREATE TABLE IF NOT EXISTS "drop_me" ("id" INTEGER PRIMARY KEY, "x" TEXT)' );
		request.dao.getConn().dropTable( "drop_me" );
		var def = request.dao.define( "drop_me" );
		$assert.isTrue( def.recordCount == 0, "Table should not exist after drop; define() should return empty result." );
	}

	function getSafeColumnNameWrapsWithDoubleQuotes() test {
		if ( !isSqlite() ) return;
		var conn = request.dao.getConn();
		$assert.isEqual( '"colname"', conn.getSafeColumnName( "colname" ) );
		$assert.isEqual( '"ID"', conn.getSafeColumnName( "ID" ) );
	}

	function getSafeIdentifierCharsAreDoubleQuotes() test {
		if ( !isSqlite() ) return;
		var conn = request.dao.getConn();
		$assert.isEqual( '"', conn.getSafeIdentifierStartChar() );
		$assert.isEqual( '"', conn.getSafeIdentifierEndChar() );
	}

	function pageTableResultsWithLimitAndOffset() test {
		if ( !isSqlite() ) return;
		var paged = request.dao.read( table = "eventLog", offset = 0, limit = 3 );
		$assert.isTrue( paged.recordCount <= 3 );
		$assert.isTrue( structKeyExists( paged, "__fullCount" ) || structKeyExists( paged, "__count" ) );
	}

	function bulkInsertArray() test {
		if ( !isSqlite() ) return;
		request.dao.execute( "DELETE FROM ""test""" );
		var data = [];
		for ( var i = 1; i <= 5; i++ ) {
			data.append( { test: "bulk #i#", testDate: now() } );
		}
		var ids = request.dao.insert( table = "test", data = data );
		$assert.isTrue( isArray( ids ) );
		$assert.isEqual( 5, arrayLen( ids ) );
		var rows = request.dao.read( "test" );
		$assert.isTrue( rows.recordCount >= 5 );
	}

	function afterTests() {
		// optional cleanup
	}

}
