component displayName="My test suite" extends="testbox.system.BaseSpec"{

     // executes before all tests
     function beforeTests(){
		request.dao = new com.database.dao( dsn = "dao" );
     }

     function createNewDAOInstanceUsingDefaultDatasource() test{
          var test = new com.database.dao();

          $assert.isTrue( isInstanceOf( test, "com.database.dao" ) );
          var records = request.dao.read("users");
          $assert.typeOf( "query", records );
     }

     function createNewDAOInstance() test{
     	var test = new com.database.dao( dsn = "dao" );

     	$assert.isTrue( isInstanceOf( test, "com.database.dao" ) );
     }
     function readByTableName() test{
          var records = request.dao.read("users");

          $assert.typeOf( "query", records );

     }
     function readBySQLWithoutWhereClause() test{
          var records = request.dao.read("select * from users");

          $assert.typeOf( "query", records );
     }
     function readWithNamedParams() test{
          var records = request.dao.read("
               SELECT *
               FROM eventLog
               WHERE ID = :eventLogId or ID = :anotherId{ type='int',null=false}",{ eventLogId=1, anotherId=20 } );

          $assert.typeOf( "query", records );
     }
     function readWithNamedParamsDoubleValueParam() test{
          var records = request.dao.read("
               SELECT *
               FROM eventLog
               WHERE ID = :eventLogId or ID = :anotherId{value='test', type='int',null=false}",{ eventLogId=1, anotherId=20 } );

          $assert.typeOf( "query", records );
          $assert.isTrue( records.ID == 1 );
     }
     function readWithNamedParamsAsList() test{
          var records = request.dao.read("
               SELECT *
               FROM eventLog
               WHERE ID IN(:eventLogIds{type='int',null=false,list=true})",{ eventLogIds="1,20" } );

          $assert.typeOf( "query", records );
          $assert.isTrue( records.ID == 1 );
     }
     function readWithNamedParamsArrayAsList() test{
          var records = request.dao.read("
               SELECT *
               FROM eventLog
               WHERE ID IN(:eventLogIds{type='int',null=false,list=true})",{ eventLogIds=[1,20] } );

          $assert.typeOf( "query", records );
          $assert.isTrue( records.ID == 1 );     
     }
     function readWithNamedParamsAsAlphaList() test{
        var events="delete,test insert";
        var records = request.dao.read("
            SELECT *
            FROM eventLog
            WHERE event IN(:events{list=true})",{ events:events } );

        $assert.typeOf( "query", records );
        $assert.isTrue( records.recordCount == 3 );
     }
     function readWithNamedParamsArrayAsAlphaList() test{
        var events=["delete","test insert"];
        var records = request.dao.read("
            SELECT *
            FROM eventLog
            WHERE event IN(:events{list=true})",{ events:events } );

        $assert.typeOf( "query", records );
        $assert.isTrue( records.recordCount == 3 );  
     }
     function readWithParamsAsList() test{
        var eventLogIds="1,20";
        var records = request.dao.read("
            SELECT *
            FROM eventLog
            WHERE ID IN( #request.dao.queryParam( value=eventLogIds, type='int',null=false,list=true )# )" );

        $assert.typeOf( "query", records );
        $assert.isTrue( records.ID == 1 );
     }
     function readWithParamsArrayAsList() test{
        var eventLogIds=[1,20];
        var records = request.dao.read("
            SELECT *
            FROM eventLog
            WHERE ID IN( #request.dao.queryParam( value=eventLogIds, type='int',null=false,list=true )# )" );

        $assert.typeOf( "query", records );
        $assert.isTrue( records.ID == 1 );
     }
     function readWithParamsAsAlphaList() test{
        var events="delete,test insert";
        var records = request.dao.read("
            SELECT *
            FROM eventLog
            WHERE event IN( #request.dao.queryParam( value=events,list=true )# )" );

        $assert.typeOf( "query", records );
        $assert.isTrue( records.recordCount == 3 );
     }
     function readWithParamsArrayAsAlphaList() test{
        var events=["delete","test insert"];
        var records = request.dao.read("
            SELECT *
            FROM eventLog
            WHERE event IN( #request.dao.queryParam( value=events,list=true )# )" );

        $assert.typeOf( "query", records );        
        $assert.isTrue( records.recordCount == 3 );
     }
     function readWithMissingNamedParams() test{
          try{

          var records = request.dao.read("
               SELECT *
               FROM eventLog
               WHERE ID IN(:eventLogIds{type='int',null=false,list=true})",{ eventLogIds="1,20" } );

          }catch("DAO.parseQueryParams.MissingNamedParameter" e ){
               $assert.isTrue(true);
          }catch( any e ){
               writeDump([e]);abort;
               $assert.isTrue(false);
          }
     }
     function insertWithNamedParams() test{
          var newRecordId = request.dao.execute("
               INSERT INTO eventLog ( event, description, eventDate )
               VALUES (:event{type='varchar',null=false,list=false}, :description, :eventDate{type='timestamp'})",
               { event="test named params", description = "This is a description from a named param", eventDate = now() } );
          $assert.typeOf( "numeric", newRecordId );

          var rec = request.dao.read("
               SELECT * FROM eventLog
               WHERE ID = :newID
          ", { newId = newRecordId });
          $assert.typeOf( "query", rec );
          $assert.isEqual( newRecordId, rec.ID );
          $assert.isEqual( "test named params", rec.event );

     }
     // function getConnecterType() test{
     //      $assert.fail('test not implemented yet');
     // }
     // function getLastID() hint="I return the ID of the last inserted record." returntype="any" output="true" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function read() hint="I read from the database. I take either a tablename or sql statement as a parameter." returntype="any" output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     function readWithNumericInParams() hint="I read from the database. I take either a tablename or sql statement as a parameter." returntype="any" output="false" test{
          var records = request.dao.read("SELECT * FROM eventLog WHERE ID IN(1,20,3,5,6,7)");
          $assert.typeOf( "query", records );
     }
     function readWithNumericParams() hint="I read from the database. I take either a tablename or sql statement as a parameter." returntype="any" output="false" test{
          var records = request.dao.read("SELECT * FROM eventLog WHERE ID = 1 or ID = 20");
          $assert.typeOf( "query", records );
     }
     function readWithDateArg() hint="I read from the database. I take either a tablename or sql statement as a parameter." returntype="any" output="false" test{
          var records = request.dao.read("SELECT * FROM eventLog WHERE eventDate <= #now()#");
          $assert.typeOf( "query", records );
          $assert.isTrue( records.recordCount GT 0 );
     }
     function readWithDateParam() hint="I read from the database. I take either a tablename or sql statement as a parameter." returntype="any" output="false" test{
          var records = request.dao.read("SELECT * FROM eventLog WHERE eventDate <= #request.dao.queryParam(value=now(),type="datetime")#");
          $assert.typeOf( "query", records );
          $assert.isTrue( records.recordCount GT 0 );
     }
     function readAsArray() hint="I read from the database and return an array of structs representing the query object. I take either a tablename or sql statement as a parameter." returntype="any" output="false" test{
          var records = request.dao.read( sql = "SELECT * FROM eventLog WHERE ID IN(1,20,3,5,6,7)", returnType = 'array');
          $assert.typeOf( "array", records );
     }
     function readAsJSON() hint="I read from the database and return a JSON string representing the query object. I take either a tablename or sql statement as a parameter." returntype="any" output="false" test{
          var records = request.dao.read( sql = "SELECT * FROM eventLog WHERE ID IN(1,20,3,5,6,7)", returnType = 'json');
          $assert.typeOf( "string", records );
          $assert.typeOf( "array", deserializeJSON(records) );
     }
     function readQueryOfQueryAsQuery() hint="I test the query of query syntax" returntype="any" output="false" test{
          var users = request.dao.read("users");
          var johns = request.dao.read( sql = "
                    SELECT first_name, last_name
                    FROM userQuery
                    WHERE lower(first_name) = :firstName
               ",
               params = { firstName = 'john' },
               QoQ = { userQuery = users}
          );
          $assert.typeOf( "query", johns );

     }
     function readQueryOfQueryAsArray() hint="I test the query of query syntax" returntype="any" output="false" test{
          var users = request.dao.read("users");
          var johns = request.dao.read( sql = "
                    SELECT first_name, last_name
                    FROM userQuery
                    WHERE lower(first_name) = :firstName
               ",
               params = { firstName = 'john' },
               returnType = "Array",
               QoQ = { userQuery = users}
          );
          $assert.typeOf( "array", johns );

     }
     function readQueryOfQueryAsJSON() hint="I test the query of query syntax" returntype="any" output="false" test{
          var users = request.dao.read("users");
          var johns = request.dao.read( sql = "
                    SELECT first_name, last_name
                    FROM userQuery
                    WHERE lower(first_name) = :firstName
               ",
               params = { firstName = 'john' },
               returnType = "JSON",
               QoQ = { userQuery = users}
          );
          $assert.typeOf( "string", johns );
          $assert.typeOf( "array", deserializeJSON(johns) );

     }

     function queryToArray() test{
          var records = request.dao.read( sql = "SELECT * FROM eventLog WHERE ID IN(1,20,3,5,6,7)");
          var test = request.dao.queryToArray( records );
          $assert.typeOf( "array", test );
     }

     function queryToArrayWithMap() test{
          var records = request.dao.read( sql = "SELECT first_name, last_name from users");
          var test = request.dao.queryToArray( records, function( row, index, cols ){
               var formattedRow = {};
               for( var col in cols ){
                    formattedRow[col] =  row[col] & "test";
               }
               return formattedRow;
          } );
          $assert.typeOf( "array", test );
          $assert.isTrue( records.recordCount == arrayLen( test ) );
          $assert.isTrue( records["first_name"][1] & "test" == test[1]["first_name"] );
     }
     function pageQueryResultsWithLimitAndOffset() hint="I test the query with server side paging" returntype="any" output="false" test{
          var pagedEvents = request.dao.read(
               sql = "
                    SELECT *
                    FROM eventLog
                    ",
               offset = 0,
               limit = 5
          );
          $assert.isTrue( pagedEvents.recordCount == 5 );
          $assert.isTrue( pagedEvents.recordCount != pagedEvents.__fullCount );
     }
     function pageTableResultsWithLimitAndOffset() hint="I test the query with server side paging" returntype="any" output="false" test{
          var pagedEvents = request.dao.read(
               table = "eventLog",
               offset = 0,
               limit = 5
          );
          $assert.isTrue( pagedEvents.recordCount == 5 );
          $assert.isTrue( pagedEvents.recordCount != pagedEvents.__fullCount );
     }
     function pageImpliedTableResultsWithLimitAndOffset() hint="I test the query with server side paging" returntype="any" output="false" test{
          var pagedEvents = request.dao.read(
               sql = "eventLog",
               offset = 0,
               limit = 5
          );
          $assert.isTrue( pagedEvents.recordCount == 5 );
          $assert.isTrue( pagedEvents.recordCount != pagedEvents.__fullCount );
     }

     function pageQoQResultsWithLimitAndOffset() hint="I test the query of query syntax with server side paging" returntype="any" output="false" test{
          var events = request.dao.read("eventLog");
          var pagedEvents = request.dao.read(
               sql = "
                    SELECT *
                    FROM eventsQuery
                    ",
               QoQ = { eventsQuery = events },
               offset = 0,
               limit = 5
          );
          if( pagedEvents.recordCount == pagedEvents.__fullCount || pagedEvents.recordCount != 5 ){
               writeDump([pagedEvents,events]);abort;
          }
          $assert.isTrue( events.ID[1] == pagedEvents.ID[1] );
          $assert.isTrue( pagedEvents.recordCount == 5 );
          $assert.isTrue( pagedEvents.recordCount != pagedEvents.__fullCount );
     }
     // function readFromQuery() hint="I read from another query (query of query). I take a sql statement as a parameter." returntype="query" output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function write() hint="I insert data into the database.  I take a tabledef object containing the tablename and column values. I return the new record's Primary Key value." returntype="any" output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     function insert() hint="I insert data into a table in the database." returntype="any" access="public" output="false" test{

          request.dao.execute("truncate table test");
          var data = { "test": i & "  " & createUUID(), "testDate": now() };
          var test = request.dao.insert( table = "test", data = data );

          $assert.isTrue( test == 1 );

          var retrieve = request.dao.read( "test" );
          $assert.isTrue( retrieve.recordCount == 1 );
     }

     function insertWithOnFinish() hint="I insert data into a table in the database then call an onFinish function." returntype="any" access="public" output="false" test{

          request.dao.execute("truncate table test");
          var testData = i & "  " & createUUID();
          var data = { "test": testData, "testDate": now() };
          var test = request.dao.insert( table = "test", data = data, onFinish = function( table, data, id ){
               return data.test == testData;
          } );

          $assert.isTrue( test == 1 );

          var retrieve = request.dao.read( "test" );
          $assert.isTrue( retrieve.recordCount == 1 );
     }

     function bulkInsertArray() hint="I test inserting an array of data into the a table." returntype="any" output="false" test{
          var data = [];
          request.dao.execute("truncate table test");
          for( i = 1; i <= 10; i++ ){
               data.append( { "test": i & "  " & createUUID(), "testDate": now() } );
          }
          var test = request.dao.insert( table = "test", data = data );

          $assert.isTrue( test.len() == 10 );
          $assert.isTrue( test[ 5 ] == 5 );

          var retrieve = request.dao.read( "test" );
          $assert.isTrue( retrieve.recordCount == 10 );
     }
     function bulkInsertQuery() hint="I test inserting an query object of data into the a table." returntype="any" output="false" test{
          var data = [];
          request.dao.execute("truncate table test");
          for( i = 1; i <= 10; i++ ){
               data.append( { "test": i & "  " & createUUID(), "testDate": now() } );
          }
          var qry = queryNew("test,testDate", "cf_sql_varchar,cf_sql_date", data );
          var test = request.dao.insert( table = "test", data = qry );

          $assert.isTrue( test.len() == 10 );
          $assert.isTrue( test[ 5 ] == 5 );

          var retrieve = request.dao.read( "test" );
          $assert.isTrue( retrieve.recordCount == 10 );
     }
     function update() hint="I update data in a table in the database." returntype="any" access="public" output="false" test{

          request.dao.execute("truncate table test");
          var data = { "test": "test data here", "testDate": now() };
          var test = request.dao.insert( table = "test", data = data );
          var retrieve = request.dao.read( "test" );
          data.test = "new test data";

          request.dao.update( table = "test", data = data, id = test );
          var retrieve = request.dao.read( "test" );
          $assert.isTrue( retrieve.test == "new test data" );
     }
     // function updateTable() hint="I update data in the database.  I take a tabledef object containing the tablename and column values. I return the record's Primary Key value." returntype="numeric" output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function bulkUpdate() hint="I update data in the database.  I take a tabledef object containing the tablename and column values. I return the number of records updated." returntype="numeric" output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     function delete() hint="I delete data in the database.  I take the table name and either the ID of the record to be deleted or a * to indicate delete all." output="false" test{
          var identityInsertOn = request.dao.getDBtype() == "mssql" ? "set identity_insert dbo.eventLog on;":"";
          var identityInsertOff = request.dao.getDBtype() == "mssql" ? "set identity_insert dbo.eventLog off;":"";
          var newRecordId = request.dao.execute(sql =
               "#identityInsertOn#
               INSERT INTO eventLog ( ID, event, description, eventDate )
               VALUES (:ID, :event{type='varchar',null=false,list=false}, :description, :eventDate{type='timestamp'});
               #identityInsertOff#",
               params = { event="test to be deleted", description = "This is a description from a named param", eventDate = now(), ID = 10000 }
          );

          var event = request.dao.read("select * from eventLog where ID = 10000");
          $assert.isTrue( event.recordCount );
          request.dao.delete( table = "eventLog", idField = "ID", recordID = 10000 );         
          var event = request.dao.read("select * from eventLog where ID = 10000");
          $assert.isTrue( !event.recordCount );
     }
     // function markDeleted() hint="I mark the record as deleted.  I take the table name and either the ID of the record to be deleted or a * to indicate delete all." returntype="boolean" output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function logTransaction() returntype="void" output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function execute() hint="I execute database commands that do not return data.  I take an SQL execute command and return 0 for failure, 1 for success, or the last inserted ID if it was an insert." returntype="any" output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function prepareNonQueryParamValue() returntype="string" output="false" hint="I prepare a parameter value for SQL execution when not using cfqueryparam.  Basically I try to do the same thing as cfqueryparam." test{
     //      $assert.fail('test not implemented yet');
     // }
     // function getNonQueryParamFormattedValue()  returntype="string" output="false" hint="I prepare a parameter value for SQL execution when not using cfqueryparam.  Basically I try to do the same thing as cfqueryparam." test{
     //      $assert.fail('test not implemented yet');
     // }
     // function getCFSQLType() returntype="string" hint="I determine the CFSQL type for the passd value and return the proper type as a string to be used in cfqueryparam." output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function setUseCFQueryParams() access="public" returntype="void" output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function getUseCFQueryParams() access="public" returntype="boolean" output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function setUpdate() returntype="void" hint="I build a container to be passed to the update function." output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function define() hint="I return the structure of the passed table.  I am MySQL specific." returntype="query" access="public" output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function getColumnType() hint="I return the datatype for the given table.column.  I am MySQL specific." returntype="string" access="public" output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function getTables() hint="I return a list of tables for the current database." returntype="query" access="public" output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function getColumns() hint="I return a list of columns for the passed table." returntype="string" access="public" output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function getPrimaryKey() hint="I get the primary key for the given table. To do this I envoke the getPrimaryKey from the conneted database type." output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function getSafeColumnNames() access="public" returntype="string" hint="I take a list of columns and return it as a safe columns list with each column wrapped within ``.  This is MySQL Specific." output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function getSafeColumnName() access="public" returntype="string" hint="I take a single column name and return it as a safe columns list with each column wrapped within ``.  This is MySQL Specific." output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function getSafeIdentifierStartChar() access="public" returntype="string" hint="I return the opening escape character for a column name.  This is MySQL Specific." output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function getSafeIdentifierEndChar() access="public" returntype="string" hint="I return the closing escape character for a column name.  This is MySQL Specific." output="false" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function queryParam() hint="I create the values to build the cfqueryparam tag." output="false" returntype="string" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function queryParamStruct() hint="I create the values to build the cfqueryparam tag." output="false" returntype="struct" test{
     //      $assert.fail('test not implemented yet');
     // }
     // function parameterizeSQL() output="true" access="public" returntype="struct" hint="I build a struct containing all of the where clause of the SQL statement, parameterized when possible.  The returned struct will contain an array of each parameterized clause containing the data necessary to build a <cfqueryparam> tag." test{
     //      $assert.fail('test not implemented yet');
     // }
     // function parseQueryParams() output="false" access="public" returntype="string" hint="I parse queryParam calls in the passed SQL string.  See queryParams() for syntax." test{
     //      $assert.fail('test not implemented yet');
     // }
     // function addTableDef() output="false" returntype="void" test{
     //      $assert.fail('test not implemented yet');
     // }
     // executes after all tests
     function afterTests(){

     	//structClear( application );

     }

}