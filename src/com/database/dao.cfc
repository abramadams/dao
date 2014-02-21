<!--- **********************************************************
		Component	: dao.cfc
		Author		: Abram Adams
		Date		: 1/2/2007
		Description	: Generic database access object that will
		control all database interaction.  This component will
		invoke database specific functions when needed to perform
		platform specific calls.

		For instance mysql.cfc has MySQL specific syntax
		and routines to perform generic functions like obtaining
		the definition of a table, the interface here is
		define(tablename) and the MySQL function is DESCRIBE tablename.
		To impliment for MS SQL you would need to create a
		mssql.cfc and have MS SQL specific syntax for the
		define(tablename) function that returns a query object.

		EXAMPLES:
			// Create global database connection
			dao = new dao(
						   dsn		= "mydsn",
						   user		= "dbuser",
						   password = "dbpass",
						   dbtype	= "mysql"
						  );

			Function read:
			query = dao.read("users");
			or:
			query = dao.read("
				select name, email 
				from users
				where id = #dao.queryParam(1)#
			");

			Function write:
			NewKey = application.dao.write('insert into users (id) values(1)');

			Function update:
			dao.update("
				update users 
				set name = #dao.queryParam('test','varchar')# 
				where id = #dao.queryParam(12,'int')#
			");

			Function execute:
			results = dao.execute("show databases");

			Function delete:
			dao.delete("users","*");

	  ********************************************************** --->

<cfcomponent displayname="DAO" hint="This component is basically a DAO Factory that will construct the appropriate invokation for the given database type." output="true" accessors="true">
			   
	<cfproperty name="dsn" type="string">	
	<cfproperty name="dbtype" type="string">	
	<cfproperty name="writeTransactionLog" type="boolean">	
			  
	<cffunction name="init" access="public" returntype="DAO" output="false" displayname="DAO Constructor" hint="I initialize DAO.">
		<cfargument name="dsn" type="string" required="true" hint="Data Source Name" />
		<cfargument name="dbtype" type="string" required="false" hint="Database Type" default="mysql" />
		<cfargument name="user" type="string" required="false" default="" hint="Data Source User Name" />
		<cfargument name="password" type="string" required="false" default="" hint="Data Source Password" />
		<cfargument name="writeTransactionLog" type="boolean" required="false" hint="Write transactions to log (for replication)?" default="false" />
		<cfargument name="transactionLogFile" type="string" required="false" hint="Location to write the transaction log" default="#expandPath('/')#sql_transaction_log.sql" />
		<cfargument name="useCFQueryParams" type="boolean" required="false" hint="Determines if execute queries will use cfqueryparam" default="true" />
		
		<cfscript>

			//This is the datasource name for the system
			variables.dsn = arguments.dsn;
			variables.writeTransactionLog = arguments.writeTransactionLog;

			// This will define the type of database you are using (i.e. MySQL, MSSQL, etc)
			variables.dbType = Arguments.dbType;
			this.user=arguments.user;
			this.password=arguments.password;
			
			//This is the actual db specific connection.
			this.conn = createObject("component", variables.dbType);
			this.conn.init( 
					dao = this,
					dsn = variables.dsn, 
					user = arguments.user,
					password = arguments.password,
					dbtype = arguments.dbtype,
					transactionLogFile = arguments.transactionLogFile,
					useCFQueryParams = arguments.useCFQueryParams
					);
			
			variables.transactionLogFile = arguments.transactionLogFile;			
			variables.useCFQueryParams = arguments.useCFQueryParams;
			
			variables.tabledefs = {};			
			
		</cfscript>

		<cfreturn this />
	</cffunction>

	<cffunction name="getLastID" hint="I return the ID of the last inserted record." returntype="any" output="true">

		<cfset var ret = this.conn.getLastID()/>

		<cfreturn ret />
	</cffunction>
	
	<cffunction name="read" hint="I read from the database. I take either a tablename or sql statement as a parameter." returntype="any" output="false">
		<cfargument name="sql" required="false" type="string" default="" hint="Either a tablename or full SQL statement.">
		<cfargument name="name" required="false" type="string" hint="Name of Query (required for cachedwithin)" default="ret_#listFirst(createUUID(),'-')#_#getTickCount()#">
		<cfargument name="QoQ" required="false" type="struct" hint="Struct containing query object for QoQ" default="#{}#">
		<cfargument name="cachedwithin" required="false" type="any" hint="createTimeSpan() to cache this query" default="">
		<cfargument name="table" required="false" type="string" default="" hint="Table name to select from, use only if not using SQL">
		<cfargument name="columns" required="false" type="string" default="" hint="List of valid column names for select statement, use only if not using SQL">
		<cfargument name="where" required="false" type="string" hint="Where clause. Only used if sql is a tablename" default="">
		<cfargument name="limit" required="false" type="any" hint="Limit records returned.  Only used if sql is a tablename" default="">
		<cfargument name="offset" required="false" type="any" hint="Offset queried recordset.  Only used if sql is a tablename" default="">
		<cfargument name="orderby" required="false" type="string" hint="Order By columns.  Only used if sql is a tablename" default="">
		

		<cfset var tmpSQL = "" />
		<cfset var tempCFSQLType = "" />
		<cfset var tempValue = "" />
		<cfset var tmpName = "" />
		<cfset var idx = "" />
		<cfset var LOCAL = {} />

		<cfif !len( trim( arguments.sql ) ) && !len( trim( arguments.table ) )>
			<cfthrow message="You must pass in either a table name or sql statement." />
		</cfif>

		<cfif listlen( arguments.sql, ' ') EQ 1 && !len( trim( arguments.table ) )>
			<cfset arguments.table = arguments.sql/>
		</cfif>

		<!--- <cftry> --->
			<cfif len( trim( arguments.sql ) ) || len( trim( arguments.table ) )>
				<cftimer label="Query: #arguments.name#" type="debug">
				<cfif !structKeyExists( arguments.QoQ, 'query' ) >
						<cfif listlen(arguments.sql, ' ') GT 1>
							<cfif len(trim(arguments.cachedwithin))>								
									<!---
										We need to parse the sql
										statement to find $queryParam()$ calls.  We do this by
										passing the sql to parseQueryParams, which replaces the
										$queryParam()$ function call with a pseudo cfqueryparam that
										we can digest here to build the query.  The returned pseudo
										cfqueryparam tag is structured as follows:

										<cfqueryparam
													cfsqltype="sql data type"  <--- this is converted
																					to cfsqltype using
																					getCFSQLType
													value="actual value" />
										EXAMPLE: $queryParam(value='abc',cfsqltype='varchar')$
										This can also be done prior to sending the SQL statement to this 
										function by calling the queryParam() function directly.
										EXAMPLE: #dao.queryParam(value='abc',cfsqltype='varchar')#
										This direct method is recommended.
									 --->
									<!--- First thing to do is parse the queryparams from the sql statement (if any exist) --->
									<!--- <cfset tmpSQL = parseQueryParams(arguments.sql)/> --->
									
									
									<!--- Now we build the query --->
									<cfquery name="LOCAL.#arguments.name#" datasource="#variables.dsn#" result="results_#arguments.name#">										
										<!--- 
											Parse out the queryParam calls inside the where statement 
											This has to be done this way because you cannot use 
											cfqueryparam tags outside of a cfquery.
											@TODO: refactor to use the query.cfc
										--->
										<cfset tmpSQL = parameterizeSQL( arguments.sql )/>										
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
									
									<!--- Now we build the query --->
									<cfquery name="LOCAL.#arguments.name#" datasource="#variables.dsn#" result="results_#arguments.name#">										
										<!--- 
											Parse out the queryParam calls inside the where statement 
											This has to be done this way because you cannot use 
											cfqueryparam tags outside of a cfquery.
											@TODO: refactor to use the query.cfc
										--->
										<cfset tmpSQL = parameterizeSQL( arguments.sql )/>										
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
							<!--- abstract --->							
							<cfset LOCAL[arguments.name] = this.conn.select( 																
																table = arguments.table,
																columns = arguments.columns,
																name = arguments.name, 
																where = arguments.where,
																orderby = arguments.orderby,
																limit = arguments.limit,
																offset = arguments.offset,
																cachedwithin = arguments.cachedwithin
															)/>
						</cfif>

				<cfelse>
					<cfset setVariable( arguments.qoq.name, arguments.qoq.query)>					
					<cfquery name="LOCAL.#arguments.name#" dbtype="query">
						#PreserveSingleQuotes( sql )#
					</cfquery>
				</cfif>
				</cftimer>
			</cfif>
			<!--- <cfcatch type="any">				
				<cfthrow errorcode="880" type="custom.error" detail="Unexpected Error" message="There was an unexpected error reading from the database.  Please contact your administrator. #cfcatch.message# #chr(10)# #arguments.sql#">
			</cfcatch>
		</cftry> --->
		
		<cfreturn LOCAL[arguments.name]  />
	</cffunction>


	<cffunction name="readFromQuery" hint="I read from another query (query of query). I take a sql statement as a parameter." returntype="query" output="false">
		<cfargument name="sql" required="true" type="string" hint="Full SQL statement.">
		
		<cfset var ret = "" />
		
		<cfif len(trim(arguments.sql))>
			<cfquery name="ret" dbtype="query">
				#PreserveSingleQuotes(sql)#
			</cfquery>
		</cfif>

		<cfreturn ret />
	</cffunction>

	<cffunction name="write" hint="I insert data into the database.  I take a tabledef object containing the tablename and column values. I return the new record's Primary Key value." returntype="any" output="false">
		<cfargument name="tabledef" required="true" type="tabledef" hint="TableDef object containing data.">

			<cfset var ret = 0/>
			<cfset ret = this.conn.write( arguments.tabledef )/>

		<cfreturn ret />
	</cffunction>
	
	<cffunction name="insert" hint="I insert data into a table in the database." returntype="any" access="public" output="false">
		<cfargument name="table" type="string" required="true" hint="Name of table to insert data into.">
		<cfargument name="data" required="true" type="struct" hint="Struct of name value pairs containing data.  Name must match column name.  This could be a form scope">		
		<cfargument name="dryRun" type="boolean" required="false" default="false" hint="for debugging, will dump the data used to insert instead of actually inserting.">
		<cfargument name="onFinish" type="any" required="false" default="" hint="Will execute when finished inserting.  Can be used for audit logging, notifications, post update processing, etc...">

		<cfset var LOCAL = {}/>
					
		<cfif !structKeyExists(variables.tabledefs,arguments.table)>
			<cfset variables.tabledefs[arguments.table] = createObject("component","tabledef").init(tablename=arguments.table,dsn=getDSN())/>
		</cfif>
		<cfset LOCAL.table = duplicate(variables.tabledefs[arguments.table])/>
		
		<cfset LOCAL.columns = LOCAL.table.getColumns()/>
			
		<cfloop list="#LOCAL.columns#" index="LOCAL.column">
			<cfparam name="arguments.data.#LOCAL.column#" default="#LOCAL.table.getColumnDefaultValue(LOCAL.column)#">			
		</cfloop>
				
		<cfscript>
			LOCAL.row = LOCAL.table.addRow();
			for (LOCAL.i=1;LOCAL.i LTE listLen(LOCAL.columns);LOCAL.i++){
				LOCAL.col = listGetAt(LOCAL.columns,LOCAL.i);
				if (structKeyExists(arguments.data,LOCAL.col)){
					if(LOCAL.col eq LOCAL.table.getPrimaryKeyColumn() && LOCAL.table.getTableMeta().columns[LOCAL.col].type != 4 && !len(trim(arguments.data[LOCAL.col]))){
						LOCAL.table.setColumn(column=LOCAL.col,value=createUUID(),row=LOCAL.row);
					}else{						
						LOCAL.table.setColumn(column=LOCAL.col,value=arguments.data[LOCAL.col],row=LOCAL.row);
					}
				}
			}

			/// insert it				
			if (not arguments.dryrun){
				LOCAL.newRecord = this.conn.write(LOCAL.table);
			}
		</cfscript>		

		<cfif arguments.dryrun>
			<cfset dryRun = { "Data" = arguments.data,"Table Instance" = LOCAL.table, "Table Definition" = LOCAL.table.getTableMeta(), "Records to be Inserted" = LOCAL.table.getRows()}/>
			<cfreturn dryRun />			
		</cfif>
		

		<cfif isCustomFunction( onFinish )>
			<cfset LOCAL.callbackData = { "data" = LOCAL.table.getRows(), "ID" = newRecord }/>
			<cfset onFinish( LOCAL.callbackData )/>
		</cfif>

		<cfreturn LOCAL.newRecord />
		
	</cffunction>

	<cffunction name="bulkInsert" hint="I insert data into the database.  I take a tabledef object containing the tablename and column values. I return the number of records inserted." returntype="any" output="false">
		<cfargument name="tabledef" required="true" type="tabledef" hint="TableDef object containing data.">

		<cfset var qry = arguments.tabledef.getRows()/>

		<cfset this.conn.write(arguments.tabledef)/>


		<cfreturn qry.recordcount />
	</cffunction>

	<cffunction name="update" hint="I update data in a table in the database." returntype="any" access="public" output="false">
		<cfargument name="table" type="string" required="true" hint="Name of table to update data from.">
		<cfargument name="data" required="true" type="struct" hint="Struct of name value pairs containing data.  Name must match column name.  This could be a form scope">
		<cfargument name="IDField" required="false" type="string" default="ID" hint="The name of the Primary Key column in the table.">
		<cfargument name="ID" required="false" type="string" default="" hint="The value of the Primary Key column in the table.">				
		<cfargument name="dryRun" type="boolean" required="false" default="false" hint="for debugging, will dump the data used to insert instead of actually inserting.">
		<cfargument name="onFinish" type="any" required="false" default="" hint="Will execute when finished updating.  Can be used for audit logging, notifications, post update processing, etc...">
		
		<cfset var LOCAL = {}/>
	
		<cfset LOCAL.isDirty = false/>
		
		<!--- Check for the tabledef object for this table, if it doesn't already exist, create it --->
		<cfif !structKeyExists(variables.tabledefs,arguments.table)>
			<cfset variables.tabledefs[arguments.table] = createObject("component","tabledef").init(tablename=arguments.table,dsn=getDSN())/>
		</cfif>
		<cfset LOCAL.table = duplicate(variables.tabledefs[arguments.table])/>
		
		<cfset LOCAL.columns = LOCAL.table.getColumns()/>
		
		<cfset LOCAL.currentData = this.read("
			SELECT #LOCAL.columns#
			FROM #arguments.table#
			WHERE #LOCAL.table.getPrimaryKeyColumn()# = #this.queryParam(value=arguments.data[LOCAL.table.getPrimaryKeyColumn()],cfsqltype=local.table.instance.tablemeta.columns[LOCAL.table.getPrimaryKeyColumn()].type eq 4 ? 'int' : 'varchar')#
		")>
		
		<cfloop list="#LOCAL.columns#" index="LOCAL.column">
			<cfif len(trim(LOCAL.currentData[LOCAL.column][1]))>
				<!--- 
					If the form field for this column was not passed in, 
					but the column has a value in the DB, let's use that 
				--->
				<cfparam name="arguments.data.#LOCAL.column#" default="#LOCAL.currentData[LOCAL.column][1]#">
			<cfelseif len(trim(LOCAL.table.getColumnDefaultValue(LOCAL.column))) and LOCAL.table.getColumnDefaultValue(LOCAL.column) NEQ '0000-00-00 00:00:00' and LOCAL.table.getColumnDefaultValue(LOCAL.column) NEQ 'NULL'>
				<!--- 
					If the form field for this column was not passed in 
					and the column doesn't have a value, pass the default value 
				--->
				<cfparam name="arguments.data.#LOCAL.column#" default="#LOCAL.table.getColumnDefaultValue(LOCAL.column)#">		
			</cfif>
		
			<cfif structKeyExists(arguments.data,LOCAL.column) 
				&& compare(LOCAL.currentData[LOCAL.column][1].toString(), arguments.data[LOCAL.column].toString())>
				<!--- 
						This will cause dao.update to only update the columns that have changed.  
						This will not only make the update slightly faster, but it will cut down
						the transaction log size for offline replication.  						
				--->
				<cfset LOCAL.table.setColumnIsDirty(
						column = LOCAL.column, 
						isDirty = true
				)/>
				<cfset LOCAL.isDirty = true/>			
			</cfif>
			
		</cfloop>		
	
		<!---
			This will loop through each column and create a table object (see tabledef.cfc)
			with the form values.
			NOTE: The Primary Key field will be updated.  The form.ID variable will be used for
			this value so either make sure it is the ID for the table, or pass the attribute "ID"
			with the ID value to be used.
		 --->
		<cfscript>
			LOCAL.row = LOCAL.table.addRow();
			LOCAL.pk = LOCAL.table.getPrimaryKeyColumn();
			for (LOCAL.i=1;LOCAL.i LTE listLen(LOCAL.columns);LOCAL.i++){
				LOCAL.col = listGetAt(LOCAL.columns,LOCAL.i);
				if (len(trim(arguments.ID)) and LOCAL.col is LOCAL.pk){
					LOCAL.table.setColumn(column=LOCAL.col,value=arguments.id,row=LOCAL.row);					
				}else if (structKeyExists(arguments.data,LOCAL.col)){
					LOCAL.table.setColumn(column=LOCAL.col,value=arguments.data[LOCAL.col],row=LOCAL.row);					
				}
		
			}
			//update it
			if (not arguments.dryrun){
				this.updateTable(LOCAL.table);
			}
		</cfscript>
		<cfif arguments.dryrun>
			<cfset dryRun = { "Data" = arguments.data, "Table Definition" = LOCAL.table.getTableMeta(), "Records to Update" = LOCAL.table.getRows()}/>			
			<cfreturn dryRun />
		</cfif>
		
		<cfif isCustomFunction( onFinish )>
			<cfset LOCAL.callbackData = { "data" = LOCAL.table.getRows(), "id" = LOCAL.table.getRows()[IDField] }/>
			<cfset onFinish( LOCAL.callbackData )/>
		</cfif>

		<cfreturn val(arguments.ID) />
	</cffunction>

	<cffunction name="updateTable" hint="I update data in the database.  I take a tabledef object containing the tablename and column values. I return the record's Primary Key value." returntype="numeric" output="false">
		<cfargument name="tabledef" required="true" type="tabledef" hint="TableDef object containing data.">
		<cfargument name="columns" required="false" type="string" hint="Optional list columns to be updated." default="">
		<cfargument name="IDField" required="false" type="string" hint="Optional ID field." default="">

		<cfset var ret = "" />
		
		<cfif !len(trim(arguments.IDField))>
			<cfset arguments.IDField = arguments.tabledef.getPrimaryKeyColumn()/>
		</cfif>
		<cfset ret = this.conn.update(tabledef=arguments.tabledef,columns=arguments.columns,IDField=arguments.IDField)>
		

		<cfreturn ret />
	</cffunction>

	<cffunction name="bulkUpdate" hint="I update data in the database.  I take a tabledef object containing the tablename and column values. I return the number of records updated." returntype="numeric" output="false">
		<cfargument name="tabledef" required="true" type="tabledef" hint="TableDef object containing data.">

		<cfset var qry = arguments.tabledef.getRows() />
		<cfset var curRow = 0 />
		<cfset var cols = arguments.tabledef.getNonAutoIncrementColumns() />
		<cfset var pk = arguments.tabledef.getPrimaryKeyColumn() />
		<cfset var ins = "" />
		<cfset var col = "" />
		
		<cfoutput query="qry">
			<cfset curRow = 0>
 			<cftransaction>
				<cfquery name="ins" datasource="#variables.dsn#">
					update #arguments.tabledef.getTableName()#
					set
						<cfloop list="#arguments.tabledef.getNonAutoIncrementColumns()#" index="col">
							<cfset curRow = curRow +1>
							#getSafeColumnName(col)# = <cfqueryparam value="#evaluate(col)#" cfsqltype="#arguments.tabledef.getCFSQLType(col)#"><cfif curRow lt listLen(arguments.tabledef.getNonAutoIncrementColumns())>,</cfif>
						</cfloop>
					where #pk# = #evaluate(pk)#
				</cfquery>
			</cftransaction>
		</cfoutput>
		<cfreturn qry.recordcount />
	</cffunction>

	<cffunction name="delete" hint="I delete data in the database.  I take the table name and either the ID of the record to be deleted or a * to indicate delete all." returntype="boolean" output="false">
		<cfargument name="table" required="true" type="string" hint="Table to delete from.">
		<cfargument name="recordID" required="true" type="string" hint="Record ID of record to be deleted. Use * to delete all.">
		<cfargument name="IDField" required="false" type="string" hint="ID Field of record to be deleted. Default value = table's Primary Key." default="">
		<cfargument name="onFinish" type="any" required="false" default="" hint="Will execute when finished deleting.  Can be used for audit logging, notifications, post update processing, etc...">

		<cfset var ret = true>
 		<cftry>
			<cftransaction>

				<cfif arguments.RecordID is "*">
					<cfset ret = this.conn.deleteall(tablename=arguments.table)>
				<cfelse>
					<cfset ret = this.conn.delete(tablename=arguments.table,recordid=arguments.recordid,idField=arguments.idfield)>
				</cfif>

			</cftransaction>
			<cfcatch type="any">
				<cfset ret = false>
			</cfcatch>
		</cftry>

		<cfif isCustomFunction( onFinish )>
			<cfset LOCAL.callbackData = { "ID" = arguments.recordID }/>
			<cfset onFinish( LOCAL.callbackData )/>
		</cfif>

		<cfreturn ret />

	</cffunction>


	<cffunction name="markDeleted" hint="I mark the record as deleted.  I take the table name and either the ID of the record to be deleted or a * to indicate delete all." returntype="boolean" output="false">
		<cfargument name="table" required="true" type="string" hint="Table to delete from.">
		<cfargument name="recordID" required="true" type="string" hint="Record ID of record to be deleted. Use * to delete all.">
		<cfargument name="IDField" required="false" type="string" hint="ID Field of record to be deleted. Default value = table's Primary Key." default="ID">
		<cfargument name="userID" required="false" type="numeric" hint="User ID of user performing delete." default="ID">		

		<cfset var ret = true>
 		<cftry>

			<cfif arguments.RecordID is "*">
				<cfset ret = this.conn.execute("
					UPDATE #arguments.table# 
					SET status = #this.getDeleteStatusCode()#, 
					modified_datetime = #createODBCDateTime(now())#, 
					modified_by_users_ID = #queryParam(value=arguments.userID,cfsqltype='integer')# 					
					")>
				<!--- can't do a delete comment to the entire table. --->
			<cfelse>
				<cfset ret = this.conn.execute("
					UPDATE #arguments.table# 
					SET status = #this.getDeleteStatusCode()#, 
					modified_datetime = #createODBCDateTime(now())#, 
					modified_by_users_ID = #queryParam(value=arguments.userID,cfsqltype='integer')#
					WHERE  #arguments.IDfield# = #queryParam(value=arguments.recordID,cfsqltype='integer')#
					")>
				<cfset ret = this.conn.execute("
					INSERT INTO deleted_records (`table`, `record_ID`,`deleted_by_users_ID`,`deleted_datetime`,`delete_comment`)
						VALUES (#queryParam(value=arguments.table,cfsqltype='varchar')#,#queryParam(value=arguments.recordID,cfsqltype='integer')#,#queryParam(value=arguments.userID,cfsqltype='integer')#,#createODBCDateTime(now())#,#queryParam(value=arguments.deleteComment,cfsqltype='varchar')#)
				")>
			</cfif>

			<cfcatch type="any">		
				<cfthrow errorcode="805" type="custom.error" detail="Unexpected Error" message="There was an unexpected error updating the database.  Please contact your administrator.">
				<cfset ret = false>
			</cfcatch>
		</cftry>

		<cfreturn ret />

	</cffunction>
		
	<cffunction name="logTransaction" returntype="void" output="false">
		<cfargument name="sql" required="true" type="string">
		<cfargument name="lastID" required="false" type="string">
		
		<!--- Duck out if we were told not to write the transaction log --->
		<cfif !getWriteTransactionLog()>
			<cfreturn />
		</cfif>

		<cfset var LOCAL = structNew()/>
		
		<!--- Transaction logging: --->
		<!---
			For push style replication we need to capture each data
			altering statement.  In the case of inserts, we need
			to also include the ID that was created when we 
			locally inserted the record.  This will be inserted
			on the server, and when the server repliates the data
			back to the client, they will be skipped because they
			already exist (per my.ini config setting: 
			"slave-skip-errors = 1062" which skips duplicate 
			record errors when replicating.)  
		 --->			 
		<cfif reFindNoCase('INSERT(.*?)INTO',arguments.sql)>
			<!--- Now let's inspect the sql to determine the table name --->
			<cfset LOCAL.tableName = reReplaceNoCase(arguments.sql,'(.*?)INSERT(.*?)INTO (.*?)\((.*)','\3','one')/>
			<!--- 
				With the table name we can now find out what field is the primary key
				field.  This is sort of a limitation of this routine, as it only supports 
				one primary key insertion.  This should be fine though as MySQL only allows 
				one auto incrementing field, which means that if we had more than one
				primary key we would be creating it on the client side anyway and we'd
				already know it and it would already be in the sql statement, thus no
				need to do anything with it. 
			--->
			
			<cfset LOCAL.PKInfo = getPrimaryKey(LOCAL.tableName)/>
			<cfset LOCAL.primaryKey = LOCAL.PKInfo.field/>
			<cfset LOCAL.primaryKeyType = LOCAL.PKInfo.type/>		
					
			<cfif len(trim(LOCAL.primaryKey)) AND NOT reFindNoCase('\b#LOCAL.primaryKey#\b',arguments.sql)>
				<cfset LOCAL.tmpSQL = reReplaceNoCase(arguments.sql,'INSERT(.*?)INTO (.*?)\(','REPLACE INTO \2(`' & LOCAL.primaryKey & '`, ','one')/>
				<cfset LOCAL.tmpSQL = reReplaceNoCase(LOCAL.tmpSQL,'VALUES(.*?)\(',"VALUES (" & queryParam(value=arguments.lastID, cfsqltype='int',list='false',null='false') & ", ",'one')/><!--- #LOCAL.primaryKeyType# --->
				<cfset arguments.sql = LOCAL.tmpSQL />
			</cfif>
		</cfif>		
		
		<cfif not directoryExists(getDirectoryFromPath(expandPath(transactionLogFile)))>
			<cfdirectory action="create" directory="#getDirectoryFromPath(expandPath(transactionLogFile))#" mode="775">
		</cfif>
		<cfif not fileExists(transactionLogFile)>
			<cffile action="write" file="#transactionLogFile#" output="" mode="664" addnewline="false" charset="utf-8">
		</cfif>
		<!--- Count lines in file to get a sequence number --->
		<cfscript>
		    LOCAL.file = createObject("java","java.io.File").init(javacast("string",transactionLogFile));
		    LOCAL.fileReader = createObject("java","java.io.FileReader").init(LOCAL.file);
			LOCAL.reader = createObject("java","java.io.LineNumberReader").init(LOCAL.fileReader);				
			LOCAL.reader.skip(LOCAL.file.length());
			LOCAL.lines = LOCAL.reader.getLineNumber();
			LOCAL.fileReader.close();
			LOCAL.reader.close();
		</cfscript>
		<!--- Strip out line feeds, tabs and multiple spaces --->
		<cfset LOCAL.content = "#trim(reReplaceNoCase(arguments.sql,chr(9),' ','all'))#"/>
		<cfset LOCAL.content = reReplaceNoCase(LOCAL.content,chr(10),' ','all')/>
		<cfset LOCAL.content = reReplaceNoCase(LOCAL.content,'[[:space:]]{2,2}',' ','all')/>
		<cfset LOCAL.content = "#lines+1##chr(444)##now()##chr(444)##this.getDSN()##chr(444)##createUUID()##chr(444)##trim(LOCAL.content)##chr(10)#">
		<cffile action="append" file="#transactionLogFile#" output="#encrypt(LOCAL.content,'0E69C1BB-BABA-4D48-A7C9D60D020485B0')##chr(555)#" addnewline="false" mode="664" charset="utf-8">
		

	</cffunction>

	<cffunction name="execute" hint="I execute database commands that do not return data.  I take an SQL execute command and return 0 for failure, 1 for success, or the last inserted ID if it was an insert." returntype="any" output="false">
		<cfargument name="sql" required="true" type="string" hint="SQL command to execute.  Can be any valid SQL command.">
		<cfargument name="writeTransactionLog" required="false" default="#this.getWriteTransactionLog() eq true#" type="boolean" hint="Do you want to write the executed statement to the transaction log?">
				
		<cfset var ret = 0 />
		<cfset var exec = "" />
		<cfset var LOCAL = structNew() />
		<cfset var result = {}/>
 		<cftry>
							
				<!---
					We need to parse the sql
					statement to find $queryParam()$ calls.  We do this by
					passing the sql to parseQueryParams, which replaces the
					$queryParam()$ function call with a pseudo cfqueryparam that
					we can digest here to build the query.  The returned pseudo
					cfqueryparam tag is structured as follows:

					<cfqueryparam
								cfsqltype="sql data type"  <--- this is converted
																to cfsqltype using
																getCFSQLType
								value="actual value" />
								
					EXAMPLE: $queryParam(value='abc',cfsqltype='varchar')$
					This can also be done prior to sending the SQL statement to this 
					function by calling the queryParam() function directly.
					EXAMPLE: #dao.queryParam(value='abc',cfsqltype='varchar')#
					This direct method is recommended.					
				 --->
				<!--- First thing to do is replace the <cfqueryparam with a delimiter chr(999) --->
				<cfset LOCAL.tmpSQL = parseQueryParams(arguments.sql)>
				<!--- Now we build the query --->			
				
			 	<cfquery datasource="#variables.dsn#" result="LOCAL.result">
					<!--- The first position of the tmpSQL list will be the first section of SQL code --->
					#listFirst(preserveSingleQuotes(LOCAL.tmpSQL),chr(998))#
					<!--- Now, we loop through the rest of the tmpSQL to build the cfqueryparams --->	
					<cfloop list="#listDeleteAt(LOCAL.tmpSQL,1,chr(998))#" delimiters="#chr(998)#" index="LOCAL.idx">
						<!---
							This will return the position and length of the cfsqltype
							We use this to extract the values for the actual cfqueryparam
						--->
						<cfset LOCAL.tempCFSQLType = reFindNoCase('cfsqltype\=#chr(777)#(.*?)#chr(777)#',LOCAL.idx,1,true)>
						<!--- A little regex to extract the value from the queryparam string  --->												
						<cfset LOCAL.value = reReplaceNoCase(PreserveSingleQuotes(LOCAL.idx),'.*value\=#chr(777)#(.*?)#chr(777)#.*','\1','all')>
						<!--- Strip out any loose hanging special characters used for temporary delimiters (chr(999) and chr(777)) --->
						<cfset LOCAL.value = reReplaceNoCase(preserveSingleQuotes(LOCAL.value),chr(999),'','all')>	
						
						<!--- We'll look for the list and null attributes to see if they exist and then extract their values --->
						<cfset LOCAL.tempList = reFindNoCase('list\=#chr(777)#(.*?)#chr(777)#',LOCAL.idx,1,true)>
						<cfif NOT arrayLen(LOCAL.tempList.pos) GTE 2 OR NOT isBoolean(mid(LOCAL.idx,LOCAL.tempList.pos[2],LOCAL.tempList.len[2]))>
							<cfset LOCAL.isList = false />
						<cfelse>
							<cfset LOCAL.isList = mid(LOCAL.idx,LOCAL.tempList.pos[2],LOCAL.tempList.len[2])/>
						</cfif>
						<cfset LOCAL.tempNull = reFindNoCase('null\=#chr(777)#(.*?)#chr(777)#',LOCAL.idx,1,true)>
						<cfif NOT arrayLen(LOCAL.tempNull.pos) GTE 2 OR NOT isBoolean(mid(LOCAL.idx,LOCAL.tempNull.pos[2],LOCAL.tempNull.len[2]))>
							<cfset LOCAL.isNull = false />
						<cfelse>
							<cfset LOCAL.isNull = mid(LOCAL.idx,LOCAL.tempNull.pos[2],LOCAL.tempNull.len[2])/>
						</cfif>		
						
						<cfset LOCAL.cfSQLType = mid(LOCAL.idx,LOCAL.tempCFSQLType.pos[2],LOCAL.tempCFSQLType.len[2])/>
						
						<cfif getUseCFQueryParams()>
							<!--- Now write the cfqueryparam --->							
							<cfqueryparam 
								cfsqltype="#LOCAL.cfSQLType#" 
								value="#LOCAL.value#" 
								list="#LOCAL.isList#"
								null="#LOCAL.isNull#">
						<cfelse>
							#this.getNonQueryParamFormattedValue(
													value = LOCAL.value, 
													cfsqltype = LOCAL.cfSQLType, 
													list = LOCAL.isList, 
													null = LOCAL.isNull)#
							
						</cfif>										
						<!--- Now anything after the closing > should be  --->
					 	<cfif len(listLast(preserveSingleQuotes(LOCAL.idx),chr(999)))> #listLast(preserveSingleQuotes(LOCAL.idx),chr(999))#</cfif>
					</cfloop>
				</cfquery>	
						
				<!--- Grab the last inserted ID if it was an insert --->
				<cfif refindNoCase('INSERT(.*?)INTO (.*?)\(',LOCAL.tmpSQL)>
					
					<cfif structkeyExists(LOCAL.result,'GENERATED_KEY')>

						<cfset LOCAL.lastInsertedID = LOCAL.result.GENERATED_KEY/>

					<cfelse>

						<cfset LOCAL.lastInsertedID = getLastID()/>						
	
					</cfif>
					
					<cfset ret = LOCAL.lastInsertedID/>	
					
				<cfelse>
					<cfset LOCAL.lastInsertedID = 1/>
					<cfset ret = 1/>
					
				</cfif>
				
						
			<!--- Now write to the transaction log --->
			<cfif arguments.writeTransactionLog>			
				<cfset this.logTransaction(arguments.sql,LOCAL.lastInsertedID)/>
			</cfif>
			<cfcatch type="database">
				<cfif findNoCase('Invalid data',cfcatch.Message)>
					<cfheader statuscode="500"/>
					<cfthrow errorcode="801" type="custom.error" detail="Invalid Data Type" message="The value: &quot;#cfcatch.value#&quot; was expected to be of type: &nbsp;#listLast(cfcatch.sql_type,'_')#.  Please correct the values and try again.">
				<cfelse>
					<cfrethrow>				
				</cfif>
			</cfcatch>
			<cfcatch type="any">
				<cfthrow errorcode="802-dao.execute" type="custom.error" detail="Unexpected Error" message="There was an unexpected error updating the database.  Please contact your administrator. #cfcatch.message#">
				<cfset ret = 0/>
			</cfcatch>
		</cftry>

		<cfreturn ret />

	</cffunction>

	

	<!--- Database Generic Functions --->

	<cffunction name="prepareNonQueryParamValue" returntype="string" output="false" hint="I prepare a parameter value for SQL execution when not using cfqueryparam.  Basically I try to do the same thing as cfqueryparam.">	
		<cfargument name="value" type="string" required="true">
		<cfargument name="cfsqltype" type="string" required="true">
		<cfargument name="null" type="boolean" required="true">
		
		<cfset var LOCAL = {}/>
		
		<cfif arguments.cfSQLType is "cf_sql_timestamp" or arguments.cfSQLType is "cf_sql_date">
			<cfif arguments.value is "0000-00-00 00:00">
				<cfset LOCAL.ret = "'#arguments.value#'"/>
			<cfelseif isDate(arguments.value)>
				<cfset LOCAL.ret = createODBCDateTime(arguments.value)/>
			<cfelse>
				<cfset LOCAL.ret = "'0000-00-00 00:00'"/>
			</cfif>
		<cfelseif arguments.cfSQLType is "cf_sql_integer">
			<cfset LOCAL.ret = val(arguments.value)/>
		<cfelseif arguments.cfSQLType is "cf_sql_boolean">
			<cfset LOCAL.ret = val(arguments.value)/>
		<cfelseif isSimpleValue(arguments.value)>
			<cfset LOCAL.ret = "'#arguments.value#'"/>
		</cfif>
		
		<cfreturn LOCAL.ret />
		
	</cffunction>
	
	<cffunction name="getNonQueryParamFormattedValue"  returntype="string" output="false" hint="I prepare a parameter value for SQL execution when not using cfqueryparam.  Basically I try to do the same thing as cfqueryparam.">
		<cfargument name="value" type="string" required="true">
		<cfargument name="cfsqltype" type="string" required="true">
		<cfargument name="list" type="string" required="true">
		<cfargument name="null" type="boolean" required="true">
		
		<cfset var LOCAL = {}/>
		
		<cfif arguments.list>
			<cfloop list="#arguments.value#" index="LOCAL.idx">
				<cfset LOCAL.ret = listAppend(LOCAL.ret,
					prepareNonQueryParamValue(
						value = listGetAt(arguments.value,LOCAL.idx),
						cfsqltype = arguments.cfsqltype,
						null = arguments.null			
					))/>
			</cfloop>
		<cfelse>
			<cfset LOCAL.ret = 
					prepareNonQueryParamValue(
						value = arguments.value,
						cfsqltype = arguments.cfsqltype,
						null = arguments.null			
					)/>		
		</cfif>		
		
		<cfreturn LOCAL.ret />
		
	</cffunction>
	
	<cffunction name="getCFSQLType" returntype="string" hint="I determine the CFSQL type for the passd value and return the proper type as a string to be used in cfqueryparam." output="false">
		<cfargument name="type" required="true">

		<cfset var int_types = "int,integer,numeric,number,cf_sql_integer">
		<cfset var string_types = "varchar,char,text,memo,nchar,nvarchar,ntext,cf_sql_varchar">
		<cfset var date_types = "datetime,date,cf_sql_date">
		<cfset var decimal_types = "decimal,cf_sql_decimal">
		<cfset var money_types = "money,cf_sql_money">
		<cfset var timestamp_types = "timestamp,cf_sql_timestamp">
		<cfset var double_types = "double,cf_sql_double">
		<cfset var bit_types = "bit">
		<!--- Default return = varchar --->
		<cfset var ret = "cf_sql_varchar">

		
		<cfset var ret = arguments.type/>

		<cfif listFindNoCase(int_types,arguments.type)>
			<cfset ret = "cf_sql_integer">
		<cfelseif listFindNoCase(string_types,arguments.type)>
			<cfset ret = "cf_sql_varchar">
		<cfelseif listFindNoCase(date_types,arguments.type)>
			<cfset ret = "cf_sql_date">
		<cfelseif listFindNoCase(decimal_types,arguments.type)>
			<cfset ret = "cf_sql_decimal">
		<cfelseif listFindNoCase(money_types,arguments.type)>
			<cfset ret = "cf_sql_money">
		<cfelseif listFindNoCase(double_types,arguments.type)>
			<cfset ret = "cf_sql_double">
		<cfelseif listFindNoCase(timestamp_types,arguments.type)>
			<cfset ret = "cf_sql_timestamp">
		<cfelseif listFindNoCase(bit_types,arguments.type)>
			<cfset ret = "cf_sql_bit">
		</cfif>

		<cfreturn ret />
	</cffunction>

	<!--- setters --->
	
	<cffunction name="setUseCFQueryParams" access="public" returntype="void" output="false">
		<cfargument name="useCFQueryParams" type="boolean" required="true">
		
		<cfset this.useCFQueryParams = arguments.useCFQueryParams/>
		<cfset this.conn.useCFQueryParams = arguments.useCFQueryParams/>
		
	</cffunction>
	
	<cffunction name="getUseCFQueryParams" access="public" returntype="boolean" output="false">
		
		<cfreturn this.conn.getUseCFQueryParams() />
		
	</cffunction>
	
	<cffunction name="setUpdate" returntype="void" hint="I build a container to be passed to the update function." output="false">
		<cfargument name="table" required="true" type="string" hint="Table to perform action against.">
		<cfargument name="key" required="true" type="any" hint="Primary Key Index value.">
		<cfargument name="col_value" required="true" type="struct" hint="Column and Value pairs as a struct.">

	</cffunction>

	<cffunction name="define" hint="I return the structure of the passed table.  I am MySQL specific." returntype="query" access="public" output="false">
		<cfargument name="table" required="true" type="string" hint="Table to define.">

		<cfset var def = this.conn.define(arguments.table)>

		<cfreturn def />
	</cffunction>

	<cffunction name="getColumnType" hint="I return the datatype for the given table.column.  I am MySQL specific." returntype="string" access="public" output="false">
		<cfargument name="table" required="true" type="string" hint="Table to define.">
		<cfargument name="column" required="true" type="string" hint="Column to define.">

		<cfset var def = define(arguments.table)>
		<cfset var col = "">
		<cfset var ret = "">
		
		<cfquery name="col" dbtype="query">
			SELECT * FROM def
			WHERE field = '#arguments.column#'
		</cfquery>
		<cfif find('(',col.type)>
			<cfset ret = listFirst(col.type,'(')>
		<cfelse>
			<cfset ret = col.type>
		</cfif>

		<cfreturn ret />
	</cffunction>
    
    <cffunction name="getTables" hint="I return a list of tables for the current database." returntype="query" access="public" output="false">

		<cfset var tables = this.conn.getTables()>

		<cfreturn tables />
	</cffunction>

	<cffunction name="getColumns" hint="I return a list of columns for the passed table." returntype="string" access="public" output="false">
		<cfargument name="table" required="true" type="string" hint="Table to define.">
	
		<cfset var def = new tabledef(tablename=arguments.table,dsn=variables.dsn)/>
		<cfset var cols = def.getColumns()>
		
		<cfif !len(trim(cols))>
			<cfset cols = "*"/>
		</cfif>

		<cfreturn cols />
	</cffunction>
	
	<cffunction name="getPrimaryKey" hint="I get the primary key for the given table. To do this I envoke the getPrimaryKey from the conneted database type." output="false">
		<cfargument name="table" required="true" type="string">
	
		<cfreturn this.conn.getPrimaryKey(arguments.table)/>
	
	</cffunction>
	
	<cffunction name="getSafeColumnNames" access="public" returntype="string" hint="I take a list of columns and return it as a safe columns list with each column wrapped within ``.  This is MySQL Specific." output="false">
		<cfargument name="cols" required="true" type="string">

			<cfset var columns = this.conn.getSafeColumnNames( arguments.cols )/>

		<cfreturn columns />

	</cffunction>

	<cffunction name="getSafeColumnName" access="public" returntype="string" hint="I take a single column name and return it as a safe columns list with each column wrapped within ``.  This is MySQL Specific." output="false">
		<cfargument name="col" required="true" type="string">

		<cfset var ret = this.conn.getSafeColumnName( arguments.col )/>


		<cfreturn ret />

	</cffunction>

	<cffunction name="queryParam" hint="I create the values to build the cfqueryparam tag." output="false" returntype="string">
		<cfargument name="value" type="string" required="true">
		<cfargument name="cfsqltype" type="string" required="false" default="cf_sql_varchar" hint="This can be a standard RDBS datatype or a cf_sql_type (see getCFSQLType())">
		<cfargument name="list" type="boolean" required="false" default="false">
		<cfargument name="null" required="false" type="boolean" default="false">
		
		<cfset var returnStruct = structNew() />
		<cfset var returnString = structNew() />
		
		<cfset returnStruct = queryParamStruct(value=trim(arguments.value),cfsqltype=arguments.cfsqltype,list=arguments.list,null=arguments.null)>
 		<cfset returnString = '#chr(998)#list=#chr(777)##returnStruct.list##chr(777)# null=#chr(777)##returnStruct.null##chr(777)# cfsqltype=#chr(777)##returnStruct.cfsqltype##chr(777)# value=#chr(777)##returnStruct.value##chr(777)##chr(999)#'>	
		<cfreturn returnString />
	</cffunction>

	<cffunction name="queryParamStruct" hint="I create the values to build the cfqueryparam tag." output="false" returntype="struct">
		<cfargument name="value" type="string" required="true">
		<cfargument name="cfsqltype" type="string" required="false" default="cf_sql_varchar" hint="This can be a standard RDBS datatype or a cf_sql_type (see getCFSQLType())">
		<cfargument name="list" type="boolean" required="false" default="false">
		<cfargument name="null" required="false" type="boolean" default="false">
		
		<cfset var returnStruct = structNew() />

		<cfset returnStruct.cfsqltype = reReplaceNoCase(getCFSQLType(arguments.cfsqltype),'\$queryparam','INVALID','all')>
		<!--- strip out any queryparam calls in the value, this will prevent the ability to submit malicious code through the SQL string --->
		<cfset returnStruct.value = reReplaceNoCase(arguments.value,'\$queryparam','INVALID','all')>
		<cfset returnStruct.list = reReplaceNoCase(arguments.list,'\$queryparam','INVALID','all')>
		<cfset returnStruct.null = reReplaceNoCase(arguments.null,'\$queryparam','INVALID','all')>
		
		<cfreturn returnStruct />
	</cffunction>

	<cffunction name="parameterizeSQL" output="true" access="public" returntype="struct" hint="I build a struct containing all of the where clause of the SQL statement, parameterized when possible.  The returned struct will contain an array of each parameterized clause containing the data necessary to build a <cfqueryparam> tag.">
		<cfargument name="sql" type="string" required="true" hint="SQL statement (or partial SQL statement) which contains tokenized queryParam calls">
		
		<cfset var LOCAL = {}/>
		<cfset var tmp = {}/>
		<cfset var idx = 1/>
		<cfset var tempValue = ""/>
		<cfset var tempList = ""/>		
		<cfset var tempCFSQLType = ""/>		
		<cfset var tempParam = ""/>		
		<cfset var tmpSQL = parseQueryParams( arguments.sql ) />
			<!---<cfdump var="#tmpSQL#" abort>--->
			<cfset LOCAL.statements = []/>

			<cfif listLen( tmpSQL, chr( 998 ) ) LT 2 || !len( trim( listGetAt( tmpSQL, 2, chr( 998 ) ) ) ) >
				<!--- No queryParams to parse, just return the raw SQL --->
				<cfreturn {statements = [ {"before" = tmpSQL} ] }/>
			</cfif>
			<cfset tmpSQL = listToArray( tmpSQL, chr( 999 ) ) />
			
			<cfloop from="1" to="#arrayLen( tmpSQL )#" index="idx">
				
				<cfset tmp.before = listFirst( tmpSQL[ idx ], chr( 998 ) ) />
				<!--- remove trailing ' from previous clause --->
				<cfif left( tmp.before, 1 ) eq "'" >
					<cfset tmp.before = mid( tmp.before, 2, len( tmp.before ) ) />
				</cfif>
				<cfset tmp.before = preserveSingleQuotes( tmp.before ) />

				<cfset tempParam = listRest( tmpSQL[ idx ], chr( 998 ) ) />
				<cfset tempParam = preserveSingleQuotes( tempParam ) />
				<!---
					These will return the position and length of the name, cfsqltype and value.
					We use these to extract the values for the actual cfqueryparam
				--->
				<cfset tempCFSQLType = reFindNoCase( 'cfsqltype\=#chr(777)#(.*?)#chr(777)#', tempParam, 1, true ) />
				
				<cfif arrayLen( tempCFSQLType.pos ) LTE 1>
					<cfset arrayAppend( LOCAL.statements, tmp ) />
					<cfcontinue/>
				</cfif>

				<cfset tmp.cfSQLType = mid( tempParam, tempCFSQLType.pos[2], tempCFSQLType.len[2] ) />
				<cfset tempValue = reFindNoCase( 'value\=#chr( 777 )#(.*?)#chr( 777 )#', tempParam, 1, true ) />
				<!--- Strip out any loose hanging special characters used for temporary delimiters (chr(999) and chr(777)) --->
				<cfset tmp.value = reReplaceNoCase( mid( PreserveSingleQuotes( tempParam ), tempValue.pos[2], tempValue.len[2] ), chr( 777 ), '', 'all' ) />
				<cfset tmp.value = reReplaceNoCase( preserveSingleQuotes( tmp.value ), chr( 999 ), '', 'all' ) />

				<cfset tempList = reFindNoCase( 'list\=#chr( 777 )#(.*?)#chr( 777 )#', tempParam, 1, true ) />
				<cfif NOT arrayLen( tempList.pos ) GTE 2 OR NOT isBoolean( mid( tempParam, tempList.pos[2], tempList.len[2] ) ) >
					<cfset tmp.isList = false />
				<cfelse>
					<cfset tmp.isList = mid( tempParam, tempList.pos[2], tempList.len[2] ) />
				</cfif>

				<cfset arrayAppend( LOCAL.statements, tmp )/>
				<!--- Reset tmp struct --->
				<cfset tmp = {}/>
			</cfloop>
			<cfreturn LOCAL />

	</cffunction>

	<cffunction name="parseQueryParams" output="false" access="public" returntype="string" hint="I parse queryParam calls in the passed SQL string.  See queryParams() for syntax.">
		<cfargument name="str" type="any" required="true">
		<!--- 
			This function wll parse the passed SQL string to replace $queryParam()$ with the evaluated 
			<cfqueryparam> tag before passing the SQL statement to cfquery (dao.read()).  This function
			should only be used if the SQL statement is stored in the database.  If the SQL is generated
			in-page, use dao.queryParam() directly to create query parameters.  The reason is that this
			method is limited and could cause errors if $'s are passed in.
		--->
		<cfscript>
			// First we check to see if the string has anything to parse
			var nStartPos = findnocase('$queryparam(',arguments.str,1);
			var nEndPos = "";
			var tmpStartString = "";
			var tmpString = "";
			var tmpEndString = "";			
			var eval_string = "";
			var returnString = "";
			
			//Append a space for padding, this helps with the last iteration of recursion
			arguments.str = arguments.str & " ";
			
			if (nStartPos){
				//If so, we'll recursively parse all CF code (code between $'s)
				nStartPos 	= nStartPos + 1;
				nEndPos 	= (findnocase(')$',arguments.str,nStartPos) - nStartPos)+1;
				// If no end $ (really #) was found, pass back original string.
				if (NOT nEndPos GT 0){
					return arguments.str;
					break;
				}else if (nStartPos LTE 1){
					return arguments.str;
					break;
				}
				// Now let's grab the piece of string to evaluate
				tmpStartString = mid(arguments.str,1,nStartPos - 2);
				tmpString = mid(arguments.str,nStartPos,nEndPos);
				tmpEndString = mid(arguments.str, len(tmpStartString) + nEndPos + 3,len(arguments.str));
				// A little clean-up
				tmpString = reReplaceNoCase(tmpString,'&quot;',"'",'all');
				// If queryParam was passed in the SQL, lets' parse it
				if (findNoCase("queryParam",tmpString)){					
					// We need to normalize the cfml and to be parsed
					// in order to ensure error free processing.  The
					// following will extract the cfsqltype and value
					// from the queryParam() call and reconstruct the
					// queryParam call passing variables instead of
					// literal strings.  This is done to prevent breaking
					// when a non-closed quote or double-quote is passed
					// in the literal string.
					// (i.e. value="this is'nt" my string") would break the
					// code if we didn't do the following
					tmpString = reReplaceNoCase(tmpString,'^queryParam\(','');
					tmpString = reReplaceNoCase(tmpString,'\)$','');					
					var tmpArr = listToArray( tmpString );
					// parse each passed in key/value pair and make sure they are proper JSON (i.e. quoted names/values)
					for( var i = 1; i <= arrayLen( tmpArr ); i++ ){
						tmpArr[ i ] = reReplaceNoCase( tmpArr[ i ], '[''|"]*(.+?)[''|"]*=[''|"]*(\b.*\b)[''|"|$]*', '"\1":"\2"', 'all') ;
						// temporary hack for blank values until I can figure how to handle this in the regex above.
						if( tmpArr[ i ] == "value=''" || tmpArr[ i ] == "value=" || tmpArr[ i ] == 'value=""'){
							tmpArr[ i ] = '"value":""';
						}
					}
					// turn the JSON into a CF struct
					tmpString = deSerializeJSON( "{" & arrayToList( tmpArr ) & "}" );
					
					// finally we can evaluate the queryParam struct.  This will scrub the values (i.e. proper cfsql types, prevent sql injection, etc...).					
					eval_string = queryParamStruct( 
													value = structKeyExists( tmpString, 'value' ) ? tmpString.value : '',
													cfsqltype = structKeyExists( tmpString, 'cfsqltype' ) ? tmpString.cfsqltype : '',
													list= structKeyExists( tmpString, 'list' ) ? tmpString.list : false,
													null = structKeyExists( tmpString, 'null' ) ? tmpString.null : false
												);
					
					
					// This can be any kind of object, but we are hoping it is a struct (see queryParam())
					if ( isStruct( eval_string ) ){
						// Now we'll pass back a pseudo cfqueryparam.  The read() function will
						// break this down and re-create it since the tag call itself has to be static
						returnString = tmpStartString & chr(998) & 'cfsqltype=#chr(777)#' & reReplaceNoCase(eval_string.cfsqltype,'\$queryparam','INVALID','all') & '#chr(777)# value=#chr(777)#' & reReplaceNoCase(eval_string.value,'\$queryparam','INVALID','all') & '#chr(777)#' & chr(999) &  tmpEndString;
						// Now the recursion.  Pass the string with the value we just parsed back
						// this function to see if there is anything left to parse.  When there is
						// nothing left to parse it will be returned to the calling function (read())
						return parseQueryParams( returnString );
						break;
					}else{
						// The evaluated string was not a simple object and could be malicious so we'll
						// just pass back an error message so the programmer can fix it.
						//return arguments.str;
						return "Parsed queryParam is not a struct!";
						break;
					}
				}else{
					// There was not an instance of queryParam called, so return the unmodified sql
					return arguments.str;
					break;
				}
			}else{
				// Nothing left to parse, let's return the string back to the original calling function
				return arguments.str;
			}
		</cfscript>
	</cffunction>

	<cffunction name="addTableDef" output="false" returntype="void">
		<cfargument name="tabledef" type="tabledef" required="true">
		<cfset variables.tabledefs[arguments.tabledef.instance.name] = arguments.tabledef/>
	</cffunction>

	<cfscript>
		public tabledef function makeTable( required tabledef tabledef ){
			return this.conn.makeTable( arguments.tabledef );
		}
	</cfscript>
	
</cfcomponent>