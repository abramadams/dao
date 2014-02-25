<!--- **********************************************************
		Component	: dao.cfc (MySQL Specific)
		Author		: Abram Adams
		Date		: 1/2/2007
		Description	: Targeted database access object that will
		control all MySQL specific database interaction.
		This component will use MySQL syntax to perform general
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
			variables.dsn = arguments.dsn;
			variables.dao = arguments.dao;
			variables.transactionLogFile = arguments.transactionLogFile;
			
			this.useCFQueryParams = arguments.useCFQueryParams;
			
		</cfscript>

		<cfreturn this />

	</cffunction>

	<cffunction name="getUseCFQueryParams" access="public" returntype="boolean" output="false">
		
		<cfreturn this.useCFQueryParams />
		
	</cffunction>

	<cffunction name="getLastID" hint="I return the ID of the last inserted record.  I am MySQL specific." returntype="any" output="false">
	
		<cfset var get = "" />
		
		<cfquery name="get" datasource="#variables.dsn#">
			Select LAST_INSERT_ID() as thekey
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


	<cffunction name="select" hint="I select records from the database.  I am MySQL specific." returntype="query" output="true">
		<cfargument name="sql" required="false" type="string" default="" hint="Either Table to select from or sql statement.">
		<cfargument name="name" required="false" type="string" hint="Name of Query (required for cachedwithin)" default="sel_#listFirst(createUUID(),'-')#">
		<cfargument name="cachedwithin" required="false" type="any" hint="createTimeSpan() to cache this query" default="">
		<cfargument name="table" required="false" type="string" default="" hint="Table name to select from, use only if not using SQL">
		<cfargument name="columns" required="false" type="string" default="" hint="List of valid column names for select statement, use only if not using SQL">
		<cfargument name="where" required="false" type="string" hint="Where clause Only used if sql is a tablename" default="">
		<cfargument name="limit" required="false" type="any" hint="Limit records returned.  Only used if sql is a tablename" default="">
		<cfargument name="offset" required="false" type="any" hint="Offset queried recordset.  Only used if sql is a tablename" default="">
		<cfargument name="orderby" required="false" type="string" hint="Order By columns.  Only used if sql is a tablename" default="">

		<cfset var get = "" />
		<cfset var tmpSQL = "" />
		<cfset var idx = 1 />
		<cfif listlen( arguments.sql, ' ') EQ 1 && !len( trim( arguments.table ) )>
			<cfset arguments.table = arguments.sql/>
		</cfif>
		<cftry>
			<cfif listlen(arguments.sql, ' ') GT 1>
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
				<!--- Table select --->
				<cfif !len( trim( arguments.columns ) ) >
					<cfset arguments.columns = getSafeColumnNames(variables.dao.getColumns(arguments.table))/>
				</cfif>
				<cfif len(trim(arguments.cachedwithin))>
					<cfquery name="get" datasource="#variables.dsn#" cachedwithin="#arguments.cachedwithin#">
						SELECT #getSafeColumnNames(variables.dao.getColumns(arguments.table))# 
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
							ORDER BY <cfqueryparam value="#listFirst( arguments.orderby, ' ')#" cfsqltype="cf_sql_varchar"> <cfqueryparam value="#listRest( arguments.orderby, ' ')#" cfsqltype="cf_sql_varchar">
						</cfif>
						<cfif len( trim( arguments.limit ) ) GT 0 && isNumeric( arguments.limit )>
							LIMIT <cfqueryparam value="#val( arguments.limit )#" cfsqltype="cf_sql_integer"><cfif val( arguments.offset )> OFFSET <cfqueryparam value="#val( arguments.offset )#" cfsqltype="cf_sql_integer"></cfif>
						</cfif>
					</cfquery>
				<cfelse>
					<cfquery name="get" datasource="#variables.dsn#">
						SELECT #arguments.columns#
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
							ORDER BY <cfqueryparam value="#listFirst( arguments.orderby, ' ')#" cfsqltype="cf_sql_varchar"> <cfqueryparam value="#listRest( arguments.orderby, ' ')#" cfsqltype="cf_sql_varchar">
						</cfif>
						<cfif len( trim( arguments.limit ) ) GT 0 && isNumeric( arguments.limit )>
							LIMIT <cfqueryparam value="#val( arguments.limit )#" cfsqltype="cf_sql_integer"><cfif val( arguments.offset )> OFFSET <cfqueryparam value="#val( arguments.offset )#" cfsqltype="cf_sql_integer"></cfif>
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

	<cffunction name="update" hint="I update all fields in the passed table.  I take a tabledef object containing the tablename and column values. I return the record's Primary Key value.  I am MySQL specific." returntype="any" output="true">
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
																											
						WHERE #getSafeColumnName(pk)# = '#qry[pk][currentRow]#'
					</cfsavecontent>
					
					<cfif performUpdate>
						<cfset getDao().execute(upd) />
					</cfif>
				<!---</cftransaction>--->
			</cfoutput>
			<cfcatch type="any">
								 
				<cfthrow errorcode="803-mysql.update" type="bullseye.custom.error" detail="Unexpected Error" message="There was an unexpected error updating the database.  Please contact your administrator. #cfcatch.message#">

			</cfcatch>

		</cftry>


		<cfreturn ret />
	</cffunction>

	
	<!--- GETTERS --->
<!--- Data Definition Functions --->
	<cffunction name="define" hint="I return the structure of the passed table.  I am MySQL specific." returntype="query" access="public" output="true">
		<cfargument name="TableName" required="true" type="string" hint="Table to define.">
		
		<cfset var def = "" />
		
		<cfquery name="def" datasource="#variables.dsn#">
			<!--- DESCRIBE #arguments.tablename# --->
			SHOW FULL COLUMNS FROM #arguments.tablename#
		</cfquery>

		<cfreturn def />
	</cffunction>

	<cffunction name="getTables" hint="I return a list of tables for the current database." returntype="query" access="public" output="true">

		<cfset var tables = read('SHOW TABLES')>
		
		<cfreturn tables />
	</cffunction>

	<cffunction name="getPrimaryKey" hint="I return the primary key column name and type for the passed in table.  I am MySQL specific." returntype="struct" access="public" output="true">
		<cfargument name="TableName" required="true" type="string" hint="Table to return primary key.">

		<cfset var def = define(arguments.tablename) />
		<cfset var ret = structnew() />
		<cfset var get = "" />
		<cftry>
			<cfquery name="get" dbtype="query" maxrows="1">
				SELECT [Field],[Type] from def
				WHERE [Key] = 'PRI'
			</cfquery>		
			<cfcatch type="any">
				<cfquery name="get" dbtype="query" maxrows="1">
					SELECT [column_name] as [field],[column_type] as [type] from def
					WHERE [column_key] = 'PRI'
				</cfquery>
			</cfcatch>
		</cftry>
		<cfset ret.field = get.field>
		<cfset ret.type = getCFSQLType(get.type)>

		<cfreturn ret />

	</cffunction>

	<cffunction name="getPrimaryKeys" hint="I return the primary keys column name and type for the passed in table.  I am MySQL specific." returntype="array" access="public" output="true">
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
			<cfset ret[arrayLen(ret)].type = getCFSQLType(get.type)>
		</cfoutput>
	
		<cfreturn ret />

	</cffunction>
	
	<cffunction name="getSafeColumnNames" access="public" returntype="string" hint="I take a list of columns and return it as a safe columns list with each column wrapped within ``.  This is MySQL Specific." output="true">
		<cfargument name="cols" required="true" type="string">

		<cfset var i = 0 />
		<cfset var columns = "" />
		<cfset var colname = "" />
	
		<cfsavecontent variable="columns">
			<cfoutput>
				<cfloop list="#arguments.cols#" index="colname">
					<cfset i = i + 1>`#colname#`<cfif i lt listLen(cols)>,</cfif>
				</cfloop>
			</cfoutput>
		</cfsavecontent>
		
		<cfreturn columns />

	</cffunction>

	<cffunction name="getSafeColumnName" access="public" returntype="string" hint="I take a single column name and return it as a safe columns list with each column wrapped within ``.  This is MySQL Specific." output="true">
		<cfargument name="col" required="true" type="string">
		
		<cfset var ret = "" />
		
		<cfset ret = "`" & arguments.col & "`" >

		<cfreturn ret />

	</cffunction>
	
	<cfscript>
		/**
	    * @hint I create a table based on the passed in tabledef object's properties.		    
	    **/
		package tabledef function makeTable( required tabledef tabledef ){
			
			var tableSQL = "CREATE TABLE `#tabledef.getTableName()#` (";
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
						tmpstr = '`#col.name#` varchar(#structKeyExists( col, 'length' ) ? col.length : '255'#) #( col.isPrimaryKey || col.isIndex ) ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & col.default & "'": ''#';
					break;
					case 'numeric':
						tmpstr = '`#col.name#` int(#structKeyExists( col, 'length' ) ? col.length : '11'#) unsigned #( col.isPrimaryKey || col.isIndex ) ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & col.default & "'": ''# #structKeyExists(col,'generator') && col.generator eq 'increment' ? ' AUTO_INCREMENT' : ''#';
					break;
					case 'date':
						tmpstr = '`#col.name#` datetime #( col.isPrimaryKey || col.isIndex ) ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & col.default & "'": ''#';
					break;
					case 'tinyint':
						tmpstr = '`#col.name#` tinyint(1) #( col.isPrimaryKey || col.isIndex ) ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & (col.default ? 1 : 0) & "'": ''# #structKeyExists(col,'generator') && col.generator eq 'increment' ? ' AUTO_INCREMENT' : ''#';
					break;
					case 'boolean': case 'bit':
						tmpstr = '`#col.name#` BIT #( col.isPrimaryKey || col.isIndex ) ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT " & (col.default ? true : false) : ''#';
					break;
					case 'text':
						tmpstr = '`#col.name#` text #( col.isPrimaryKey || col.isIndex ) ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & (col.default ? 1 : 0) & "'": ''# #structKeyExists(col,'generator') && col.generator eq 'increment' ? ' AUTO_INCREMENT' : ''#';
					break;
					default:
						tmpstr = '`#col.name#` #col.type# #structKeyExists( col, 'length' ) ? '(' & col.length & ')' : '(255)'# #( col.isPrimaryKey || col.isIndex ) ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & col.default & "'": ''#';
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
						primaryKeys = listPrepend(primaryKeys, '`#col.name#`');
					}else{
						primaryKeys = listAppend(primaryKeys, '`#col.name#`');
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
		
	</cfscript>
</cfcomponent>