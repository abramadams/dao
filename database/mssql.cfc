<!---
************************************************************
*
*	Copyright (c) 2007-2021, Abram Adams
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
*		Component	: dao.cfc (MSSQL Specific)
*		Author		: Abram Adams
*		Date		: 1/2/2007
*		@version 1.0.0
*	   	@updated 10/10/2021
*   	@dependencies { "dao" : ">=1.0.0" }
*		Description	: Targeted database access object that will
*		controll all MSSQL specific database interaction.
*		This component will use MSSQL syntax to perform general
*		database functions.
*********************************************************** --->


<cfcomponent output="false" accessors="true" implements="IDAOConnector">
	<cfproperty name="dao" type="dao" />
	<cfproperty name="dsn" type="string" />
	<cfproperty name="useCFQueryParams" type="boolean" />

	<cffunction name="init" access="public" output="false" displayname="DAO Constructor" hint="I initialize MySQL DAO.">
		<cfargument name="dao" type="dao" required="true" hint="DAO object" />
		<cfargument name="dsn" type="string" required="true" hint="Data Source Name" />
		<cfargument name="user" type="string" required="false" default="" hint="Data Source User Name" />
		<cfargument name="password" type="string" required="false" default="" hint="Data Source Password" />
		<cfargument name="useCFQueryParams" type="boolean" required="false" hint="Determines if execute queries will use cfqueryparam" default="true" />

		<cfscript>

			//This is the datasource name for the system
			setDsn( dsn );
			setDao( dao );
			setUseCFQueryParams( arguments.useCFQueryParams );
		</cfscript>

		<cfreturn this />

	</cffunction>

	<cffunction name="getLastID" hint="I return the ID of the last inserted record.  I am MSSQL specific." returntype="any" output="false">
		<cfquery name="get" datasource="#getDsn()#">
			SELECT Scope_Identity() as thekey
		</cfquery>
		<cfreturn get.thekey />
	</cffunction>


	<cffunction name="delete" hint="I delete records from the database.  I am mssql specific." returntype="boolean" output="false">
		<cfargument name="TableName" required="true" type="string" hint="Table to delete from.">
		<cfargument name="recordID" required="true" type="string" hint="Record ID of record to be deleted.">
		<cfargument name="IDField" required="false" type="string" hint="ID field of record to be deleted.">

		<cfset var ret = true />
		<cfset var pk = getPrimaryKey(arguments.tablename) />
		<cfset var del = "" />

		<cftry>
			<cfquery name="del" datasource="#getDsn()#">
				DELETE from #arguments.tablename#
				<cfif not len(trim(arguments.IDField))>
				WHERE #getSafeColumnName(pk.field)# = <cfqueryparam cfsqltype="#getCFSQLType(pk.type)#" value="#arguments.recordID#">
				<cfelse>
				WHERE #getSafeColumnName(arguments.idField)# = <cfqueryparam cfsqltype="#getCFSQLType(pk.type)#" value="#arguments.recordID#">
				</cfif>
			</cfquery>
			<cfcatch type="any">
				<cfset ret = false>
			</cfcatch>
		</cftry>
		<cfreturn ret />
	</cffunction>

	<cffunction name="deleteAll" hint="I delete all records from the passed tablename.  I am mssql specific." returntype="boolean" output="false">
		<cfargument name="TableName" required="true" type="string" hint="Table to delete from.">

		<cfset var ret = true />
		<cfset var rel = "" />

		<cftry>
			<cfquery name="del" datasource="#getDsn()#">
				DELETE from #arguments.tablename#
			</cfquery>
			<cfcatch type="any">
				<cfset ret = false>
			</cfcatch>
		</cftry>
		<cfreturn ret />
	</cffunction>


	<cffunction name="select" hint="I select records from the database.  I am MSSQL specific." returntype="query" output="false">
		<cfargument name="sql" required="false" type="string" default="" hint="Either Table to select from or sql statement.">
		<cfargument name="name" required="false" type="string" hint="Name of Query (required for cachedwithin)" default="sel_#listFirst(createUUID(),'-')#">
		<cfargument name="cachedwithin" required="false" type="any" hint="createTimeSpan() to cache this query" default="">
		<cfargument name="table" required="false" type="string" default="" hint="Table name to select from, use only if not using SQL">
		<cfargument name="alias" required="false" type="string" default="" hint="Table alias name to select from, use only if not using SQL">
		<cfargument name="columns" required="false" type="string" default="" hint="List of valid column names for select statement, use only if not using SQL">
		<cfargument name="where" required="false" type="string" hint="Where clause. Only used if sql is a tablename" default="">
		<cfargument name="limit" required="false" type="any" hint="Limit records returned." default="">
		<cfargument name="offset" required="false" type="any" hint="Offset queried recordset." default="">
		<cfargument name="orderby" required="false" type="string" hint="Order By columns.  Only used if sql is a tablename" default="">

		<cfset var get = "" />
		<cfset var idx = "" />
		<cfif listlen( arguments.sql, ' ') EQ 1 && !len( trim( arguments.table ) )>
			<cfset arguments.table = arguments.sql/>
		</cfif>

		<cftry>
			<cfif listlen(trim(arguments.sql), ' ') GT 1>
				<cfif len(trim(arguments.cachedwithin))>
					<cfquery name="get" datasource="#getDsn()#" cachedwithin="#arguments.cachedwithin#">
						<!--- #preserveSingleQuotes(arguments.sql)# --->
						<!---
							Parse out the queryParam calls inside the where statement
							This has to be done this way because you cannot use
							cfqueryparam tags outside of a cfquery.
							@TODO: refactor to use the query.cfc
						--->
						<cfset var tmpSQL = getDao().parameterizeSQL( arguments.where )/>
						<cfloop from="1" to="#arrayLen( tmpSQL.statements )#" index="idx">
							#tmpSQL.statements[idx].before#
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
					<cfquery name="get" datasource="#getDsn()#">
						<!--- #preserveSingleQuotes(arguments.sql)# --->
						<!---
							Parse out the queryParam calls inside the where statement
							This has to be done this way because you cannot use
							cfqueryparam tags outside of a cfquery.
							@TODO: refactor to use the query.cfc
						--->
						<cfset var tmpSQL = getDao().parameterizeSQL( arguments.where )/>
						<cfloop from="1" to="#arrayLen( tmpSQL.statements )#" index="idx">
							#tmpSQL.statements[idx].before#
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


				<!--- DB Agnostic Limit/Offset for server-side paging --->
				<cfif len( trim( limit ) ) && len( trim( offset ) )>
					<cfset get = getDao().pageRecords( get, offset, limit ) />
				</cfif>
			<cfelse>
				<!--- Table select --->
				<cfif !len( trim( arguments.columns ) ) >
					<cfset arguments.columns = getSafeColumnNames(getDao().getColumns(arguments.table))/>
				</cfif>
				<cfset var columnAliases = arguments.columns.listToArray().map((col)=>{
					var ret = col.listLast( ' ' );
					ret = ret.listLast( '.' );
					return ret;
				}).toList()/>
				<cfif !isNull( arguments.alias ) >
					<cfset arguments.columns = arguments.columns.reReplaceNoCase( "\b#arguments.table#\.", "#arguments.alias#.", "all" )/>
				</cfif> 
				<cfif len(trim(arguments.cachedwithin))>
					<cfquery name="get" datasource="#getDsn()#" cachedwithin="#arguments.cachedwithin#">

						SELECT #columnAliases#
						FROM (
							SELECT ROW_NUMBER() OVER(ORDER BY #( len( trim( arguments.orderby ) ) ? arguments.orderby : getDao().getPrimaryKey( arguments.table )['field'] )#) as [__fullCount], #arguments.columns#
							FROM #arguments.table# #arguments.alias#
							<cfif len( trim( arguments.where ) )>
							<!---
								Parse out the queryParam calls inside the where statement
								This has to be done this way because you cannot use
								cfqueryparam tags outside of a cfquery.
								@TODO: refactor to use the query.cfc
							--->
							<cfset tmpSQL = getDao().parameterizeSQL( arguments.where )/>
							<cfloop from="1" to="#arrayLen( tmpSQL.statements )#" index="idx">
								#tmpSQL.statements[idx].before#
								<cfif structKeyExists( tmpSQL.statements[idx], 'cfsqltype' )>
									<cfqueryparam
										cfsqltype="#tmpSQL.statements[idx].cfSQLType#"
										value="#tmpSQL.statements[idx].value#"
										list="#tmpSQL.statements[idx].isList#">
								</cfif>
							</cfloop>
							<!--- /Parse out the queryParam calls inside the where statement --->
							</cfif>
							<cfif len( trim( arguments.orderby ) )>
								ORDER BY #arguments.orderby#
							</cfif>
							) #arguments.table#
						<cfif val( arguments.limit ) GT 0>
							WHERE [__fullCount] BETWEEN #val( arguments.offset )# AND #val( arguments.limit )#
						</cfif>
					</cfquery>
				<cfelse>
					<cfquery name="get" datasource="#getDsn()#">
						SELECT #columnAliases#
							FROM (
								SELECT ROW_NUMBER() OVER(ORDER BY #( len( trim( arguments.orderby ) ) ? arguments.orderby : getDao().getPrimaryKey( arguments.table )['field'] )#) as [__fullCount], #arguments.columns#
								FROM #arguments.table# as #arguments.alias#
								<cfif len( trim( arguments.where ) )>
								<!---
									Parse out the queryParam calls inside the where statement
									This has to be done this way because you cannot use
									cfqueryparam tags outside of a cfquery.
									@TODO: refactor to use the query.cfc
								--->
								<cfset var tmpSQL = getDao().parameterizeSQL( arguments.where )/>
								<cfloop from="1" to="#arrayLen( tmpSQL.statements )#" index="idx">
									#tmpSQL.statements[idx].before#
									<cfif structKeyExists( tmpSQL.statements[idx], 'cfsqltype' )>
										<cfqueryparam
											cfsqltype="#tmpSQL.statements[idx].cfSQLType#"
											value="#tmpSQL.statements[idx].value#"
											list="#tmpSQL.statements[idx].isList#">
									</cfif>
								</cfloop>
								<!--- /Parse out the queryParam calls inside the where statement --->
								</cfif>
								) #arguments.table#

							<cfif val( arguments.limit ) GT 0>
								WHERE [__fullCount] BETWEEN #val( arguments.offset )# AND #val( arguments.limit )#
							</cfif>
							<cfif len( trim( arguments.orderby ) )>
								ORDER BY #arguments.orderby#
							</cfif>
					</cfquery>
				</cfif>
			</cfif>

			<cfcatch type="any">
				<cfdump var="#arguments#" label="Arguments passed to select()">
				<cfdump var="#cfcatch#" label="CFCATCH Information">
				<!---<cfdump var="#evaluate(arguments.name)#" label="Query results">--->
				<cfsetting showdebugoutput="false">
				<cfabort>
			</cfcatch>
		</cftry>
		<cfreturn get />
	</cffunction>

	<cfscript>
	function write( required tabledef tabledef, boolean insertPrimaryKeys = false, boolean bulkInsert = false ) output = false hint="I insert data into the database.  I take a tabledef object containing the tablename and column values. I return the new record's Primary Key value.  I am MySQL specific." {

		var curRow = 0;
		var columns = "";
		var ins = "";
		var isnull = "";
		var cfsqltype = "cf_sql_varchar";
		var tablename = tabledef.getTableName();
		var col = "";
		var ret = [];


		var qry = arguments.tabledef.getRows();
		if( !arguments.insertPrimaryKeys ){
			columns = arguments.tabledef.getNonAutoIncrementColumns();
		}else{
			columns = arguments.tabledef.getColumns();
		}
		if( !qry.recordCount ){
			throw( message = "No data to insert" );
		}

		var ins = "";
		for( var row in qry ){
			ins &= "INSERT INTO #tablename# (#getSafeColumnNames(columns)#)
					VALUES(";
			curRow = 0;

			for( var col in columns ){

				isnull = "false";
				curRow++;

				//  push the cfsqltype into a var scope variable that get's reset at the end of this loop
				cfsqltype = tabledef.getCFSQLType(col);
				if( cfsqltype == "cf_sql_date" && isDate( row[col] ) ){
					cfsqltype = "cf_sql_timestamp";
				}
				if( !len( trim( row[col] ) ) ){
					if( len( trim( tabledef.getColumnDefaultValue( col ) ) ) ){
						row[col] = tabledef.getColumnDefaultValue( col );
					}else{
						row[col] = tabledef.getColumnNullValue( col );
						isnull = "true";
					}
				}
				if( !tabledef.isColumnNullable( col ) ){
					isnull = "false";
					if( ( cfsqltype contains "date" || cfsqltype contains "time" ) ){
						if( row[col] == 'CURRENT_TIMESTAMP'){
							row[col] = '';
						}else if( row[col] == '0000-00-00 00:00:00' ){
							row[col] = createTime( 0, 0, 0 );
						}
					}
				}
				if( curRow > 1){
					ins &=",";
				}
				if( !len( trim( row[col] ) ) ){
					row[col] = tabledef.getColumnNullValue( row[col] );
					if( cfsqltype != "cf_sql_boolean" ){
						isnull = "true";
					}
				}

				ins &= getDao().queryParam( value = row[col], cfsqltype = cfsqltype, list = 'false', null = isnull );
				cfsqltype = "bad";
			}
			ins &= ")";
			if( qry.recordCount > qry.currentRow ){
				if( !arguments.bulkInsert ){
					ins &= chr(789);
				}else{
					ins &= "
						GO
					";
				}
			}
		}

		if( !arguments.bulkInsert ){
			var statements = listLen( ins, chr(789) );
			for( var i = 1; i <= statements; i++){
				ret.append( getDao().execute( listGetAt( ins, i, chr(789) ) ) );
			}
		}else{
			ret.append( getDao().execute( ins ) );
		}

		return ret.len() gt 1 ? ret : ret[ 1 ];
	}
	</cfscript>

	<cffunction name="update" hint="I update all fields in the passed table.  I take a tabledef object containing the tablename and column values. I return the record's Primary Key value.  I am mssql specific." returntype="any" output="false">
		<cfargument name="tabledef" required="true" type="any" hint="TableDef object containing data.">
		<cfargument name="columns" required="false" default="" type="string" hint="Optional list columns to be updated.">
		<cfargument name="IDField" required="true" type="string" hint="Optional list columns to be updated.">

		<cfset var curRow = 0 />
		<cfset var current = arrayNew(1) />
		<cfset var qry = arguments.tabledef.getRows() />
		<cfset var pk = arguments.IDField />
		<cfset var ret = true />
		<cfset var value = "" />
		<cfset var isnull = "false" />
		<cfset var upd = "" />
		<cfset var col = "" />
		<cfset var cfsqltype = "" />
		<cfset var tableName = arguments.tabledef.getTableName()/>
		<cfset var performUpdate = false/>
		<cfif not len(trim(arguments.columns))>
			<cfset arguments.columns = arguments.tabledef.getColumns()>
		</cfif>

		<cftry>
			<cfoutput query="qry">
				<!--- reset current row counter --->
				<cfset curRow = 0>

					<cfsavecontent variable="upd">
						UPDATE #tableName#
						SET
							<cfloop list="#arguments.columns#" index="col">
								<!--- No need to update th PK field --->
								<cfif col NEQ pk AND arguments.tabledef.getColumnIsDirty(col)>
									<cfset performUpdate = true/>
									<cfset isnull = "false">
									<cfset curRow = curRow +1>
									<cfif curRow GT 1>, </cfif>
									#getSafeColumnName(col)# =
									<cfset value = qry[col][currentRow]/>
									<cfset cfsqltype = arguments.tabledef.getCFSQLType(col)>

									<cfif not len(trim(value))>
										<cfif cfsqltype neq "cf_sql_boolean">
											<cfset isnull = "true">
										</cfif>
										<cfset value = arguments.tabledef.getColumnNullValue(col)>
										<cfif not arguments.tabledef.isColumnNullable(col)>
											<cfset isnull = "false">
										</cfif>
										<!--- <cfif cfsqltype is "cf_sql_timestamp">
											<cfset cfsqltype = "cf_sql_varchar">
										</cfif> --->
									</cfif>

									<!---<cfqueryparam value="#value#" cfsqltype="#cfsqltype#" null="#isnull#">--->
									#getDao().queryParam(value=value,cfsqltype=cfsqltype,list='false',null=isnull)#
									<cfset value = "">
									<cfset cfsqltype = "">
								</cfif>
							</cfloop>

						WHERE #getSafeColumnName(pk)# = #getDao().queryParam(qry[pk][currentRow])#
					</cfsavecontent>
					<cfset ret = qry[pk][currentRow] />

					<cfif performUpdate>
						<cfset getDao().execute(upd) />
					</cfif>
				<!---</cftransaction>--->
			</cfoutput>
			<cfcatch type="any">
				<cfset constants.ERROR = structNew()/>
				<cfset constants.ERROR.details = cfcatch/>
				<cfset constants.ERROR.data = structNew()/>
				<cfset constants.ERROR.data.message = "Data attempted to be inserted"/>
				<cfset constants.ERROR.data.details = arguments.tabledef.getRows() />
				<cfset constants.ERROR.data.query =  upd/>
				<cfset constants.ERROR.table =  structNew()/>
				<cfset constants.ERROR.table.message = "Table Definition"/>
				<cfset constants.ERROR.table.details = define(arguments.tabledef.getTableName()) />

				<cfthrow errorcode="803-mssql.update" type="dao.custom.error" detail="Unexpected Error" message="There was an unexpected error updating the database.  Please contact your administrator. #cfcatch.message#">

			</cfcatch>

		</cftry>


		<cfreturn ret />
	</cffunction>

<!--- Data Definition Functions --->
	<cffunction name="define" hint="I return the structure of the passed table.  I am MSSQL specific." returntype="any" output="false">
		<cfargument name="TableName" required="true" type="string" hint="Table to define.">

		<cfset var table = new tabledef( dsn = getDao().getDSN(), tableName = arguments.TableName )>
		<cfset var def = table.getTableMeta()>

		<cfreturn def />
	</cffunction>

	<cffunction name="getPrimaryKey" hint="I return the primary key column name and type for the passed in table.  I am MSSQL specific." returntype="struct" output="false">
		<cfargument name="TableName" required="true" type="string" hint="Table to return primary key.">

		<cfset var table = new tabledef( dsn = getDao().getDSN(), tableName = arguments.TableName )>
		<cfset var pk = table.getPrimaryKeyColumn()/>
		<cfset var type = table.getColumnType( pk )/>

		<cfreturn { field = pk, type = type } />

	</cffunction>

	<cffunction name="getPrimaryKeys" hint="I return the primary keys column name and type for the passed in table.  I am MSSQL specific." returntype="array" access="public" output="false">
		<cfargument name="TableName" required="true" type="string" hint="Table to return primary key.">

		<cfset var def = define(arguments.tablename) />
		<cfset var ret = [] />
		<cfset var get = "" />

		<cfquery name="get" dbtype="query">
			SELECT [Field],[Type] from def
			WHERE [Key] = 'PRI'
		</cfquery>
		<cfoutput query="get">
			<cfset arrayAppend(ret, structNew())/>
			<cfset ret[arrayLen(ret)].field = get.field>
			<cfset ret[arrayLen(ret)].type = getDAO().getCFSQLType( listFirst( get.type, '(' ) )>
		</cfoutput>

		<cfreturn ret />

	</cffunction>
	<!--- GETTERS --->

	<cfscript>
		/**
		* I take a list of columns and return it as a safe columns list with each column wrapped within ``.  This is MySQL Specific.
		**/
		public string function getSafeColumnNames( required string cols )  output = false {
			var columns = [];
			// writeDump(cols);abort;
			for( var colName in listToArray( cols ) ){
				var col = reReplace( colName, "(.*?)(\.)(.+?)(,|\.|\s|$)", "#getSafeIdentifierStartChar()#\1#getSafeIdentifierEndChar()#.#getSafeIdentifierStartChar()#\3#getSafeIdentifierEndChar()#", "all" );
				arrayAppend( columns, col );
			}

			return arrayToList( columns );
		}
		/**
		* I take a single column name and return it as a safe columns list with each column wrapped within ``.  This is MySQL Specific.
		* */
		public string function getSafeColumnName( required string col ) output = false{
			return "#getSafeIdentifierStartChar()##trim(arguments.col)##getSafeIdentifierEndChar()#";
		}
		/**
		* I return the opening escape character for a column name.  This is MySQL Specific.
		* */
		public string function getSafeIdentifierStartChar() output = false{
			return '[';
		}
		/**
		* I return the closing escape character for a column name.  This is MySQL Specific.
		* */
		public string function getSafeIdentifierEndChar() output = false{
			return ']';
		}

		/**
	    * @hint I create a table based on the passed in tabledef object's properties.
	    **/
		public tabledef function makeTable( required tabledef tabledef ) output = false {

			var tableSQL = "CREATE TABLE #getSafeIdentifierStartChar##tabledef.getTableName()##getSafeIdentifierEndChar()# (";
			var columnsSQL = "";
			var primaryKeys = "";
			var indexes = "";
			var autoIncrement = false;
			var tmpstr = "";


			for ( var colName in tableDef.getTableMeta().columns ){
				var col = tableDef.getTableMeta().columns[ colName ];
				col.name = colName;

				switch( col.sqltype ){
					case 'string':
						tmpstr = '#getSafeIdentifierStartChar()##col.name##getSafeIdentifierEndChar()# varchar(#structKeyExists( col, 'length' ) ? col.length : '255'#) #( col.isPrimaryKey || col.isIndex ) ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & col.default & "'": ''#';
					break;
					case 'numeric':
						tmpstr = '#getSafeIdentifierStartChar()##col.name##getSafeIdentifierEndChar()# int #structKeyExists(col,'generator') && col.generator eq 'increment' ? ' IDENTITY(1,1) ' : ''# #col.isPrimaryKey ? ' PRIMARY KEY' : ''# #( col.isPrimaryKey || col.isIndex ) ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & col.default & "'": ''#';
					break;
					case 'date':
						tmpstr = '#getSafeIdentifierStartChar()##col.name##getSafeIdentifierEndChar()# datetime #( col.isPrimaryKey || col.isIndex ) ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & col.default & "'": ''#';
					break;
					case 'tinyint':
						tmpstr = '#getSafeIdentifierStartChar()##col.name##getSafeIdentifierEndChar()# tinyint(1) #structKeyExists(col,'generator') && col.generator eq 'increment' ? ' IDENTITY(1,1) ' : ''# #( col.isPrimaryKey || col.isIndex ) ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & (col.default ? 1 : 0) & "'": ''#';
					break;
					case 'boolean': case 'bit':
						tmpstr = '#getSafeIdentifierStartChar()##col.name##getSafeIdentifierEndChar()# BIT #( col.isPrimaryKey || col.isIndex ) ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT " & (col.default ? true : false) : ''#';
					break;
					case 'text':
						tmpstr = '#getSafeIdentifierStartChar()##col.name##getSafeIdentifierEndChar()# text #( col.isPrimaryKey || col.isIndex ) ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & (col.default ? 1 : 0) & "'": ''#';
					break;
					default:
						tmpstr = '#getSafeIdentifierStartChar()##col.name##getSafeIdentifierEndChar()# #col.type# #structKeyExists( col, 'length' ) ? '(' & col.length & ')' : '(255)'# #( col.isPrimaryKey || col.isIndex ) ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & col.default & "'": ''#';
					break;
				}

				if( structKeyExists( col, 'generator' ) && col.generator eq 'increment' ){
					autoIncrement = true;
					columnsSQL = listPrepend( columnsSQL, tmpstr );
				}else{
					columnsSQL = listAppend( columnsSQL, tmpstr );
				}

				if( col.isPrimaryKey ){
					if( structKeyExists( col, 'generator' ) && col.generator eq 'increment' ){
						primaryKeys = listPrepend(primaryKeys, '#getSafeIdentifierStartChar()##col.name##getSafeIdentifierEndChar()#');
					}else{
						primaryKeys = listAppend(primaryKeys, '#getSafeIdentifierStartChar()##col.name##getSafeIdentifierEndChar()#');
					}
				}


			}

			tableSQL &= columnsSQL & ')';

			/*if( listLen( primaryKeys ) ){
				tableSQL &=  ', PRIMARY KEY (#primaryKeys#)';
			}
			tableSQL &= ') ENGINE=InnoDB DEFAULT CHARSET=utf8;';*/

			try{

			getDao().execute( tableSQL );
			}catch(any e){
				writeDump( tableDef.getTableMeta().columns );
				writeDump( e );abort;
			}

			return tabledef;

		}

		/**
	    * I drop a table based on the passed in table name.
	    **/
		public void function dropTable( required string table ) output = false{
			getDao().execute( "
				IF OBJECT_ID('#table#', 'U') IS NOT NULL
  				DROP TABLE [#table#]
  			" );
		}
	</cfscript>
</cfcomponent>