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

<cfcomponent hint="Instantiates a single table definition" output="true">
	<cffunction name="init" returntype="tabledef" output="false">
		<cfargument name="tablename" type="string" required="yes" >
		<cfargument name="dsn" type="string" required="yes">
		
			<cfscript>
				this.instance = {};
				this.instance.table = queryNew('');
				this.instance.name = arguments.tablename;
				this.instance.tabledef = {};
				setTableName(arguments.tablename);
				this.instance.tablemeta.columns = {};
				this.dsn = arguments.dsn;

				/* Uses coldfusion.server.ServiceFactory to grab the table metadata */
				loadTableMetaData();
				
			</cfscript>


		<cfreturn this />
	</cffunction>

	<cffunction name="setTableName" access="public" returntype="void" output="false">
		<cfargument name="tablename" type="string" hint="Table Name" required="yes">
		<!--- <cfset this.instance.table.name = trim(arguments.tablename)> --->
		<cfset this.instance.name = trim(arguments.tablename)>
	</cffunction>

	<cffunction name="addColumn" access="public" returntype="void" output="false">
		<cfargument name="column" type="string" hint="Table column name" required="yes">
		<cfargument name="datatype" type="string" hint="Table column data type" required="yes">
		<!---
			Integer: 32-bit integer
			BigInt: 64-bit integer
			Double: 64-bit decimal number
			Decimal: Variable length decimal, as specified by java.math.BigDecimal
			VarChar: String
			Binary: Byte array
			Bit: Boolean (1=True, 0=False)
			Time: Time
			Data: Date (can include time information)
		 --->
		<cfargument name="length" type="string" hint="Table column max length" required="yes">
		<cfargument name="isPrimaryKey" type="boolean" hint="Is table column the primary key?" required="yes">
		<cfargument name="generator" type="string" hint="Genertor method for field (i.e. increment or uuid)" required="false" default="">
		<cfargument name="isIndex" type="boolean" hint="Is table column an index?" required="yes">		
		<cfargument name="isNullable" type="boolean" hint="Is table column nullable?" required="yes">
		<cfargument name="defaultvalue" type="string" hint="Table column default value" required="no" default="">
		<cfargument name="comment" type="string" hint="Table column comment" required="no" default="">
		<cfargument name="isDirty" type="boolean" hint="Used to identify columns that had data changed" required="no" default="false">

		<cfset var arrPadding = arrayNew(1)>
		<cfscript>
			//<!--- need to make serializable --->
			/* Store Column Definition in structure for later use*/
			StructInsert(this.instance.tablemeta.columns,arguments.column,{});
			this.instance.tablemeta.columns[arguments.column].type = getValidDataType(arguments.datatype);
			this.instance.tablemeta.columns[arguments.column].length = arguments.length;
			this.instance.tablemeta.columns[arguments.column].isIndex = arguments.isIndex;
			this.instance.tablemeta.columns[arguments.column].isPrimaryKey = arguments.isPrimaryKey;			
			this.instance.tablemeta.columns[arguments.column].isNullable = arguments.isNullable;
			this.instance.tablemeta.columns[arguments.column].defaultValue = arguments.defaultValue;
			this.instance.tablemeta.columns[arguments.column].generator = arguments.generator;
			this.instance.tablemeta.columns[arguments.column].comment = arguments.comment;
			this.instance.tablemeta.columns[arguments.column].isDirty = arguments.isDirty;

			QueryAddColumn(this.instance.table,arguments.column,getDummyType(arguments.datatype),arrPadding);

		</cfscript>
	</cffunction>

	<cffunction name="setColumn" access="public" returntype="void" hint="I add data to the given column" output="false">
		<cfargument name="column" required="yes" type="string">
		<cfargument name="value" required="yes" type="any">
		<cfargument name="row" required="yes" type="numeric">
		
		<cfset var ret = "">

		<cfset ret = querySetCell(this.instance.table, arguments.column,arguments.value,arguments.row)>

	</cffunction>

	<cffunction name="setColumnComment" access="public" returntype="void" hint="I add data to the given column" output="false">
		<cfargument name="column" required="yes" type="string">
		<cfargument name="comment" required="yes" type="any">

		<cfset this.instance.tablemeta.columns[arguments.column].comment = arguments.comment>

	</cffunction>
	
	<cffunction name="setColumnIsDirty" access="public" returntype="void" hint="I add data to the given column" output="false">
		<cfargument name="column" required="yes" type="string">
		<cfargument name="isDirty" required="no" type="boolean" default="true">

		<cfset this.instance.tablemeta.columns[arguments.column].isDirty = arguments.isDirty>

	</cffunction>
	
	<cffunction name="setColumnPrimaryKeyGenerator" access="public" returntype="void" hint="I add data to the given column" output="false">
		<cfargument name="column" required="yes" type="string">
		<cfargument name="generator" required="no" type="string" default="increment">

		<cfset this.instance.tablemeta.columns[arguments.column].primaryKeyGenerator = arguments.generator/>

	</cffunction>

	<cffunction name="addRow" access="public" returntype="numeric" hint="I add a blank row to the tabledef object and return the new row count." output="false">

		<cfset var ret = "">
		
		<cfset ret = queryAddRow(this.instance.table)>

		<cfreturn getRowCount() />
	</cffunction>



<!--- GETTERS --->
	<cffunction name="getTableName" access="public" returntype="string" output="false">
		<cfreturn this.instance.name />
	</cffunction>

	<cffunction name="getColumns" access="public" returntype="string" output="false">
		<cfreturn this.instance.table.columnlist />
	</cffunction>

	<cffunction name="getRows" access="public" returntype="query" output="false">
		<cfreturn duplicate(this.instance.table) />
	</cffunction>

	<cffunction name="getRowCount" access="public" returntype="numeric" output="false">
		<cfreturn this.instance.table.recordcount />
	</cffunction>

	<cffunction name="getValidDataType" output="false" returntype="string">
		<cfargument name="type" required="yes" type="string">
			<!---ARRAY
			BIGINT
			BINARY
			BIT
			BLOB
			BOOLEAN
			CHAR
			CLOB
			DATALINK
			DATE
			DECIMAL
			DISTINCT
			DOUBLE
			FLOAT
			INTEGER
			JAVA_OBJECT
			LONGNVARCHAR
			LONGVARBINARY
			LONGVARCHAR
			NCHAR
			NCLOB
			NULL
			NUMERIC
			NVARCHAR
			OTHER
			REAL
			REF
			ROWID
			SMALLINT
			SQLXML
			STRUCT
			TIME
			TIMESTAMP
			TINYINT
			VARBINARY
			VARCHAR--->
		<cfif arguments.type is "datetime">
			<cfset arguments.type = "timestamp">
		</cfif>		
		<cfif findNoCase("int",arguments.type)>
			<cfset arguments.type = "INTEGER"/>
		</cfif>
		<cfif findNoCase("text",arguments.type)>
			<cfset arguments.type = "VARCHAR"/>
		</cfif>
		<cfset var cfsqltype = jdbcType(typeid = arguments.type)/>
		
		<cfreturn cfsqltype/>
		
	</cffunction>
	<cffunction name="getDummyType" output="false">
		<cfargument name="type" required="yes" type="string">

		<cfswitch expression="#arguments.type#">
		<!--- Integer | BigInt | Double | Decimal | VarChar | Binary | Bit | Time | Date]  --->
			<cfcase value="4">
				<cfset dummytype = "Integer">
			</cfcase>
			<cfcase value="5">
				<cfset dummytype = "Integer">
			</cfcase>
			<cfcase value="93">
				<cfset dummytype = "Date">
			</cfcase>
			<cfcase value="12">
				<cfset dummytype = "VarChar">
			</cfcase>
			<cfcase value="-4">
				<cfset dummytype = "VarChar">
			</cfcase>
			<cfcase value="-1">
				<cfset dummytype = "VarChar">
			</cfcase>
			<cfcase value="-7">
				<cfset dummytype = "Bit">
			</cfcase>
			<cfcase value="8">
				<cfset dummytype = "Double">
			</cfcase>
			<cfcase value="1">
				<cfset dummytype = "VarChar">
			</cfcase>
			<cfcase value="-6">
				<cfset dummytype = "Integer">
			</cfcase>
			<cfcase value="2">
				<cfset dummytype = "Decimal">
			</cfcase>
			<cfdefaultcase>
				<cfset dummytype = "VarChar">
			</cfdefaultcase>
		</cfswitch>
		<cfreturn dummytype />
	</cffunction>

	<cffunction name="getColumnType" access="public" returntype="any" output="false">
		<cfargument name="column" required="yes" type="string" hint="Column in which to determine data type.">
		<cfset var type = "varchar">

		<cfif structKeyExists(this.instance.tablemeta.columns,arguments.column)>
			<cfset type = this.instance.tablemeta.columns[arguments.column].type>
		</cfif>

		<cfreturn  type />
	</cffunction>

	<cffunction name="getColumnNullValue" access="public" returntype="string" hint="I return a null value based on the passed column's type." output="false">
		<cfargument name="column" required="yes" type="string" hint="Column in which to determine data type.">
		<cfset var ret = getColumnDefaultValue(arguments.column)>

		<cfif not len(trim(ret))>
			<cfswitch expression="#lcase(getDummyType(getColumnType(arguments.column)))#">
				<cfcase value="date">
					<cfset ret = "0000-00-00 00:00">
				</cfcase>
				<cfcase value="double">
					<cfset ret = "0.00">
				</cfcase>
				<cfcase value="decimal">
					<cfset ret = "0.00">
				</cfcase>
				<cfcase value="bit">
					<cfset ret = "NULL">
				</cfcase>
				<cfcase value="integer">
					<cfset ret = "0">
				</cfcase>
				<cfcase value="tinyint">
					<cfset ret = "0">
				</cfcase>
				<cfcase value="int">
					<cfset ret = "0">
				</cfcase>
				<cfcase value="boolean">
					<cfset ret = "0">
				</cfcase>
				<cfcase value="varchar">
					<cfset ret = "">
				</cfcase>
				<cfdefaultcase>
					<cfset ret = "">
				</cfdefaultcase>
			</cfswitch>
		</cfif>

		<cfreturn  ret />
	</cffunction>


	<cffunction name="getCFSQLType" output="false">
		<cfargument name="col" required="yes" type="string">
		<cfset var cfsqltype = "">
		
		<cfset cfsqltype = jdbcType(typeid = getColumnType(arguments.col))/>
		
		<cfif cfsqltype is "datetime">
			<cfset cfsqltype = "timestamp">
		</cfif>		
		<cfreturn "cf_sql_" & cfsqltype>
	</cffunction>

	<cffunction name="getColumnLength" access="public" returntype="numeric" output="false">
		<cfargument name="column" required="yes" type="string" hint="Column in which to determine data type.">

		<cfreturn this.instance.tablemeta.columns[arguments.column].length />
	</cffunction>


	<cffunction name="getColumnIsDirty" access="public" returntype="boolean" output="false">
		<cfargument name="column" required="yes" type="string" hint="Column in which to determine if data changed.">

		<cfreturn this.instance.tablemeta.columns[arguments.column].isDirty />
	</cffunction>

	<cffunction name="getColumnDefaultValue" access="public" returntype="string" output="false">
		<cfargument name="column" required="yes" type="string" hint="Column in which to determine data type.">
		<cfset var ret = ""/>
		<cfif structKeyExists(this.instance.tablemeta.columns, arguments.column)>
			<cfset ret = this.instance.tablemeta.columns[arguments.column].defaultValue>
		<cfelse>
			<cfset ret = "">
		</cfif>
		<cfreturn ret />
	</cffunction>

	<cffunction name="isColumnIndex" access="public" returntype="any" output="false">
		<cfargument name="column" required="yes" type="string" hint="Column in which to determine data type.">

		<cfreturn this.instance.tablemeta.columns[arguments.column].isIndex />
	</cffunction>

	<cffunction name="isColumnNullable" access="public" returntype="boolean" output="false">
		<cfargument name="column" required="yes" type="string" hint="Column in which to determine data type.">
		<cfset var nullable = true>
		<cfif structKeyExists(this.instance.tablemeta.columns,arguments.column)>
			<cfset nullable = this.instance.tablemeta.columns[arguments.column].isNullable>
		</cfif>
		<cfreturn nullable />
	</cffunction>

	<cffunction name="getTableMeta" access="public" returntype="struct" output="false">
		<cfreturn this.instance.tablemeta />
	</cffunction>

	<cffunction name="getNonPrimaryKeyColumns" access="public" returntype="string" output="false">
		<cfset var noKeys = "">
		<cfset var col = ""/>
		
		<cfloop collection="#this.instance.tablemeta.columns#" item="col">
			<cfif this.instance.tablemeta.columns[col].isPrimaryKey is not "YES">
				<!--- <cfdump var="#this.instance.tablemeta.columns[col]#"> --->
				<cfset nokeys = listAppend(noKeys,col)>
				<!--- <cfdump var="#nokeys#"> --->
			</cfif>
		</cfloop>
		<cfreturn noKeys />
	</cffunction>

	<cffunction name="getNonAutoIncrementColumns" access="public" returntype="string" output="false">
		<cfset var noKeys = "">
		<cfset var col = ""/>
		
		<cfloop collection="#this.instance.tablemeta.columns#" item="col">
			<cfif !( len( trim( this.instance.tablemeta.columns[col].generator ) ) && !this.instance.tablemeta.columns[col].isPrimaryKey )|| this.instance.tablemeta.columns[col].generator eq "uuid">
				<!--- <cfdump var="#this.instance.tablemeta.columns[col]#"> --->
				<cfset nokeys = listAppend(noKeys,col)>
				<!--- <cfdump var="#nokeys#"> --->
			</cfif>
		</cfloop>

		<cfreturn noKeys />
	</cffunction>
	
	<cffunction name="getIndexColumns" access="public" returntype="string" output="false" hint="I return the index key fields for the current table.">
		<cfset var Keys = "">
		<cfset var col = ""/>
		<cfloop collection="#this.instance.tablemeta.columns#" item="col">
			<cfif this.instance.tablemeta.columns[col].isIndex is "YES">
				<cfset keys = listAppend(Keys,col)>
			</cfif>
		</cfloop>
		<cfreturn Keys />
	</cffunction>

	<cffunction name="getPrimaryKeyColumn" access="public" returntype="string" output="false">
		<cfset var Keys = "">
		<cfset var col = ""/>
		<cfloop collection="#this.instance.tablemeta.columns#" item="col">
			<cfif this.instance.tablemeta.columns[col].isPrimaryKey is "YES">
				<cfset keys = listAppend(Keys,col)>
				<cfbreak>
			</cfif>
		</cfloop>
		<cfreturn Keys />
	</cffunction>

<!--- END:GETTERS --->
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
			d = new dbinfo( datasource = this.dsn );
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
							datatype=columntype,
							isIndex=isIndex,
							isPrimaryKey=isprimary,
							isNullable=isnullable,
							defaultvalue=defaultvalue,
							generator=generator,
							comment=comment )>
			
		</cfoutput>
						
	</cffunction>
	
	<cffunction name="jdbcType" output="false" returntype="string"  hint="returns the name or number for a given Java JDBC data type">
		<cfargument name="typeid" type="string" required="true">
		
		<cfset var sqltype = createobject("java","java.sql.Types")>
		<cfset var types = {}>
		<cfset var x = ""/>		
		<cfloop item="x" collection="#sqltype#">
			<cfset types[x] = sqltype[x]>
			<cfset types[sqltype[x]] = x>
		</cfloop>
		
		<cfif left(arguments.typeID,3) is "INT">
			<cfset arguments.typeID = "integer"/>
		</cfif> 
		<cfif structKeyExists(types, arguments.typeID) && types[arguments.typeid] is "timestamp">
			<cfset types[arguments.typeid] = "datetime">		
		</cfif>
		
		
		<cfreturn types[arguments.typeid]>
	</cffunction>

</cfcomponent>