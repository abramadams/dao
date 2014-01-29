<!--- **********************************************************
		Component	: dao.cfc (MSSQL Specific)
		Author		: Abram Adams
		Date		: 1/2/2007
		Description	: Targeted database access object that will
		controll all MSSQL specific database interaction.  
		This component will use MSSQL syntax to perform general
		database functions.

	  ********************************************************** --->


<cfcomponent output="false" accessors="true">
	<cfproperty name="dao" type="dao"/>

	<cffunction name="init" access="public" output="false" displayname="DAO Constructor" hint="I initialize MySQL DAO.">
		<cfargument name="dao" type="dao" required="true" hint="DAO object" />
		<cfargument name="dsn" type="string" required="true" hint="Data Source Name" />
		<cfargument name="dbtype" type="string" required="false" hint="Database Type" default="mysql" />
		<cfargument name="user" type="string" required="false" default="" hint="Data Source User Name" />
		<cfargument name="password" type="string" required="false" default="" hint="Data Source Password" />
		<cfargument name="transactionLogFile" type="string" required="false" hint="Database Type" default="#expandPath('/')#sql_transaction_log.sql" />
		<cfargument name="useCFQueryParams" type="boolean" required="false" hint="Determines if execute queries will use cfqueryparam" default="true" />

		<cfscript>
			
			//This is the datasource name for the system
			variables.dsn = Arguments.dsn;
			variables.dao = arguments.dao;
			variables.transactionLogFile = arguments.transactionLogFile;
			
			this.useCFQueryParams = arguments.useCFQueryParams;
			
		</cfscript>

		<cfreturn this />

	</cffunction>
	
	<cffunction name="getUseCFQueryParams" access="public" returntype="boolean" output="false">
		
		<cfreturn this.useCFQueryParams />
		
	</cffunction>


	<cffunction name="getLastID" hint="I return the ID of the last inserted record.  I am MSSQL specific." returntype="numeric" output="true">
		<cfquery name="get" datasource="#variables.dsn#">
			SELECT Scope_Identity() as thekey
		</cfquery>
		<cfreturn get.thekey />
	</cffunction>
	

	<cffunction name="delete" hint="I delete records from the database.  I am MySQL specific." returntype="boolean" output="true">
		<cfargument name="TableName" required="true" type="string" hint="Table to delete from.">
		<cfargument name="recordID" required="true" type="string" hint="Record ID of record to be deleted.">
		<cfargument name="IDField" required="false" type="string" hint="ID field of record to be deleted.">

		<cfset var ret = true />
		<cfset var pk = getPrimaryKey(arguments.tablename) />
		<cfset var del = "" />
		
		<cftry>
			<cfquery name="del" datasource="#variables.dsn#">
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

	<cffunction name="deleteAll" hint="I delete all records from the passed tablename.  I am MySQL specific." returntype="boolean" output="true">
		<cfargument name="TableName" required="true" type="string" hint="Table to delete from.">

		<cfset var ret = true />
		<cfset var rel = "" />

		<cftry>
			<cfquery name="del" datasource="#variables.dsn#">
				DELETE from #arguments.tablename#
			</cfquery>
			<cfcatch type="any">
				<cfset ret = false>
			</cfcatch>
		</cftry>
		<cfreturn ret />
	</cffunction>


	<cffunction name="select" hint="I select records from the database.  I am MSSQL specific." returntype="query" output="true">
		<cfargument name="sql" required="false" type="string" default="" hint="Either Table to select from or sql statement.">
		<cfargument name="name" required="false" type="string" hint="Name of Query (required for cachedwithin)" default="sel_#listFirst(createUUID(),'-')#">
		<cfargument name="cachedwithin" required="false" type="any" hint="createTimeSpan() to cache this query" default="">
		<cfargument name="table" required="false" type="string" default="" hint="Table name to select from, use only if not using SQL">
		<cfargument name="columns" required="false" type="string" default="" hint="List of valid column names for select statement, use only if not using SQL">
		<cfargument name="where" required="false" type="string" hint="Where clause. Only used if sql is a tablename" default="">
		<cfargument name="limit" required="false" type="any" hint="Limit records returned.  Only used if sql is a tablename" default="">
		<cfargument name="orderby" required="false" type="string" hint="Order By columns.  Only used if sql is a tablename" default="">

		<cfset var get = "" />
		<cfif listlen( arguments.sql, ' ') EQ 1 && !len( trim( arguments.table ) )>
			<cfset arguments.table = arguments.sql/>
		</cfif>
		
		<cftry>
			<cfif listlen(trim(arguments.sql), ' ') GT 1>
				<cfif len(trim(arguments.cachedwithin))>
					<cfquery name="get" datasource="#variables.dsn#" cachedwithin="#arguments.cachedwithin#">
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
					<cfquery name="get" datasource="#variables.dsn#">
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
				</cfif>
			<cfelse>
				<cfif len(trim(arguments.cachedwithin))>
					<cfquery name="get" datasource="#variables.dsn#" cachedwithin="#arguments.cachedwithin#">
						SELECT 
						<cfif len( trim( arguments.limit ) ) GT 0 && isNumeric( arguments.limit )>
							TOP #val( arguments.limit )#
						</cfif>	
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
					</cfquery>
				<cfelse>
					<cfquery name="get" datasource="#variables.dsn#">
						SELECT 
						<cfif len( trim( arguments.limit ) ) GT 0 && isNumeric( arguments.limit )>
							TOP #val( arguments.limit )#
						</cfif>	
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
					</cfquery>
				</cfif>
			</cfif>

			<cfcatch type="any">
				<cfdump var="#arguments#" label="Arguments passed to select()">
				<cfdump var="#cfcatch#" label="CFCATCH Information">
				<!---<cfdump var="#evaluate(arguments.name)#" label="Query results">--->
				<cfsetting showdebugoutput="true">
				<cfabort>
			</cfcatch>
		</cftry>
		<cfreturn get />
	</cffunction>

	<cffunction name="write" hint="I insert data into the database.  I take a tabledef object containing the tablename and column values. I return the new record's Primary Key value.  I am MySQL specific." returntype="numeric" output="false">
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
		<cfset columns = arguments.tabledef.getNonPrimaryKeyColumns() />
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
							<cfset curRow = curRow +1>
							<cfset current[curRow] = structNew()>
							<cfset current[curRow].colIndex = curRow>
							<cfset current[curRow].column = col>
							<cfset current[curRow].data = qry[col][currentRow]>
							<cfset current[curRow].cfsqltype = arguments.tabledef.getCFSQLType(col)>
							
							<!--- push the cfsqltype into a var scope variable that get's reset at the end of this loop --->
							<cfset cfsqltype =  current[curRow].cfsqltype>
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

	<cffunction name="update" hint="I update all fields in the passed table.  I take a tabledef object containing the tablename and column values. I return the record's Primary Key value.  I am MySQL specific." returntype="numeric" output="true">
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
										<cfif cfsqltype is "cf_sql_timestamp">
											<cfset cfsqltype = "cf_sql_varchar">
										</cfif>
									</cfif>
										
									<!---<cfqueryparam value="#value#" cfsqltype="#cfsqltype#" null="#isnull#">--->
									#getDao().queryParam(value=value,cfsqltype=cfsqltype,list='false',null=isnull)#
									<cfset value = "">
									<cfset cfsqltype = "">
								</cfif>
							</cfloop>
																											
						WHERE #getSafeColumnName(pk)# = #qry[pk][currentRow]#
					</cfsavecontent>
					
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
				
				 
				<cfthrow errorcode="803-mysql.update" type="bullseye.custom.error" detail="#lp.getGlobalLabel('Unexpected Error')#" message="#lp.getGlobalLabel('There was an unexpected error updating the database.  Please contact your administrator')#. #cfcatch.message#">
				
			</cfcatch>

		</cftry>


		<cfreturn ret />
	</cffunction>

<!--- Data Definition Functions --->
	<cffunction name="define" hint="I return the structure of the passed table.  I am MSSQL specific." returntype="query" output="true">
		<cfargument name="TableName" required="true" type="string" hint="Table to define.">
			
		<cfset var table = new tabledef(arguments.TableName)>
		<cfset var def = table.getTableMeta()>

		<cfreturn def />
	</cffunction>
	
	<cffunction name="getTables" hint="I return a list of tables for the current database." returntype="query" access="public" output="true">

		<cfset var tables = read('SHOW TABLES')>
		
		<cfreturn tables />
	</cffunction>

	<cffunction name="getPrimaryKey" hint="I return the primary key column name and type for the passed in table.  I am MSSQL specific." returntype="struct" output="true">
		<cfargument name="TableName" required="true" type="string" hint="Table to return primary key.">

		<cfset var def = define(arguments.tablename)>
		
		<cfquery name="get" dbtype="query" maxrows="1">
			SELECT [Field],[Type] from def
			WHERE [Key] = 'PRI'
		</cfquery>
		<cfset ret = structnew()>
		<cfset ret.field = get.field>
		<cfset ret.type = getCFSQLType(get.type)>
			
		<cfreturn ret />
		
	</cffunction>
	
	<!--- GETTERS --->
	
	<cffunction name="getSafeColumnNames" access="public" returntype="string" hint="I take a list of columns and return it as a safe columns list with each column wrapped within [].  This is MSSQL Specific." output="true">
		<cfargument name="cols" required="true" type="string">

		<cfset var i = 0>
		
		<cfsavecontent variable="columns">
			<cfoutput>
				<cfloop list="#arguments.cols#" index="name">
					<cfset i = i + 1>[#name#]<cfif i lt listLen(cols)>,</cfif>
				</cfloop>
			</cfoutput>
		</cfsavecontent>
		
		<cfreturn columns />
		
	</cffunction>
	
	<cffunction name="getSafeColumnName" access="public" returntype="string" hint="I take a single column name and return it as a safe columns list with each column wrapped within [].  This is MSSQL Specific." output="true">
		<cfargument name="col" required="true" type="string">

		<cfset var ret = "[" & arguments.col & "]" >

		
		<cfreturn ret />
		
	</cffunction>	
		
</cfcomponent>