<!--- **********************************************************
		Component	: tabledef.cfc
		Author		: Abram Adams
		Date		: 1/2/2007
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
	<cfscript>

	public tabledef function init( required string tablename, required string dsn, boolean loadMeta = true ){
		this.instance = {
				table = queryNew( '' ),
				name = arguments.tablename,
				tabledef = {},
				tablemeta.columns = {}
		};

		setTableName( arguments.tablename );

		setDSN( arguments.dsn );

		/* grab the table metadata, unless told not to */
		if( loadMeta ){
			loadTableMetaData();
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
	public string function getColumns( string exclude = "" ){
		if( len( trim( exclude ) ) ){
			return listDeleteAt( this.instance.table.columnlist, listFindNoCase( this.instance.table.columnlist, exclude ) );
		}
		return this.instance.table.columnlist;
	}

	public query function getRows(){
		return this.instance.table;
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
		if( findNoCase( "text", arguments.type ) || arguments.type is "string" ){
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
		switch ( arguments.type ){
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

		if( structKeyExists( this.instance.tablemeta.columns, arguments.column ) ){
			return this.instance.tablemeta.columns[arguments.column].defaultValue;
		}

		return "";
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
				if ( FindNoCase('identity', this.instance.tablemeta.columns[col].SQLTYPE) eq 0 ){
					arrayAppend( noKeys, col );
				}
			}
		}

		return arrayToList( nokeys );
	}

	public string function getIndexColumns(){
		var keys = [];
		for ( var col in this.instance.tablemeta.columns ){
			if( this.instance.tablemeta.columns[col].isIndex == "YES" ){
				arrayAppend( Keys, col );
			}
		}

		return arrayToList( keys );
	}

	public string function getPrimaryKeyColumns(){
		var keys = [];
		for ( var col in this.instance.tablemeta.columns ){
			if( this.instance.tablemeta.columns[col].isPrimaryKey == "YES" ){
				arrayAppend( Keys, col );
			}
		}

		return arrayToList( keys );
	}

	public string function getPrimaryKeyColumn(){
		var keys = [];
		for ( var col in this.instance.tablemeta.columns ){
			if( this.instance.tablemeta.columns[col].isPrimaryKey == "YES" ){
				arrayAppend( Keys, col );
				break;
			}
		}

		return arrayToList( keys );
	}

	/**
	* @hint Returns the name or number for a given Java JDBC data type
	**/
	private string function jdbcType( required string typeId ){
		var sqltype = createobject("java","java.sql.Types");
		var types = {};

		for( var x in sqltype ){
			types[ x ] = sqltype[ x ];
			types[ sqltype[ x ] ] = x;
		}
		if( left( arguments.typeID, 3 ) is "INT" ){
			arguments.typeID = "integer";
		}
		if( structKeyExists(types, arguments.typeID) && types[arguments.typeId] is "timestamp" ){
			types[ arguments.typeId ] = "datetime";
		}

		return types[ arguments.typeId];
	}


	</cfscript>

<!--- PRIVATE FUNCTIONS --->
	<cffunction name="loadTableMetaData" output="false" access="public" returntype="void" hint="I load the metadata for the table.">
		<cfscript>
			var columns = "";
			var indexqryfull = "";
			var indexqry = "";
			var comparestrprimary = "";
			var comparestrnonprimary = "";
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

			// get the columns for the table for any schema
			d = new dbinfo( datasource = this.getDsn() );
			columns = d.columns( table = getTableName() );
			// get a full indexes query for the table
			indexqryfull = d.index( table = getTableName() );
		</cfscript>

		<cfquery name="primaryKeylist" dbtype="query">
			SELECT * FROM columns
			WHERE is_primarykey = 'YES'
		</cfquery>
		<!--- strip the statistics index (type = 0) --->
		<cfquery dbtype="query" name="LOCAL.indexqry_#this.instance.name#" cachedwithin="#createTimeSpan(0,1,0,0)#">
			SELECT  *
			FROM  indexqryfull
		</cfquery>


		<cfset indexqry = LOCAL['indexqry_' & this.instance.name]/>

		<!--- some JDBC drivers return different values for the non_unique column.
		Both of these should cover the different types I have come across --->
		<cfif isnumeric(indexqry.non_unique)>
			<cfset comparestrprimary = "'0'">
			<cfset comparestrnonprimary = "'-1'">
		<cfelse>
			<cfset comparestrprimary = "'false'">
			<cfset comparestrnonprimary = "'true'">
		</cfif>

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

	</cffunction>


</cfcomponent>