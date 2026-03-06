/**
************************************************************
*
*	Copyright (c) 2007-2026, Abram Adams
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
*		Component	: sqlite.cfc (SQLite Specific)
*		Author		: Abram Adams
*		Date		: 3/6/2025
*		@version 1.0.0
*   	@dependencies { "dao" : ">=1.0.0" }
*		Description	: Targeted database access object that will
*		control all SQLite specific database interaction.
*		This component will use SQLite syntax to perform general
*		database functions.
***********************************************************/
component output="false" accessors="true" implements="IDAOConnector" {

	property name="dao" type="dao";
	property name="dsn" type="string";
	property name="useCFQueryParams" type="boolean";

	public any function init(
		required dao dao,
		required string dsn,
		string user = "",
		string password = "",
		boolean useCFQueryParams = true
	) {
		setDsn( arguments.dsn );
		setDao( arguments.dao );
		setUseCFQueryParams( arguments.useCFQueryParams );
		return this;
	}

	public any function getLastID() {
		var __get = queryExecute(
			"SELECT last_insert_rowid() AS thekey",
			[],
			{ datasource: getDsn() }
		);
		return __get.thekey;
	}

	public boolean function delete(
		required string tableName,
		required string recordID,
		string idField = ""
	) {
		var pk = getPrimaryKey( arguments.tableName );
		var whereCol = len( trim( arguments.idField ) ) ? arguments.idField : pk.field;
		var sql = "DELETE FROM #getSafeColumnName( arguments.tableName )# WHERE #getSafeColumnName( whereCol )# = ?";
		var params = [ { cfsqltype: getDAO().getCFSQLType( pk.type ), value: arguments.recordID } ];
		queryExecute( sql, params, { datasource: getDsn() } );
		return true;
	}

	public boolean function deleteAll( required string tableName ) {
		var sql = "DELETE FROM #getSafeColumnName( arguments.tableName )#";
		queryExecute( sql, [], { datasource: getDsn() } );
		return true;
	}

	public query function select(
		string sql = "",
		string name = "sel_#listFirst( createUUID(), '-' )#",
		any cachedWithin = "",
		string table = "",
		string alias = "",
		string columns = "",
		string where = "",
		any limit = "",
		any offset = "",
		string orderBy = ""
	) {
		var __get = "";
		var tmpSQL = "";
		var idx = 1;
		var count = "";
		var options = {};
		var paramMap = [];
		var sqlStr = "";

		if ( listLen( arguments.sql, " " ) == 1 && !len( trim( arguments.table ) ) ) {
			arguments.table = arguments.sql;
		}

		try {
			if ( listLen( arguments.sql, " " ) > 1 ) {
				// Arbitrary SQL
				tmpSQL = getDao().parameterizeSQL( arguments.sql );
				sqlStr = _buildParameterizedSql( tmpSQL, paramMap );
				options = { datasource: getDsn() };
				if ( len( trim( arguments.cachedWithin ) ) ) options.cachedWithin = arguments.cachedWithin;
				__get = queryExecute( sqlStr, paramMap, options );

				if ( len( trim( limit ) ) && len( trim( offset ) ) ) {
					__get = getDao().pageRecords( __get, offset, limit );
				}
			} else {
				// Table select
				if ( !len( trim( arguments.columns ) ) ) {
					arguments.columns = getSafeColumnNames( getDao().getColumns( arguments.table ) );
				}

				sqlStr = "SELECT #arrayToList( listToArray( trim( arguments.columns ) ) )# FROM #getSafeColumnName( arguments.table )# #arguments.alias#";
				paramMap = [];

				if ( len( trim( arguments.where ) ) ) {
					tmpSQL = getDao().parameterizeSQL( arguments.where );
					sqlStr &= " " & _buildParameterizedSql( tmpSQL, paramMap );
				}
				if ( len( trim( arguments.orderBy ) ) ) {
					sqlStr &= " ORDER BY #arguments.orderBy#";
				}
				if ( len( trim( arguments.limit ) ) && isNumeric( arguments.limit ) ) {
					sqlStr &= " LIMIT ? OFFSET ?";
					paramMap.append( { cfsqltype: "cf_sql_integer", value: val( arguments.limit ) } );
					paramMap.append( { cfsqltype: "cf_sql_integer", value: val( arguments.offset ) } );
				}

				options = { datasource: getDsn() };
				if ( len( trim( arguments.cachedWithin ) ) ) options.cachedWithin = arguments.cachedWithin;
				__get = queryExecute( sqlStr, paramMap, options );

				if ( len( trim( arguments.limit ) ) > 0 && isNumeric( arguments.limit ) ) {
					var countSql = "SELECT COUNT(*) AS found_rows FROM #getSafeColumnName( arguments.table )# #arguments.alias#";
					var countParams = [];
					if ( len( trim( arguments.where ) ) ) {
						tmpSQL = getDao().parameterizeSQL( arguments.where );
						countSql &= " " & _buildParameterizedSql( tmpSQL, countParams );
					}
					var countOptions = { datasource: getDsn() };
					if ( len( trim( arguments.cachedWithin ) ) ) countOptions.cachedWithin = arguments.cachedWithin;
					count = queryExecute( countSql, countParams, countOptions );
					__get = queryExecute(
						"SELECT '#count.found_rows#' AS __count, '#count.found_rows#' AS __fullCount, * FROM __get",
						[],
						{ dbtype: "query", __get: __get }
					);
				}
			}

			return __get;
		} catch ( any e ) {
			if ( findNoCase( "no such column", e.detail ) || findNoCase( "Unknown column", e.detail ) ) {
				throw(
					type: "DAO.Read.SQLite.UnknownColumn",
					detail: e.detail,
					message: "#e.message# #len( trim( arguments.columns ) ) ? '- Available columns are: #arguments.columns#' : ''#"
				);
			}
			throw( type: "DAO.Read.SQLite.SelectException", detail: e.detail, message: e.message );
		}
	}

	private string function _buildParameterizedSql( required any tmpSQL, required array paramMap ) {
		var sqlStr = "";
		for ( var st in arguments.tmpSQL.statements ) {
			sqlStr &= preserveSingleQuotes( st.before );
			if ( structKeyExists( st, "cfsqltype" ) ) {
				var p = { cfsqltype: st.cfSQLType, value: st.value, list: st.isList };
				if ( structKeyExists( st, "null" ) ) p.null = st.null;
				paramMap.append( p );
				sqlStr &= "?";
			}
		}
		return sqlStr;
	}

	public any function write(
		required tabledef tabledef,
		boolean insertPrimaryKeys = false,
		boolean bulkInsert = false
	) {
		var curRow = 0;
		var columns = "";
		var ins = "";
		var isnull = "";
		var cfsqltype = "cf_sql_varchar";
		var tablename = tabledef.getTableName();
		var col = "";
		var ret = [];
		var qry = arguments.tabledef.getRows();

		if ( !arguments.insertPrimaryKeys ) {
			columns = arguments.tabledef.getNonAutoIncrementColumns();
		} else {
			columns = arguments.tabledef.getColumns();
		}
		if ( !qry.recordCount ) {
			throw( message: "No data to insert" );
		}

		ins = "";
		for ( var row in qry ) {
			if ( qry.currentRow == 1 || !arguments.bulkInsert ) {
				ins &= "INSERT INTO #getSafeColumnName( tablename )# (#getSafeColumnNames( columns )#) VALUES";
			}
			ins &= "(";
			curRow = 0;

			for ( col in listToArray( columns ) ) {
				isnull = "false";
				curRow++;
				var defaultValue = tabledef.getColumnDefaultValue( col );
				cfsqltype = tabledef.getCFSQLType( col );
				if ( cfsqltype == "cf_sql_date" && isDate( row[ col ] ) ) {
					cfsqltype = "cf_sql_timestamp";
				}
				if ( !len( trim( row[ col ] ) ) ) {
					if ( len( trim( defaultValue ) ) ) {
						row[ col ] = defaultValue;
					} else {
						row[ col ] = tabledef.getColumnNullValue( col );
						isnull = "true";
					}
				}
				if ( !tabledef.isColumnNullable( col ) ) {
					isnull = "false";
					if ( cfsqltype contains "date" || cfsqltype contains "time" ) {
						if ( row[ col ] == "CURRENT_TIMESTAMP" ) {
							row[ col ] = "";
						} else if ( row[ col ] == "0000-00-00 00:00:00" ) {
							row[ col ] = createTime( 0, 0, 0 );
						}
					}
				}
				if ( curRow > 1 ) ins &= ",";
				if ( !len( trim( row[ col ] ) ) ) {
					row[ col ] = tabledef.getColumnNullValue( row[ col ] );
					if ( cfsqltype != "cf_sql_boolean" && !len( trim( defaultValue ) ) ) {
						isnull = "true";
					}
				}

				ins &= getDao().queryParam( value: row[ col ], cfsqltype: cfsqltype, list: "false", null: isnull );
				cfsqltype = "bad";
			}
			ins &= ")";
			if ( qry.recordCount > qry.currentRow ) {
				if ( !arguments.bulkInsert ) {
					ins &= chr( 789 );
				} else {
					ins &= ",";
				}
			}
		}

		if ( !arguments.bulkInsert ) {
			var statements = listLen( ins, chr( 789 ) );
			for ( var i = 1; i <= statements; i++ ) {
				ret.append( getDao().execute( listGetAt( ins, i, chr( 789 ) ) ) );
			}
		} else {
			ret.append( getDao().execute( ins ) );
		}

		return ret.len() > 1 ? ret : ret[ 1 ];
	}

	public any function update(
		required any tabledef,
		string columns = "",
		required string idField
	) {
		var qry = arguments.tabledef.getRows();
		var pk = arguments.idField;
		var ret = true;
		var value = "";
		var isnull = "false";
		var upd = "";
		var col = "";
		var cfsqltype = "";
		var tableName = arguments.tabledef.getTableName();
		var performUpdate = false;

		if ( !len( trim( arguments.columns ) ) ) {
			arguments.columns = arguments.tabledef.getColumns();
		}

		try {
			for ( var i = 1; i <= qry.recordCount; i++ ) {
				performUpdate = false;
				upd = "UPDATE #getSafeColumnName( tableName )# SET ";
				var curRow = 0;

				for ( col in listToArray( arguments.columns ) ) {
					if ( col != pk && arguments.tabledef.getColumnIsDirty( col ) ) {
						performUpdate = true;
						isnull = false;
						curRow++;

						value = qry[ col ][ i ];
						cfsqltype = arguments.tabledef.getCFSQLType( col );
						if ( cfsqltype == "cf_sql_double" && len( listLast( value ) ) == 2 ) {
							value = lsParseNumber( value );
						}
						if ( !len( trim( value ) ) ) {
							if ( cfsqltype != "cf_sql_boolean" ) isnull = true;
							value = arguments.tabledef.getColumnNullValue( col );
							if ( !arguments.tabledef.isColumnNullable( col ) ) isnull = "false";
							if ( cfsqltype == "cf_sql_timestamp" ) isnull = true;
						}
						if ( ( cfsqltype contains "date" || cfsqltype contains "time" ) && ( value == "0000-00-00 00:00:00" || value == "CURRENT_TIMESTAMP" ) ) {
							isnull = true;
							if ( value == "CURRENT_TIMESTAMP" ) value = "";
						}
						if ( curRow > 1 ) upd &= ", ";
						upd &= "#getSafeColumnName( col )# = #getDao().queryParam( value: value, cfsqltype: cfsqltype, list: 'false', null: isnull )#";
						value = "";
						cfsqltype = "";
					}
				}

				upd &= " WHERE #getSafeColumnName( pk )# = #getDao().queryParam( qry[ pk ][ i ] )#";
				ret = qry[ pk ][ i ];

				if ( performUpdate ) {
					getDao().execute( upd );
				}
			}
		} catch ( any e ) {
			throw(
				errorcode: "803-sqlite.update",
				type: "dao.custom.error",
				detail: "Unexpected Error #e.detail#",
				message: "There was an unexpected error updating the database.  Please contact your administrator. #e.message#"
			);
		}

		return ret;
	}

	public any function define( required string tableName ) {
		var def = queryExecute(
			"PRAGMA table_info(#getSafeColumnName( arguments.tableName )#)",
			[],
			{ datasource: getDsn() }
		);
		return def;
	}

	public struct function getPrimaryKey( required string tableName ) {
		var def = define( arguments.tableName );
		var ret = {};
		var __get = queryExecute(
			"SELECT name AS field, type FROM def WHERE pk = 1",
			[],
			{ dbtype: "query", maxrows: 1, def: def }
		);
		if ( __get.recordCount == 0 ) {
			throw( type: "DAO.SQLite.NoPrimaryKey", message: "Table #arguments.tableName# has no primary key defined." );
		}
		ret.field = __get.field;
		ret.type = getDAO().getCFSQLType( listFirst( __get.type, "(" ) );
		return ret;
	}

	public array function getPrimaryKeys( required string tableName ) {
		var def = define( arguments.tableName );
		var ret = [];
		var __get = queryExecute(
			"SELECT name AS field, type FROM def WHERE pk = 1",
			[],
			{ dbtype: "query", def: def }
		);
		for ( var i = 1; i <= __get.recordCount; i++ ) {
			var row = queryGetRow( __get, i );
			ret.append( {
				field: row.field,
				type: getDAO().getCFSQLType( listFirst( row.type, "(" ) )
			} );
		}
		return ret;
	}

	public string function getSafeColumnNames( required string cols ) {
		var columns = [];
		for ( var colName in listToArray( arguments.cols ) ) {
			var col = "#getSafeIdentifierStartChar()##trim( colName )##getSafeIdentifierEndChar()#";
			col = reReplace( col, "\.", "#getSafeIdentifierStartChar()#.#getSafeIdentifierEndChar()#", "all" );
			col = reReplace( col, "#getSafeIdentifierStartChar()#\*#getSafeIdentifierEndChar()#", "*", "all" );
			columns.append( col );
		}
		return arrayToList( columns );
	}

	public string function getSafeColumnName( required string col ) {
		return "#getSafeIdentifierStartChar()##trim( arguments.col )##getSafeIdentifierEndChar()#";
	}

	public string function getSafeIdentifierStartChar() {
		return '"';
	}

	public string function getSafeIdentifierEndChar() {
		return '"';
	}

	public tabledef function makeTable( required tabledef tabledef ) {
		var tableSQL = "CREATE TABLE IF NOT EXISTS " & getSafeIdentifierStartChar() & tabledef.getTableName() & getSafeIdentifierEndChar() & " (";
		var columnsSQL = "";
		var primaryKeys = "";
		var tmpstr = "";
		var col = {};
		var q = getSafeIdentifierStartChar();
		var qq = getSafeIdentifierEndChar();

		for ( var colName in tabledef.getTableMeta().columns ) {
			col = duplicate( tabledef.getTableMeta().columns[ colName ] );
			col.name = colName;

			switch ( col.sqltype ) {
				case "string":
					tmpstr = q & col.name & qq & " TEXT " & ( ( col.isPrimaryKey || col.isIndex ) ? "NOT" : "" ) & " NULL " & ( structKeyExists( col, "default" ) ? "DEFAULT '" & col.default & "'" : "" );
					break;
				case "numeric":
					tmpstr = q & col.name & qq & " INTEGER " & ( structKeyExists( col, "generator" ) && col.generator == "increment" ? "PRIMARY KEY AUTOINCREMENT" : ( col.isPrimaryKey ? "PRIMARY KEY" : "" ) ) & " " & ( ( col.isPrimaryKey || col.isIndex ) ? "NOT" : "" ) & " NULL " & ( structKeyExists( col, "default" ) ? "DEFAULT '" & col.default & "'" : "" );
					break;
				case "date":
				case "datetime":
				case "timestamp":
					tmpstr = q & col.name & qq & " TEXT " & ( ( col.isPrimaryKey || col.isIndex ) ? "NOT" : "" ) & " NULL " & ( structKeyExists( col, "default" ) ? "DEFAULT '" & col.default & "'" : "" );
					break;
				case "tinyint":
					tmpstr = q & col.name & qq & " INTEGER " & ( structKeyExists( col, "generator" ) && col.generator == "increment" ? "PRIMARY KEY AUTOINCREMENT" : "" ) & " " & ( ( col.isPrimaryKey || col.isIndex ) ? "NOT" : "" ) & " NULL " & ( structKeyExists( col, "default" ) ? "DEFAULT " & ( col.default ? 1 : 0 ) : "" );
					break;
				case "boolean":
				case "bit":
					tmpstr = q & col.name & qq & " INTEGER " & ( ( col.isPrimaryKey || col.isIndex ) ? "NOT" : "" ) & " NULL " & ( structKeyExists( col, "default" ) ? "DEFAULT " & ( col.default ? 1 : 0 ) : "" );
					break;
				case "text":
					tmpstr = q & col.name & qq & " TEXT " & ( ( col.isPrimaryKey || col.isIndex ) ? "NOT" : "" ) & " NULL " & ( structKeyExists( col, "default" ) ? "DEFAULT '" & col.default & "'" : "" );
					break;
				default:
					tmpstr = q & col.name & qq & " " & listFirst( col.sqltype, " " ) & ( structKeyExists( col, "length" ) ? "(" & col.length & ")" : "" ) & " " & ( ( col.isPrimaryKey || col.isIndex ) ? "NOT" : "" ) & " NULL " & ( structKeyExists( col, "default" ) ? "DEFAULT '" & col.default & "'" : "" );
					break;
			}

			if ( structKeyExists( col, "generator" ) && col.generator == "increment" ) {
				columnsSQL = listPrepend( columnsSQL, tmpstr );
			} else {
				columnsSQL = listAppend( columnsSQL, tmpstr );
			}

			if ( col.isPrimaryKey && !( structKeyExists( col, "generator" ) && col.generator == "increment" ) ) {
				primaryKeys = listAppend( primaryKeys, q & col.name & qq );
			}
		}

		tableSQL &= columnsSQL;
		if ( listLen( primaryKeys ) ) {
			tableSQL &= ", PRIMARY KEY (#primaryKeys#)";
		}
		tableSQL &= ")";

		getDao().execute( tableSQL );
		return tabledef;
	}

	public void function dropTable( required string table ) {
		getDao().execute( "DROP TABLE IF EXISTS " & getSafeIdentifierStartChar() & arguments.table & getSafeIdentifierEndChar() );
	}

}
