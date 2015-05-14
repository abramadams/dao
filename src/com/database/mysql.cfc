<!--- **********************************************************
		Component	: dao.cfc (MySQL Specific)
		Author		: Abram Adams
		Date		: 1/2/2007
		@version 0.0.70
	   	@updated 5/14/2015
		Description	: Targeted database access object that will
		control all MySQL specific database interaction.
		This component will use MySQL syntax to perform general
		database functions.

	  ********************************************************** --->

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
			setUseCFQueryParams( useCFQueryParams );
			// writeDump( [ this, serializeJSON( this ) ] );abort;
		</cfscript>

		<cfreturn this />

	</cffunction>

	<cffunction name="getLastID" hint="I return the ID of the last inserted record.  I am MySQL specific." returntype="any" output="false">

		<cfset var __get = "" />

		<cfquery name="__get" datasource="#getDsn()#">
			Select LAST_INSERT_ID() as thekey
		</cfquery>
		<cfreturn __get.thekey />
	</cffunction>

	<cffunction name="delete" hint="I delete records from the database.  I am MySQL specific." returntype="boolean" output="false">
		<cfargument name="TableName" required="true" type="string" hint="Table to delete from.">
		<cfargument name="recordID" required="true" type="string" hint="Record ID of record to be deleted.">
		<cfargument name="IDField" required="false" type="string" hint="ID field of record to be deleted.">

		<cfset var ret = true />
		<cfset var pk = getPrimaryKey(arguments.tablename) />
		<cfset var del = "" />

		<!--- <cftry> --->
			<cfquery name="del" datasource="#getDsn()#">
				DELETE from #arguments.tablename#
				<cfif not len(trim(arguments.IDField))>
				WHERE #getSafeColumnName(pk.field)# = <cfqueryparam cfsqltype="#getDAO().getCFSQLType(pk.type)#" value="#arguments.recordID#">
				<cfelse>
				WHERE #getSafeColumnName(arguments.idField)# = <cfqueryparam cfsqltype="#getDAO().getCFSQLType(pk.type)#" value="#arguments.recordID#">
				</cfif>
			</cfquery>
			<!--- <cfcatch type="any">
				<cfset ret = false>
			</cfcatch>
		</cftry> --->
		<cfreturn ret />
	</cffunction>

	<cffunction name="deleteAll" hint="I delete all records from the passed tablename.  I am MySQL specific." returntype="boolean" output="false">
		<cfargument name="TableName" required="true" type="string" hint="Table to delete from.">

		<cfset var ret = true />
		<cfset var rel = "" />

		<!--- <cftry> --->
			<cfquery name="del" datasource="#getDsn()#">
				DELETE from #arguments.tablename#
			</cfquery>
			<!--- <cfcatch type="any">
				<cfset ret = false>
			</cfcatch>
		</cftry> --->
		<cfreturn ret />
	</cffunction>


	<cffunction name="select" hint="I select records from the database.  I am MySQL specific." returntype="query" output="false">
		<cfargument name="sql" required="false" type="string" default="" hint="Either Table to select from or sql statement.">
		<cfargument name="name" required="false" type="string" hint="Name of Query (required for cachedwithin)" default="sel_#listFirst(createUUID(),'-')#">
		<cfargument name="cachedwithin" required="false" type="any" hint="createTimeSpan() to cache this query" default="">
		<cfargument name="table" required="false" type="string" default="" hint="Table name to select from, use only if not using SQL">
		<cfargument name="columns" required="false" type="string" default="" hint="List of valid column names for select statement, use only if not using SQL">
		<cfargument name="where" required="false" type="string" hint="Where clause Only used if sql is a tablename" default="">
		<cfargument name="limit" required="false" type="any" hint="Limit records returned.  Only used if sql is a tablename" default="">
		<cfargument name="offset" required="false" type="any" hint="Offset queried recordset.  Only used if sql is a tablename" default="">
		<cfargument name="orderby" required="false" type="string" hint="Order By columns.  Only used if sql is a tablename" default="">

		<cfset var __get = "" />
		<cfset var tmpSQL = "" />
		<cfset var idx = 1 />
		<cfif listlen( arguments.sql, ' ') EQ 1 && !len( trim( arguments.table ) )>
			<cfset arguments.table = arguments.sql/>
		</cfif>
		<cftry>
			<cfif listlen(arguments.sql, ' ') GT 1>
				<cfif len(trim(arguments.cachedwithin))>
					<cfquery name="__get" datasource="#getDsn()#" cachedwithin="#arguments.cachedwithin#" result="results_#name#">
						<!--- #preserveSingleQuotes(arguments.sql)# --->
						<!---
								Parse out the queryParam calls inside the where statement
								This has to be done this way because you cannot use
								cfqueryparam tags outside of a cfquery.
								@TODO: refactor to use the query.cfc
							--->
							<cfset tmpSQL = getDao().parameterizeSQL( arguments.sql )/>
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
					<cfquery name="__get" datasource="#getDsn()#" result="results_#name#">
						<!--- #preserveSingleQuotes(arguments.sql)# --->
						<!---
								Parse out the queryParam calls inside the where statement
								This has to be done this way because you cannot use
								cfqueryparam tags outside of a cfquery.
								@TODO: refactor to use the query.cfc
							--->
							<cfset tmpSQL = getDao().parameterizeSQL( arguments.sql )/>
							<cfloop from="1" to="#arrayLen( tmpSQL.statements )#" index="idx">
								<cfset var simpleValue =  tmpSQL.statements[idx].before />
								#preserveSingleQuotes(simpleValue)#
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
				<!--- Table select --->
				<cfif !len( trim( arguments.columns ) ) >
					<cfset arguments.columns = getSafeColumnNames(getDao().getColumns(arguments.table))/>
				</cfif>
				<cfif len(trim(arguments.cachedwithin))>
					<cfquery name="__get" datasource="#getDsn()#" cachedwithin="#arguments.cachedwithin#" result="results_#name#">
						SELECT <cfif len( trim( arguments.limit ) ) GT 0 && isNumeric( arguments.limit )>SQL_CALC_FOUND_ROWS</cfif>
						#arguments.columns#
						FROM #arguments.table#
						<cfif len( trim( arguments.where ) )>
							<!---
								Parse out the queryParam calls inside the where statement
								This has to be done this way because you cannot use
								cfqueryparam tags outside of a cfquery.
								@TODO: refactor to use the query.cfc
							--->
							<cfset tmpSQL = getDao().parameterizeSQL( arguments.where )/>
							<cfloop from="1" to="#arrayLen( tmpSQL.statements )#" index="idx">
								<cfset var simpleValue =  tmpSQL.statements[idx].before />
								#preserveSingleQuotes(simpleValue)#
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
						<cfif len( trim( arguments.limit ) ) && isNumeric( arguments.limit )>
							LIMIT <cfqueryparam value="#val( arguments.limit )#" cfsqltype="cf_sql_integer"><cfif val( arguments.offset )> OFFSET <cfqueryparam value="#val( arguments.offset )#" cfsqltype="cf_sql_integer"></cfif>
						</cfif>
					</cfquery>
					<cfif len( trim( arguments.limit ) ) GT 0 && isNumeric( arguments.limit )>
						<cfquery name="count" datasource="#variables.dsn#" cachedwithin="#arguments.cachedwithin#">
							select FOUND_ROWS() as found_rows;
						</cfquery>
						<cfquery name="__get" dbtype="query" result="results2_#name#" cachedwithin="#arguments.cachedwithin#">
							SELECT '#count.found_rows#' __count, * FROM __get
						</cfquery>
					</cfif>
				<cfelse>
					<cfquery name="__get" datasource="#getDsn()#" result="results_#name#">
						SELECT <cfif len( trim( arguments.limit ) ) GT 0 && isNumeric( arguments.limit )>SQL_CALC_FOUND_ROWS</cfif>
						#arguments.columns#
						FROM #arguments.table#
						<cfif len( trim( arguments.where ) )>
							<!---
								Parse out the queryParam calls inside the where statement
								This has to be done this way because you cannot use
								cfqueryparam tags outside of a cfquery.
								@TODO: refactor to use the query.cfc
							--->
							<cfset tmpSQL = getDao().parameterizeSQL( arguments.where )/>
							<cfloop from="1" to="#arrayLen( tmpSQL.statements )#" index="idx">
								<cfset var simpleValue =  tmpSQL.statements[idx].before />
								#preserveSingleQuotes(simpleValue)#
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
						<cfif len( trim( arguments.limit ) ) && isNumeric( arguments.limit )>
							LIMIT <cfqueryparam value="#val( arguments.limit )#" cfsqltype="cf_sql_integer"><cfif val( arguments.offset )> OFFSET <cfqueryparam value="#val( arguments.offset )#" cfsqltype="cf_sql_integer"></cfif>
						</cfif>
					</cfquery>
					<cfif len( trim( arguments.limit ) ) GT 0 && isNumeric( arguments.limit )>
						<cfquery name="count" datasource="#variables.dsn#">
							select FOUND_ROWS() as found_rows;
						</cfquery>
						<cfquery name="__get" dbtype="query" result="results_#name#">
							SELECT '#count.found_rows#' __count, * FROM __get
						</cfquery>
					</cfif>
				</cfif>
			</cfif>

			<cfcatch type="any">
				<cfrethrow/>

				<cfdump var="#arguments#" label="Arguments passed to select()">
				<!--- <cfdump var="#getDAO().renderSQLforView(tmpSQL)#" label="parsed SQL Statement"> --->
				<cfdump var="#tmpSQL#" label="parsed SQL Statement">
				<cfdump var="#getDao()#" label="parameterized">
				<cfdump var="#getDao().parameterizeSQL( arguments.where )#" label="parameterized">
				<cfdump var="#cfcatch#" label="CFCATCH Information">
				<!---<cfdump var="#evaluate(arguments.name)#" label="Query results">--->
				<cfsetting showdebugoutput="false">
				<cfabort>
				<cfif cfcatch.detail contains "Unknown column">
					<cfthrow type="DAO.Read.MySQL.UnknownColumn" detail="#cfcatch.detail#" message="#cfcatch.message# #len(trim(arguments.columns)) ? '- Available columns are: #arguments.columns#' : ''#">
				<cfelse>
					<cfthrow type="DAO.Read.MySQL.SelectException" detail="#cfcatch.detail#" message="#cfcatch.message#">
				</cfif>
			</cfcatch>
		</cftry>
		<cfreturn __get />
	</cffunction>

	<cffunction name="write" hint="I insert data into the database.  I take a tabledef object containing the tablename and column values. I return the new record's Primary Key value.  I am MySQL specific." returntype="any" output="false">
		<cfargument name="tabledef" required="true" type="tabledef" hint="TableDef object containing data.">

		<cfset var curRow = 0 />
		<cfset var current = [] />
		<cfset var qry = "" />
		<cfset var columns = "" />
		<cfset var ins = "" />
		<cfset var isnull = "" />
		<cfset var cfsqltype = "cf_sql_varchar" />
		<cfset var tablename = arguments.tabledef.getTableName() />
		<cfset var col = "" />
		<cfset var ret = "" />


		<cfset qry = arguments.tabledef.getRows()/>
		<cfset columns = arguments.tabledef.getNonAutoIncrementColumns() />

		<cfif !qry.recordCount>
			<cfdump var="#arguments#" abort>
		</cfif>
		<cfoutput query="qry">
			<!--- reset current row counter --->
			<cfset curRow = 0>

				<cfsavecontent variable="ins">
					INSERT INTO #tablename# (#getSafeColumnNames(columns)#)
						VALUES (
						<cfloop list="#columns#" index="col">
							<cfset isnull = "false">
							<cfset curRow = curRow +1/>
							<cfset current[curRow] = {}/>
							<cfset current[curRow].colIndex = curRow/>
							<cfset current[curRow].column = col/>
							<cfset current[curRow].data = qry[col][currentRow]/>
							<cfset current[curRow].cfsqltype = arguments.tabledef.getCFSQLType(col)/>

							<!--- push the cfsqltype into a var scope variable that get's reset at the end of this loop --->
							<cfset cfsqltype =  current[curRow].cfsqltype/>
							<cfif current[curRow].cfsqltype is "cf_sql_date" or isDate(current[curRow].data) >
								<cfset current[curRow].cfsqltype = "cf_sql_timestamp">
							</cfif>
							<cfif not len(trim(current[curRow].data))>
								<cfif len(trim(arguments.tabledef.getColumnDefaultValue(col)))>
									<cfset current[curRow].data = arguments.tabledef.getColumnDefaultValue(col)>
								<cfelse>
									<cfset current[curRow].data = arguments.tabledef.getColumnNullValue(col)>
									<cfset isnull = "true">
								</cfif>
							</cfif>
							<cfif not arguments.tabledef.isColumnNullable(col)>
								<cfset isnull = "false">
								<cfif ( current[curRow].cfsqltype contains "date" || current[curRow].cfsqltype contains "time" ) && current[curRow].data eq '0000-00-00 00:00:00' >
									<cfset current[curRow].data = createTime(0,0,0)/>
								</cfif>
							</cfif>
							<cfif curRow GT 1>,</cfif>
							<cfif not len(trim(current[curRow].data))>
								<cfset current[curRow].data = arguments.tabledef.getColumnNullValue(current[curRow].column)>
								<cfif cfsqltype neq "cf_sql_boolean">
									<cfset isnull = "true">
								</cfif>
							</cfif>

							#getDao().queryParam(value=current[curRow].data,cfsqltype=cfsqltype,list='false',null=isnull)#
							<cfset cfsqltype = "bad">
						</cfloop>
						)
				</cfsavecontent>

				<cfset ret = getDao().execute(ins)/>


		</cfoutput>


		<cfreturn ret />
	</cffunction>

	<cffunction name="update" hint="I update all fields in the passed table.  I take a tabledef object containing the tablename and column values. I return the record's Primary Key value.  I am MySQL specific." returntype="any" output="false">
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
									<cfset isnull = false>
									<cfset curRow = curRow +1>


									<cfset value = qry[col][currentRow]/>
									<cfset cfsqltype = arguments.tabledef.getCFSQLType(col)>

									<cfif not len(trim(value))>
										<cfif cfsqltype neq "cf_sql_boolean">
											<cfset isnull = true>
										</cfif>
										<cfset value = arguments.tabledef.getColumnNullValue(col)>
										<cfif not arguments.tabledef.isColumnNullable(col)>
											<cfset isnull = "false">
										</cfif>
										<cfif cfsqltype is "cf_sql_timestamp">
											<cfset isNull = true/>
										</cfif>
									</cfif>
									<cfif ( cfsqltype contains "date" || cfsqltype contains "time" ) && value eq '0000-00-00 00:00:00' >
										<cfset isNull = true/>
									</cfif>
									<!---<cfqueryparam value="#value#" cfsqltype="#cfsqltype#" null="#isnull#">--->
									<!--- <cfif isNull>
										<cfset curRow--/>
									</cfif>
									<cfif !isNull> --->
										<cfif curRow GT 1>, </cfif>#getSafeColumnName(col)# = #getDao().queryParam(value=value,cfsqltype=cfsqltype,list='false',null=isnull)#
									<!--- </cfif> --->
									<cfset value = "">
									<cfset cfsqltype = "">
								</cfif>
							</cfloop>

						WHERE #getSafeColumnName(pk)# = #getDao().queryParam(qry[pk][currentRow])#
						<cfset ret = qry[pk][currentRow] />
					</cfsavecontent>

					<cfif performUpdate>
						<cfset getDao().execute(upd) />
					</cfif>
				<!---</cftransaction>--->
			</cfoutput>
			<cfcatch type="any">
				<cfdump var="#[arguments,qry,cfcatch]#" abort>
				<cfthrow errorcode="803-mysql.update" type="dao.custom.error" detail="Unexpected Error #cfcatch.detail#" message="There was an unexpected error updating the database.  Please contact your administrator. #cfcatch.message#">

			</cfcatch>

		</cftry>


		<cfreturn ret />
	</cffunction>


	<!--- GETTERS --->
<!--- Data Definition Functions --->
	<cffunction name="define" hint="I return the structure of the passed table.  I am MySQL specific." returntype="any" access="public" output="false">
		<cfargument name="TableName" required="true" type="string" hint="Table to define.">

		<cfset var def = "" />

		<cfquery name="def" datasource="#getDsn()#">
			<!--- DESCRIBE #arguments.tablename# --->
			SHOW FULL COLUMNS FROM #arguments.tablename#
		</cfquery>

		<cfreturn def />
	</cffunction>

	<cffunction name="getPrimaryKey" hint="I return the primary key column name and type for the passed in table.  I am MySQL specific." returntype="struct" access="public" output="false">
		<cfargument name="TableName" required="true" type="string" hint="Table to return primary key.">

		<cfset var def = define(arguments.tablename) />
		<cfset var ret = structnew() />
		<cfset var __get = "" />
		<cftry>
			<cfquery name="__get" dbtype="query" maxrows="1">
				SELECT [Field],[Type] from def
				WHERE [Key] = 'PRI'
			</cfquery>
			<cfcatch type="any">
				<cfquery name="__get" dbtype="query" maxrows="1">
					SELECT [column_name] as [field],[column_type] as [type] from def
					WHERE [column_key] = 'PRI'
				</cfquery>
			</cfcatch>
		</cftry>
		<cfset ret.field = get.field>
		<cfset ret.type = getDAO().getCFSQLType( listFirst( get.type, '(' ) )>

		<cfreturn ret />

	</cffunction>

	<cffunction name="getPrimaryKeys" hint="I return the primary keys column name and type for the passed in table.  I am MySQL specific." returntype="array" access="public" output="false">
		<cfargument name="TableName" required="true" type="string" hint="Table to return primary key.">

		<cfset var def = define(arguments.tablename) />
		<cfset var ret = [] />
		<cfset var __get = "" />

		<cfquery name="__get" dbtype="query">
			SELECT [Field],[Type] from def
			WHERE [Key] = 'PRI'
		</cfquery>
		<cfoutput query="__get">
			<cfset arrayAppend(ret, structNew())/>
			<cfset ret[arrayLen(ret)].field = get.field>
			<cfset ret[arrayLen(ret)].type = getDAO().getCFSQLType( listFirst( get.type, '(' ) )>
		</cfoutput>

		<cfreturn ret />

	</cffunction>

	<cfscript>
		/**
		* I take a list of columns and return it as a safe columns list with each column wrapped within ``.  This is MySQL Specific.
		**/
		public string function getSafeColumnNames( required string cols )  output = false {
			var columns = [];
			for( var colName in listToArray( cols ) ){
				var col = "#getSafeIdentifierStartChar()##trim(colName)##getSafeIdentifierEndChar()#";
				col = reReplace( col, "\.", "#getSafeIdentifierStartChar()#.#getSafeIdentifierEndChar()#", "all" );
				col = reReplace( col, "#getSafeIdentifierStartChar()#\*#getSafeIdentifierEndChar()#", "*", "all" );
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
			return '`';
		}
		/**
		* I return the closing escape character for a column name.  This is MySQL Specific.
		* */
		public string function getSafeIdentifierEndChar() output = false{
			return '`';
		}

		/**
	    * I create a table based on the passed in tabledef object's properties.
	    **/
		public tabledef function makeTable( required tabledef tabledef ) output = false{

			var tableSQL = "CREATE TABLE #getSafeIdentifierStartChar()##tabledef.getTableName()##getSafeIdentifierEndChar()# (";
			var columnsSQL = "";
			var primaryKeys = "";
			var indexes = "";
			var autoIncrement = false;
			var tmpstr = "";
			var col = {};


			for ( var colName in tableDef.getTableMeta().columns ){
				col = tableDef.getTableMeta().columns[ colName ];
				col.name = colName;

				switch( col.sqltype ){
					case 'string':
						tmpstr = '#getSafeIdentifierStartChar()##col.name##getSafeIdentifierEndChar()# varchar(#structKeyExists( col, 'length' ) ? col.length : '255'#) #( col.isPrimaryKey || col.isIndex ) ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & col.default & "'": ''#';
					break;
					case 'numeric':
						tmpstr = '#getSafeIdentifierStartChar()##col.name##getSafeIdentifierEndChar()# int(#structKeyExists( col, 'length' ) ? col.length : '11'#) unsigned #( col.isPrimaryKey || col.isIndex ) ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & col.default & "'": ''# #structKeyExists(col,'generator') && col.generator eq 'increment' ? ' AUTO_INCREMENT' : ''#';
					break;
					case 'date':
						tmpstr = '#getSafeIdentifierStartChar()##col.name##getSafeIdentifierEndChar()# datetime #( col.isPrimaryKey || col.isIndex ) ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & col.default & "'": ''#';
					break;
					case 'tinyint':
						tmpstr = '#getSafeIdentifierStartChar()##col.name##getSafeIdentifierEndChar()# tinyint(1) #( col.isPrimaryKey || col.isIndex ) ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & (col.default ? 1 : 0) & "'": ''# #structKeyExists(col,'generator') && col.generator eq 'increment' ? ' AUTO_INCREMENT' : ''#';
					break;
					case 'boolean': case 'bit':
						tmpstr = '#getSafeIdentifierStartChar()##col.name##getSafeIdentifierEndChar()# BIT #( col.isPrimaryKey || col.isIndex ) ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT " & (col.default ? true : false) : ''#';
					break;
					case 'text':
						tmpstr = '#getSafeIdentifierStartChar()##col.name##getSafeIdentifierEndChar()# text #( col.isPrimaryKey || col.isIndex ) ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & (col.default ? 1 : 0) & "'": ''# #structKeyExists(col,'generator') && col.generator eq 'increment' ? ' AUTO_INCREMENT' : ''#';
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

			tableSQL &= columnsSQL;

			if( listLen( primaryKeys ) ){
				tableSQL &=  ', PRIMARY KEY (#primaryKeys#)';
			}
			tableSQL &= ') ENGINE=InnoDB DEFAULT CHARSET=utf8;';


			getDao().execute( tableSQL );

			return tabledef;

		}

		/**
	    * I drop a table based on the passed in table name.
	    **/
		public tabledef function dropTable( required string table ) output = false{
			getDao().execute( "DROP TABLE IF EXISTS `#this.getTable()#`" );
		}
	</cfscript>
</cfcomponent>