<!---
************************************************************
*
*	Copyright (c) 2007-2015, Abram Adams
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
		Component	: tabledef.cfc
		Author		: Abram Adams
		Date		: 1/2/2007
	  	@version 0.0.66
	   	@updated 9/10/2015
		Description	: Creates an instance of the tabledef object that
		is used in various dao functions, like bulkInsert().  The
		tabledef object represents a copy of an actual db table with the
		records that are to be inserted, or updated.  This object is then
		passed to a dao function and parsed accordingly.

		EXAMPLES:
			////////////////////////////////////////////////////////////////
			//This example is a form handler in which the form field names
			//correspond to each of the columns in the destination table.
			////////////////////////////////////////////////////////////////

			//create empty tabledef object based on the table "Users"
			table = createObject('component','tabledef').init(tablename="Users",
																					dsn=application.constants.DSN);

			//add a single, blank row to be populated
			row = table.addRow();

			//loop through all the non-primary key fields in the table
			for (i=1;i LTE listLen(table.getNonPrimaryKeyColumns());i = i + 1){
				//grab the current column name (only non-primary keys)
				col = listGetAt(table.getNonPrimaryKeyColumns(),i);

				//insert the value of the form field with the same
				//name as the column into the table object
				table.setColumn(column=col,value=form[col],row=row);
			}

			// pass the table object (with 1 record) to the write function
			// this will write all records in the "table" object to the
			newRecord = application.dao.write(table);

			////////////////////////////////////////////////////////////////
			// an update would be very similar:
			////////////////////////////////////////////////////////////////

			//create empty tabledef object based on the table "Users"
			table = createObject('component','tabledef').init(tablename="Users",
																					dsn=application.constants.DSN);

			//add a single, blank row to be populated
			row = table.addRow();

			for (i=1;i LTE listLen(table.getColumns());i = i + 1){
				//grab the current column name.  This time we are using the getColumns() function
				//that returns all columns (including primary keys)
				col = listGetAt(table.getColumns(),i);
				//insert the value of the form field with the same
				//name as the column into the table object
				table.setColumn(column=col,value=form[col],row=row);
			}
			//update it
			updateRecord = application.dao.update(table);

	  ********************************************************** --->

<cfcomponent hint="Instantiates a single table definition" output="false" accessors="true">
	<cfproperty name="dsn" type="string">
	<cfproperty name="tableName" type="string">
	<cfproperty name="isTable" type="boolean">
	<cfscript>

	public tabledef function init( required string tablename, required string dsn, boolean loadMeta = true ){
		this.instance = {
				table = queryNew( '' ),
				name = reReplaceNoCase( arguments.tablename, '[^a-z0-9]', '', 'all' ),
				tabledef = {},
				tablemeta.columns = {}
		};

		setTableName( arguments.tablename );

		setDSN( arguments.dsn );

		/* grab the table metadata, unless told not to */
		if( loadMeta ){
			setIsTable( loadTableMetaData() );
		}

		return this;
	}

	public function addColumn( required string column,
							   required string type,
							   string sqlType = arguments.type,
							   string length = "",
							   boolean isPrimaryKey = false,
							   string generator = "",
							   boolean isIndex = false,
							   boolean isNullable = true,
							   string defaultValue = "",
							   string comment = "",
							   boolean isDirty = false ){


			var arrPadding = [];
			if( structKeyExists( this.instance.table, arguments.column ) ){
				return;
			}
			// need to make serializable
			// Store Column Definition in structure for later use
			this.instance.tablemeta.columns[ arguments.column ] = {
				sqltype = arguments.type,
				type = getValidDataType( arguments.type ),
				length = arguments.length,
				isIndex = arguments.isIndex,
				isPrimaryKey = arguments.isPrimaryKey,
				isNullable = arguments.isNullable,
				defaultValue = arguments.defaultValue,
				generator = arguments.generator,
				comment = arguments.comment,
				isDirty = arguments.isDirty
			};

			QueryAddColumn( this.instance.table, arguments.column, getDummyType( arguments.type ), arrPadding );
	}

	public function setColumn( required string column, required any value, required numeric row ){
		return querySetCell( this.instance.table, arguments.column, arguments.value, arguments.row );
	}

	public function setColumnComment( required string column, required any comment ){
		this.instance.tablemeta.columns[ arguments.column ].comment = arguments.comment;
	}

	public function setColumnIsDirty( required string column, required boolean isDirty ){
		this.instance.tablemeta.columns[ arguments.column ].isDirty = arguments.isDirty;
	}

	public function setColumnPrimaryKeyGenerator( required string column, required string generator ){
		this.instance.tablemeta.columns[ arguments.column ].generator = arguments.generator;
	}
	/**
	* @hint I add a blank row to the tabledef object and return the new row count.
	**/
	public numeric function addRow(){
		var ret = queryAddRow( this.instance.table );
		return getRowCount();
	}

	//	GETTERS
	public string function getColumns( string exclude = "", string prefix ="" ){
		var columns = this.instance.table.columnlist;
		if( len( trim( exclude ) ) ){
			arguments.exclude = listToArray( arguments.exclude );
			for( var excludeCol in arguments.exclude ){
				if( listFindNoCase( columns, excludeCol ) ){
					columns = listDeleteAt( columns, listFindNoCase( columns, excludeCol ) );
				}
			}
		}

		var prefixedColumnList = columns;
		if( len( trim( prefix ) ) ){
			prefixedColumnList = "#prefix#." & listChangeDelims( prefixedColumnList, ",#prefix#.", ',' );
		}
		return prefixedColumnList;
	}

	public struct function getColumnDefs( string exclude = "", string prefix ="" ){
		return this.instance.tablemeta.columns;
	}

	public boolean function hasColumn( required string column ){
		return structKeyExists( this.instance.tablemeta.columns, column );
	}

	public query function getRows(){
		return this.instance.table;
	}

	public struct function getRow( rowNumber ){
		return queryGetRow( this.instance.table, rowNumber );
	}

	public numeric function getRowCount(){
		return this.instance.table.recordcount;
	}

	public string function getValidDataType( required string type ){
		if( arguments.type is "datetime" ){
			arguments.type = "timestamp";
		}
		if( findNoCase( "int", arguments.type ) ){
			arguments.type = "INTEGER";
		}
		if( findNoCase( "money", arguments.type ) ){
			arguments.type = "DECIMAL";
		}
		if( findNoCase( "text", arguments.type ) || arguments.type is "string" || findNoCase( "varchar", arguments.type ) ){
			arguments.type = "VARCHAR";
		}
		try{
			var cfsqltype = jdbcType( typeid = arguments.type );
		}catch (any e){
			writeDump(e);
			writeDump(arguments);abort;
		}

		return cfsqltype;
	}

	public function getDummyType( required string type ){
		var dummyType = "Varchar";
		switch ( type ){
			// Integer | BigInt | Double | Decimal | VarChar | Binary | Bit | Time | Date]
			case 4: case 5: case "-6":
				dummyType = "Integer";
				break;
			case 93:
				dummyType = "Date";
				break;
			case 12: case "-4": case "-1": case 1:
				dummyType = "VarChar";
				break;
			case "-7":
				dummyType = "Bit";
				break;
			case 8:
				dummyType = "Double";
				break;
			case 2:
				dummyType = "Decimal";
				break;
			default:
				dummyType = "VarChar";
				break;
		}

		return dummyType;
	}
	/**
	* @hint I return the given column's data type
	**/
	public function getColumnType( required string column ){
		var type = "varchar";

		if( structKeyExists( this.instance.tablemeta.columns, arguments.column ) ){
			type = this.instance.tablemeta.columns[ arguments.column ].type;
		}

		return type;
	}

	/**
	* @hint I return a null value based on the passed column's type.
	**/
	public string function getColumnNullValue( required string column ){
		var ret = getColumnDefaultValue( arguments.column );
		if( !len( trim( ret ) ) ){
			switch ( lcase( getDummyType( getColumnType( arguments.column ) ) ) ){
				case "date":
					ret = "0000-00-00 00:00";
					break;

				case "double": case "decimal":
					ret = "0.00";
					break;
				case "bit":
					ret = "NULL";
					break;
				case "integer": case "tinyint": case "int": case "boolean":
					ret = "0";
					break;
				case "varchar":
					ret = "";
					break;
				default:
					ret = "";
					break;
			}
		}

		return ret;
	}

	public function getCFSQLType( required string col ){
		var cfsqltype = "";
		cfsqltype = jdbcType( typeid = getColumnType( arguments.col ) );

		if( cfsqltype is "datetime" ){
			cfsqltype = "timestamp";
		}
		return "cf_sql_" & cfsqltype;

	}

	public numeric function getColumnLength( required string column ){
		return this.instance.tablemeta.columns[arguments.column].length;
	}

	public boolean function getColumnIsDirty( required string column ){
		return this.instance.tablemeta.columns[arguments.column].isDirty;
	}

	public string function getColumnDefaultValue( required string column ){
		var ret = "";
		if( structKeyExists( this.instance.tablemeta.columns, arguments.column ) ){
			ret = reReplaceNoCase( this.instance.tablemeta.columns[arguments.column].defaultValue, '\(\((.*?)\)\)','\1', 'all' );;
		}
		if( ret == "(getdate())" ){
			ret = now();
		}
		return ret;
	}

	public boolean function isColumnIndex( required string column ){
		return this.instance.tablemeta.columns[arguments.column].isIndex;
	}

	public boolean function isColumnNullable( required string column ){
		if( structKeyExists( this.instance.tablemeta.columns,arguments.column ) ){
			return this.instance.tablemeta.columns[arguments.column].isNullable;
		}

		return true;
	}

	public struct function getTableMeta(){
		return this.instance.tablemeta;
	}

	public struct function getTable(){
		return this.instance.table;
	}

	public string function getNonPrimaryKeyColumns(){
		var nokeys = [];
		for ( var col in this.instance.tablemeta.columns ){
			if( this.instance.tablemeta.columns[col].isPrimaryKey != "YES" ){
				arrayAppend( noKeys, col );
			}
		}

		return arrayToList( nokeys );
	}

	public string function getNonAutoIncrementColumns(){
		var nokeys = [];

		// at least in mssql 2008, the SQLTYPE column contains 'int identity',
		//  but generator is not consistent  (-sy)
		for ( var col in this.instance.tablemeta.columns ){
			if( !len( trim( this.instance.tablemeta.columns[col].generator ) ) || this.instance.tablemeta.columns[col].generator == "uuid" ){
				if ( !findNoCase( 'identity', this.instance.tablemeta.columns[ col ].sqltype ) ){
					arrayAppend( noKeys, col );
				}
			}
		}

		return arrayToList( nokeys );
	}

	public string function getIndexColumns(){
		var keys = [];
		for ( var col in this.instance.tablemeta.columns ){
			if( this.instance.tablemeta.columns[col].isIndex == true ){
				arrayAppend( Keys, col );
			}
		}

		return arrayToList( keys );
	}

	public string function getPrimaryKeyColumns(){
		var keys = [];
		for ( var col in this.instance.tablemeta.columns ){
			if( this.instance.tablemeta.columns[col].isPrimaryKey == true ){
				arrayAppend( Keys, col );
			}
		}

		return arrayToList( keys );
	}

	public string function getPrimaryKeyColumn(){
		var keys = [];
		for ( var col in this.instance.tablemeta.columns ){
			if( this.instance.tablemeta.columns[col].isPrimaryKey == true ){
				return col;
			}
		}

		// If we make it here, there is no primary key.  Return the first column.
		var indexes = listFirst( getIndexColumns() );
		var columns = listLen( indexes ) ? indexes : getColumns();
		return listFirst( columns );
	}

	/**
	* @hint Returns the name or number for a given Java JDBC data type
	**/
	private string function jdbcType( required string typeId ){
		var sqltype = createObject( "java", "java.sql.Types" );
		var types = {};
		// forces java.sql.Types into a CF friendly struct ( required by Railo 4.2 to allow for-in loop )
		sqltype = deserializeJSON( serializeJSON( sqltype ) );
		for( var x in sqltype ){
			types[ x ] = sqltype[ x ];
			types[ sqltype[ x ] ] = x;
		}
		if( left( arguments.typeID, 3 ) is "INT" ){
			arguments.typeID = "integer";
		}else if( left( arguments.typeID, 7 ) is "VARCHAR"){
			arguments.typeID = "varchar";
		}
		if( structKeyExists(types, arguments.typeID) && types[arguments.typeId] is "timestamp" ){
			types[ arguments.typeId ] = "datetime";
		}

		return types[ arguments.typeId ];
	}

	</cfscript>

<!--- PRIVATE FUNCTIONS --->
	<cffunction name="loadTableMetaData" output="false" access="public" returntype="boolean" hint="I load the metadata for the table.">
		<cfscript>
			var indexqry = "";
			var primarykeys = "";
			var primarykeynamelist = "";
			var nonprimarykeys = "";
			var arrcomments = [];
			var columnname = "";
			var columntype = "";
			var fieldsize = "";
			var isnullable = "";
			var isPrimary = "";
			var isIndex = "";
			var defaultvalue = "";
			var comment = "";
			var generator = "";
			var LOCAL = {};

			if( !len( trim( getTableName() ) ) ){
				return false;
			}

			// get the columns for the table for any schema
			// auto-detect the database type.
			if ( isDefined( 'server' ) && ( structKeyExists( server, 'railo' ) || structKeyExists( server, 'lucee' ) ) ){
				// railo does things a bit different with dbinfo.
				var railoHacks = new railoHacks( this.getDsn() );
				// See if the table exists, if not return false;
				var tables = railoHacks.getTables( pattern = this.getTableName() );
				if( !tables.recordCount ){
					return false;
				}
				// In case the table name is case sensitive we'll make sure we set it to what dbinfo says it is
				setTableName( tables.table_name );
				// We pull in railo's version of dbinfo call so ACF doesn't choke on it.
				var columns = railoHacks.getColumns( table = this.getTableName() );
				var indexqryfull = railoHacks.getColumns( table = this.getTableName() );

			}else{
				var d = new dbinfo( datasource = this.getDsn() );
				// NOTE: In CF11 the "pattern" argument is now case sensitive, so we can no longer do:
				// var tables = d.tables( pattern = this.getTableName() );
				// Rather, whe have to do all this crap:
				var tables = d.tables();
				var qry = new Query();
				qry.addParam( name = "tableName", value = lcase( this.getTableName() ), cfsqltype = "cf_sql_varchar" );
				qry.setAttributes( tableQuery = tables );
				var tablesFiltered = qry.execute(
					sql = "SELECT * FROM tableQuery WHERE LOWER(table_name) = :tableName",
					dbtype = "query"
				).getResult();

				if( !tablesFiltered.recordCount ){
					return false;
				}
				// In case the table name is case sensitive we'll make sure we set it to what dbinfo says it is
				setTableName( tablesFiltered.table_name );
				var columns = d.columns( table = this.getTableName() );
				// get a full indexes query for the table
				var indexqryfull = d.index( table = this.getTableName() );
			}
		</cfscript>

		<cfquery name="primaryKeylist" dbtype="query">
			SELECT * FROM columns
			WHERE is_primarykey = 'YES'
			OR type_name LIKE '% identity'
		</cfquery>

		<!--- strip the statistics index (type = 0) --->
		<cfquery dbtype="query" name="LOCAL.indexqry_#this.instance.name#" cachedwithin="#createTimeSpan(0,1,0,0)#">
			SELECT  *
			FROM  indexqryfull
		</cfquery>


		<cfset indexqry = LOCAL['indexqry_' & this.instance.name]/>

		<cfset primarykeys = primaryKeylist/>

		<!--- convert the return query to a list of column names for the primary keys --->
		<cfset primarykeynamelist = ValueList(primarykeys.column_name)/>

		<!--- get the non primary keys --->
		<cfquery dbtype="query" name="LOCAL.nonprimarykeys_#this.instance.name#" cachedwithin="#createTimeSpan(0,1,0,0)#">
			SELECT * FROM columns
			WHERE is_primarykey = 'no'
		</cfquery>
		<!---<cfset nonprimarykeys = evaluate('nonprimarykeys_' & this.instance.name)>--->
		<cfset nonprimarykeys = LOCAL['nonprimarykeys_' & this.instance.name]/>

		<!--- This adds the comment column to the table that can be populated later --->
		<cfset QueryAddColumn(columns,'comment',arrcomments)/>

		<!--- loop through all columns and add a field object for each one --->
		<cfoutput query="columns">
			<cfset columnname = columns.column_name>
			<cfset columntype = columns.TYPE_NAME>
			<cfset fieldsize = columns.column_size>
			<cfset isnullable = columns.is_nullable EQ 1>
			<cfset isPrimary = listfindnocase(primarykeynamelist,columnname,",") GT 0>
			<cfset isIndex = listFindNoCase(valueList(indexqry.COLUMN_NAME),columnname) GT 0>
			<cfset defaultvalue = columns.COLUMN_DEFAULT_VALUE>
			<cfset comment = columns.comment>
			<cfset generator = isPrimary && columntype contains "int" ? 'increment' : isPrimary && columnType is "varchar" ? 'uuid' : '' />
			<cfset addColumn(column=columnname,
							length=fieldsize,
							type=columntype,
							sqltype=getDummyType( columntype ),
							isIndex=isIndex,
							isPrimaryKey=isprimary,
							isNullable=isnullable,
							defaultvalue=defaultvalue,
							generator=generator,
							comment=comment )>

		</cfoutput>
		<cfreturn true/>

	</cffunction>


</cfcomponent>
