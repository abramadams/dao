/**
*	@hint Extend this component to add ORM like behavior to your model CFCs.  Requires CF10, Railo 4.x due to use of anonymous functions for lazy loading.
*   @version 0.0.51
*   @updated 12/30/2013 
*   @author Abram Adams
**/ 
component accessors="true" output="false" {

	/* properties */
	property name="table" type="string" persistent="false";
	//property name="ID" type="numeric" getter="false" setter="false";
	property name="IDField" type="string" persistent="false";
	property name="IDFieldType" type="string" persistent="false";
	property name="IDFieldGenerator" type="string" persistent="false";
	/* property name="currentUserID" type="numeric" persistent="false"; */
	property name="deleteStatusCode" type="numeric" persistent="false";
	
	/* Some global properties */
	/* property name="Created_By_Users_Id" type="numeric" ;
	property name="Created_Datetime" type="date" ;
	property name="Modified_By_Users_Id" type="numeric" ;
	property name="Modified_Datetime" type="date" ; */
	
	/* Dependancy injection */
	property name="dao" type="dao" persistent="false";
	property name="tabledef" type="tabledef" persistent="false";
		
	/* Table make/reload options */
	property name="dropcreate" type="boolean" default="false" persistent="false";

	_isNew = true;
	_isDirty = false;

	public any function init( 	string table = "", 
								numeric currentUserID = 0,
								string idField = "ID",
								string idFieldType = "", 
								string idFieldGenerator = "", 
								numeric deleteStatusCode = 1, 
								any dao = "",
								boolean dropcreate = false){
		//variables._isNew = true;
		var LOCAL = {};
		if( !isSimpleValue(arguments.dao) ){
			//this.DAO = arguments.dao;
			variables.dao = arguments.dao;
		} else {
			throw("You must have a dao" & arguments.dao );
		}
		variables.dropcreate = arguments.dropcreate;		
		variables.meta = getMetaData( this );


		if( !len( trim( arguments.table ) ) ){
			/* If the table name was not passed in, see if the table property was set on the component */			
			if( structKeyExists( variables.meta,'table' ) ){
				setTable( variables.meta.table );				
			/* If not, see if the table property was set on the component it extends */
			}else if(structKeyExists(variables.meta.extends,'table')){
				setTable(variables.meta.extends.table);	
			/* If not, use the component's name as the table name */
			}else if(structKeyExists(variables.meta,'fullName')){
                setTable(listLast(variables.meta.fullName, '.'));
			}else{
				//writeDump(variables.meta); abort;
				throw('Argument: "Table" is required if the component declaration does not indicate a table.','variables','If you don''t pass in the table argument, you must specify the table attribute of the component.  I.e.  component table="table_name" {...}');
			}
		}else{
			setTable(arguments.table);
		}
		
		if( variables.dropcreate ){
			writeLog('droppping #getTable()#');
			dropTable();	
			writeLog('making #getTable()#');
			makeTable();
		}else{
			try{
				variables.tabledef = new tabledef(tableName = getTable(), dsn = variables.dao.getDSN());
			} catch (any e){
				if( e.type eq 'Database' ){
					//writeDump(e);abort;				
					makeTable();
				}else{
					writeDump(e);abort;				
				}
			}
		}

		
		/* Setup the ID (primary key) field.  This can be used to generate id values, etc.. */
		setIDField( arguments.IDField );
        setIDFieldType( variables.tabledef.getDummyType( variables.tabledef.getColumnType( getIDField() ) ) );
		setDeleteStatusCode( arguments.deleteStatusCode );

        variables.dao.addTableDef( variables.tabledef );

        // Hack to make variables.meta a true CF data type
        variables.meta = deSerializeJSON( serializeJSON( variables.meta ) );
        variables.meta.properties =  structKeyExists( variables.meta, 'properties' ) ? variables.meta.properties : [];

		/* 
			If there are more columns in the table than there are properties, let's dynamically add them 
			This will allow us to dynamically stub out the entity "class".  So one could just create a 
			CFC without any properties, then point it to a table and get a fully instantiated entity.
		*/

		var found = false;
		if( structCount( variables.tabledef.instance.tablemeta.columns ) GT arrayLen( variables.meta.properties ) ){			
			// We'll loop through each column in the table definition and see if we have a property, if not, create one.
			// @TODO when CF9 support is no longer needed, use an arrayFind with a anonymous function to do the search.
			for( var col in variables.tabledef.instance.tablemeta.columns ){				
				for ( var existingProp in variables.meta.properties ){					
					if ( ( structKeyExists( existingProp, 'column' ) && existingProp.column EQ col ) 
							|| ( structKeyExists( existingProp, 'name' ) && existingProp.name EQ col )){
						//property exists skip to the next column
						found = true;
						break;
					}
				}
				
				if ( !found ){
				
					variables[col] = this[col] = "";
					variables["set" & col] = this["set" & col] = this.methods["set" & col] = setFunc;
					variables["get" & col] = this["get" & col] = this.methods["get" & col] = getFunc;

					var newProp = {
						"name" = col, 
						"column" = col,
						"generator" = variables.tabledef.instance.tablemeta.columns[col].generator, 
						"fieldtype" = variables.tabledef.instance.tablemeta.columns[col].isPrimaryKey ? "id" : "",
						"type" = variables.tabledef.getDummyType(variables.tabledef.instance.tablemeta.columns[col].type),
						"dynamic" = true
					};
					
					arrayAppend( variables.meta.properties, newProp );				
				}

				found = false;

			}
		}


       /** 
       * This will hijack all of the setters and inject a function that will set the 
       * isDirty flag to true anytime data changes
       **/	
		for ( var prop in variables.meta.properties ){
			if( ( !structKeyExists( prop, 'setter' ) || prop.setter ) && ( !structKeyExists( prop, 'fieldType' ) ||  prop.fieldType does not contain '-to-' ) ){

				// copy the real setter function to a temp variable.
				variables[ "$$__set" & prop.name ] = this[ "set" & prop.name ];

				// now override the setter with the new function that will set the dirty flag.
				if( !structKeyExists( this, "set" & prop.name ) || !isCustomFunction( this[ "set" & prop.name ] ) ){
					this[ "set" & prop.name ] = setFunc;
				}
			}

		}
		/* Now if the model was extended, include those properties as well */
		for ( var prop in variables.meta.extends.properties ){
			if( ( !structKeyExists( prop, 'setter' ) || prop.setter ) && ( !structKeyExists( prop, 'fieldType' ) ||  prop.fieldType does not contain '-to-' ) ){
				// copy the real setter function to a temp variable.
				variables[ "$$__set" & prop.name ] = this[ "set" & prop.name ];
				// now override the setter with the new function that will set the dirty flag.
				this[ "set" & prop.name ] = setFunc;        		
			}
		}
	    return this;
	}

	/**
	* This function will replace each public setter so that the isDirty
	* flag will be set to true anytime data changes.
	**/
	private function setFunc( required any v ){
		if( getFunctionCalledName() == 'tmpFunc' ){
			return;
		}

		if( left( getFunctionCalledName(), 3) == "set" && getFunctionCalledName() != 'setterFunc' ){
			var propName = mid( getFunctionCalledName(), 4, len( getFunctionCalledName() ) );
			//var getFunc = duplicate( this["get" & mid( getFunctionCalledName(), 4, len( getFunctionCalledName() ) ) ] );			
			try{
				if( structKeyExists( variables, propName ) && v!= variables[ propName ] ){					
					variables._isDirty = compare( v, variables[ propName ] );
				}
			} catch ( any e ){
				writeDump(propName);
				writeDump(variables);
				writeDump( e );abort;
			}
			// Get the original setter function that we set aside in the init routine.
			var tmpFunc = duplicate( variables[ "$$__" & getFunctionCalledName() ] );
			// Dynamically added properties won't have setters.  This will manually stuff the value into the property
			this[propName] = variables[propName] = v;
			// tmpFunc is now the original setter so let's fire it.  The calling page
			// will not know this happened.
			tmpFunc( v );
		}

	}
	private any function getFunc( any name = "" ){

		if( len( trim( name ) ) ){
			return this[ name ];
		}

		if( left( getFunctionCalledName(), 3) == "get" && getFunctionCalledName() != 'getterFunc' ){

			var propName = mid( getFunctionCalledName(), 4, len( getFunctionCalledName() ) );

			return this[propName];
		}

		return "";

	}

	/**
	* @hint Returns true if the current state represents a new record/document 
	**/
	public boolean function isNew(){
		return variables._isNew;
	}

	/**
	* @hint Returns true if any of the original data has changed
	**/
	public boolean function isDirty(){
		return variables._isDirty;
	}

	/** 
	* @hint  I provide support for dynamic method calls for loading data into model objects.  
	*		 Use loadBy<column>And<column>And....() to load data using several column filters. 
	*		 This generates an SQL statement to retrieve the desired data.
	* 		 I also handle "lazy" loading methods like: lazyLoadAllBy<column>And<column>And...();
	**/
	public any function onMissingMethod( required string missingMethodName, required struct missingMethodArguments ){
		var LOCAL = {};		
		var queryArguments = [];
		var originalMethodName = arguments.missingMethodName;
		var args = {};
		var i = 0;
		var record = "";
		var recordSQL = "";
		var limit = arguments.missingMethodName is "loadTop" ? arguments.missingMethodArguments[1] : 1;
		var orderby = arguments.missingMethodName is "loadTop" ? "ORDER BY " & arguments.missingMethodArguments[2] : '';
		var where = "1=1";

		if( left( arguments.missingMethodName, 6 ) is "loadBy" 
			|| left( arguments.missingMethodName, 9 ) is "loadAllBy" 
			|| left( arguments.missingMethodName, 8 ) is "lazyLoad" 
			|| arguments.missingMethodName is "loadAll"
			|| arguments.missingMethodName is "loadTop"
			){
			
			var loadAll = left( arguments.missingMethodName, 7 ) is "loadAll" || left( arguments.missingMethodName, 11 ) is "lazyLoadAll";

			// Build where clause based on function name
			if(arguments.missingMethodName != "loadAll" && arguments.missingMethodName != "loadTop"){
				arguments.missingMethodName = reReplaceNoCase(reReplaceNoCase(arguments.missingMethodName,'loadBy|loadAllBy|lazyLoadAllBy|lazyLoadBy','','all'), 'And','|','all' );
				queryArguments = listToArray(arguments.missingMethodName,'|');
				for (i = 1; i LTE arrayLen(queryArguments); i++){
					args[queryArguments[i]] = arguments.missingMethodArguments[i];
					// the entity cfc could have a different column name than the given property name.  If the meta property "column" exists, we'll use that instead.
					LOCAL.columnName = structFindValue( variables.meta, queryArguments[i] );
					LOCAL.columnName = arrayLen( LOCAL.columnName ) && structKeyExists( LOCAL.columnName[1].owner, 'column' ) ? LOCAL.columnName[1].owner.column : queryArguments[i];
					
					//if( structKeyExists( variables.meta.properties, ))
					recordSQL &= " AND #LOCAL.columnName# = #variables.dao.queryParam(value=arguments.missingMethodArguments[i])#";
					//Setup defaults
					LOCAL.functionName = "set" & queryArguments[i];
					try{
						LOCAL.tmpFunc = this[LOCAL.functionName];
						LOCAL.tmpFunc(arguments.missingMethodArguments[i]);
					} catch ( any err ){}
				}											
			}
			if( structCount( missingMethodArguments ) GT arrayLen( queryArguments ) ){
				where = missingMethodArguments[ arrayLen( queryArguments ) + 1 ];
				where = len( trim( where ) ) ? where : '1=1';
			}

			/** 
			* @TODO refactor the read to handle limits more db agnostic (use the dao object to limit)
			**/
			record = variables.dao.read(sql="
				SELECT #( !loadAll && variables.dao.getDBType() is 'mssql' ) ? 'TOP ' & limit : ''# #this.getIDField()# FROM #this.getTable()#
				WHERE #where#
				#recordSQL#
				#orderby#
				#( !loadAll && variables.dao.getDBType() is 'mysql' ) ? 'LIMIT ' & limit : ''#
			", name="model_load_by_handler");
			
			variables._isNew = record.recordCount EQ 0;

			//If a record existed, load it		
			if( record.recordCount == 1 && !left( originalMethodName, 7 ) is "loadAll" && !left( originalMethodName, 11 ) is "lazyLoadAll"){
				return this.load( ID = val( record.ID ), lazy = left( originalMethodName , 4 ) is "lazy" );
			// If more than one record was returned, or method called was a "loadAll" type, return an array of data.
			}else if( record.recordCount > 1 || left( originalMethodName, 7 ) is "loadAll" || left( originalMethodName , 11 ) is "lazyLoadAll" ) {
				var recordArray = [];

				for ( var rec = 1; rec LTE record.recordCount; rec++ ){
					// append each record to the array. Each record will be an instance of the model entity in represents.  If lazy loading
					// this will be an empty entity instance with "overloaded" getter methods that instantiate when needed.
					arrayAppend( recordArray, duplicate( this.load( ID = record.ID[ rec ], lazy = left( originalMethodName , 4 ) is "lazy" ) ) );
				}
			
				return recordArray;
			//Otherwise, set the passed in arguments and return the new entity
			}else{
				for ( i = 1; i LTE arrayLen(queryArguments); i++ ){
					//Setup defaults
					LOCAL.functionName = "set" & queryArguments[ i ];
					try{
						LOCAL.tmpFunc = this[ LOCAL.functionName ];
						LOCAL.tmpFunc( arguments.missingMethodArguments[ i ] );
					} catch ( any err ){}
				}			
						
				return this;
			}
		}
		
		// throw error			
		throw( message = "Missing method", type="variables", detail="The method named: #arguments.missingMethodName# did not exist in #getmetadata(this).path#.");
		
	}
	/**
	* @hint Loads data into the model object. If lazy == true the child objects will be lazily loaded. Lazy loading allows us to inject "getter" methods that will instantiate the related data only when requested.  This makes the loading much quicker and only instantiates child objects when needed.
	**/
	public any function load( required any ID, boolean lazy = false ){
		
		var record = getRecord( ID = arguments.ID );

		for ( var fld in listToArray( record.columnList ) ){
			/* LOCAL.functionName = "set" & fld;
			try{
				LOCAL.tmpFunc = this[LOCAL.functionName];
				LOCAL.tmpFunc(record[fld][1]);
			} catch ( any err ){} */
			variables[ fld ] = record[ fld ][ 1 ];
		}
	
		variables.ID = arguments.ID;

		/*  Now iterate the properties and see if there are any relationships we can resolve */		
		var props = deSerializeJSON( serializeJSON( duplicate( variables.meta.properties ) ) );
		writeLog("parent table: " & getTable());
		
		for ( var col in props ){

			/* Load all child objects */
			if( structKeyExists( col, 'cfc' ) ){	
				var tmp = createObject( "component", col.cfc ).init( dao = this.getDao(), dropcreate = this.getDropCreate() );
				var setterFunc = this["set" & col.name ];
				var childWhere = structKeyExists( col, 'where' ) ? col.where : '1=1';
				
				if( structKeyExists( col, 'fieldType' ) && col.fieldType eq 'one-to-many' && structKeyExists( col, 'cfc' ) ){
					// load child records here....
					col.fkcolumn = structKeyExists( col, 'fkcolumn' ) ? col.fkcolumn : col.name & this.getIDField();
					
					// If lazy == false we will aggressively load all child entities (this is expensive, so use sparingly)
					if( !lazy ){
						// Using evaluate because the onMissingMethod doesn't exist when using the dynamic function method (i.e.: func = this['getsomething']; func())
						setterFunc( evaluate("tmp.loadAllBy#col.fkcolumn#( this.getID(), childWhere )") );
						
					//If lazy == true, we will just overload the "getter" method with an anonymous method that will instantiate the child entity when called.
					}else{

						setterFunc( evaluate("tmp.loadAllBy#col.fkcolumn#( this.getID(), childWhere )") );						
						/****** ACF9 Dies when the below code exists *******/
						/* // First, set the property (child column in parent entity) to an array with a single index containing the empty child entity (to be loaded later)
						this[col.name] = ( structKeyExists( col, 'type' ) && col.type is 'array' ) ? [ duplicate( tmp ) ] : duplicate( tmp );					
						// Add a helper property to the parent object.  This will store the data necessary for the "getter" function to instantiate
						// the object when called.
						this["____lazy#hash(lcase(col.name))#"] = {
								"id" : this.getID(),
								"loadFuncName" : "LoadAllBy#col.fkcolumn#",
								"childWhere" : childWhere
							};
						// Now, override the getter for the property.  Instead of returning the value of the property, it will load the child data and return that.
						this["get" & col.name] = function( boolean lazy = true ) { 
							// The function name will help us to reference the "helper" struct attached to the parent instance earlier
							var name = GetFunctionCalledName();
								name = mid( name, 4, len( name ) );
							var args = this["____lazy#hash(lcase(name))#"];							
							var tmp = this[name][1];
							
							// Now load the child object into the entity property
							this[name] = evaluate('tmp.#(lazy)?'lazy':''##args['loadFuncName']#( args.id, args.childWhere )');
							// So that the getter doesn't re-load the child entity each time it is called, we'll just replace the
							// getter funcction with a more sensible "return value" function. Much faster this way.
							this[GetFunctionCalledName()] = function(){ return this[name];};							
							return this[name]; 
						}; */
						
					}

				}else if( structKeyExists( col, 'fieldType' ) && col.fieldType eq 'one-to-one' && structKeyExists( col, 'cfc' ) ){						
					if( !lazy ){
						writeLog('aggressively loading one-to-one object: #col.cfc# [#col.name#]');						
						var tmpID = len( trim( evaluate("this.get#col.fkcolumn#()") ) ) ? variables[ col.fkcolumn ] : '0';
						setterFunc( tmp.load( tmpID ) );
						
					}else{

						setterFunc( evaluate("tmp.load( this.get#col.fkcolumn#() )") );
						/****** ACF9 Dies when the below code exists *******/
						/* // First, set the property (child column in parent entity) as the empty child entity (to be loaded later)
						this[col.name] = duplicate( tmp );					
						// Add a helper property to the parent object.  This will store the data necessary for the "getter" function to instantiate
						// the object when called.
						this["____lazy#hash(lcase(col.name))#"] = {
								"id" : variables[col.fkcolumn],
								"loadFuncName" : "Load",
								"childWhere" : childWhere
							};
						// Now, override the getter for the property.  Instead of returning the value of the property, it will load the child data and return that.
						this["get" & col.name] = function( boolean lazy = true ) { 
							// The function name will help us to reference the "helper" struct attached to the parent instance earlier
							var name = GetFunctionCalledName();
								name = mid( name, 4, len( name ) );
							var args = this["____lazy#hash(lcase(name))#"];
							var tmp = this[name];
							
							// Now load the child object into the entity property
							// since we are calling a static method, we don't need to use evaluate as we do in the one-to-many routine
							this[name] = tmp.load( args.id, lazy );
							// So that the getter doesn't re-load the child entity each time it is called, we'll just replace the
							// getter funcction with a more sensible "return value" function. Much faster this way.
							this[GetFunctionCalledName()] = function(){ return this[name];};							
							return this[name]; 
						}; */


					}
				}
			}
		}			
		
		return this;		
		
	}

	public any function lazyLoad( required any ID, boolean lazy = false ){
		return load( ID = ID, lazy = true );
	}

	public query function getRecord( any ID ){
		var LOCAL = {};
		LOCAL.ID = structKeyExists( arguments, 'ID' ) ? arguments.ID : getID();
		var record = variables.dao.read( "
					SELECT #getIDField()# as ID, #variables.tabledef.getNonAutoIncrementColumns()# FROM #this.getTable()#
					WHERE #getIDField()# = #variables.dao.queryParam( value = val( LOCAL.ID ), cfsqltype = getIDFieldType() )#
				");
		variables._isNew = record.recordCount EQ 0;
		return record;
	}


    public query function get( any ID ){
        return getRecord( ID );
    }

	public query function list(string where = "", numeric limit = 20, string orderby = ""){
		var LOCAL = {};
		var record = variables.dao.read(sql = "
					SELECT #getIDField()# as ID, #variables.tabledef.getNonPrimaryKeyColumns()# FROM #this.getTable()#
					#len( trim( arguments.where ) ) ? ' WHERE ' & arguments.where : ''#
					#len(trim(arguments.orderby)) ? ' ORDER BY ' & arguments.orderby : ''#
					#arguments.limit GT 0 ? ' LIMIT ' & arguments.limit : ''#
				");
		return record;
	}

    public string function listAsJSON(string where = "", numeric limit = 20, string orderby = "", numeric row = 0){
        return serializeJSON( listAsArray( where = arguments.where, limit = arguments.limit, orderby = arguments.orderby, row = arguments.row) );
    }

    public array function listAsArray(string where = "", numeric limit = 20, string orderby = "", numeric row = 0){
        var LOCAL = {};
        var query = list( where = arguments.where, limit = arguments.limit, orderby = arguments.orderby );

        // Determine the indexes that we will need to loop over.
        // To do so, check to see if we are working with a given row,
        // or the whole record set.
        if (arguments.row){

            // We are only looping over one row.
            LOCAL.fromIndex = arguments.row;
            LOCAL.toIndex = arguments.row;

        } else {

            // We are looping over the entire query.
            LOCAL.fromIndex = 1;
            LOCAL.toIndex = query.recordCount;

        }

        // Get the list of columns as an array and the column count.
        LOCAL.columns = ListToArray( lcase(query.columnList) );
        LOCAL.columnCount = arrayLen( LOCAL.columns );

        // Create an array to keep all the objects.
        LOCAL.dataArray = [];

        // Loop over the rows to create a structure for each row.
        for ( LOCAL.rowIndex = LOCAL.fromIndex ; LOCAL.rowIndex LTE LOCAL.toIndex ; LOCAL.rowIndex++ ){

            // Create a new structure for this row.
            arrayAppend( LOCAL.dataArray, {} );

            // Get the index of the current data array object.
            LOCAL.dataArrayIndex = arrayLen( LOCAL.dataArray );

            // Loop over the columns to set the structure values.
            for ( LOCAL.columnIndex = 1 ; LOCAL.columnIndex LTE LOCAL.columnCount ; LOCAL.columnIndex++ ){

                // Get the column value.
                LOCAL.columnName = LOCAL.columns[ LOCAL.columnIndex ];

                // Set column value into the structure.
                LOCAL.dataArray[ LOCAL.dataArrayIndex ][ LOCAL.columnName ] = query[ LOCAL.columnName ][ LOCAL.rowIndex ];

            }

        }


        // At this point, we have an array of structure objects that
        // represent the rows in the query over the indexes that we
        // wanted to convert. If we did not want to convert a specific
        // record, return the array. If we wanted to convert a single
        // row, then return the just that STRUCTURE, not the array.
        if (arguments.row){

            // Return the first array item.
            return( LOCAL.dataArray[ 1 ] );

        } else {

            // Return the entire array.
            return( LOCAL.dataArray );

        }

    }

    /**
    * @hint I return a struct representation of the object in its current state.
    **/
	public struct function toStruct( array excludeKeys = [] ){

			var arg = "";
			var LOCAL = {};
			var returnStruct = {};
			
			for ( var prop in variables.meta.properties ){						
				arg = prop.name;
				LOCAL.functionName = "get" & arg;
				try
				{
					if( !findNoCase( '$$_', arg ) 
						&& ( !structKeyExists( this, arg ) || !isCustomFunction( this[arg] ) )
						&& !listFindNoCase( "meta,prop,arg,arguments,tmpfunc,this,dao,idfield,idfieldtype,idfieldgenerator,table,tabledef,deleteStatusCode,dropcreate,#ArrayToList(excludeKeys)#",arg ) ){
						
						if( structKeyExists( this, LOCAL.functionName ) ){
							//LOCAL.tmpFunc = structKeyExists( this, 'methods' ) ? this.methods[LOCAL.functionName] : this[LOCAL.functionName];							
							
							if( structKeyExists( variables, arg ) ){								
								returnStruct[lcase(arg)] = variables[arg];
								//returnStruct[lcase(arg)] = LOCAL.tmpFunc(arg); 							
							}

							if(structKeyExists( returnStruct, arg ) ){
								if(!isSimpleValue(returnStruct[arg])){

									if( isArray( returnStruct[arg] ) ){

										for( var i = 1; i LTE arrayLen( returnStruct[arg] ); i++ ){
											if( isObject( returnStruct[lcase(arg)][i] ) ){
												returnStruct[lcase(arg)][i] = returnStruct[lcase(arg)][i].toStruct( excludeKeys = excludeKeys );
											}
										}
									}else if( isObject( returnStruct[lcase(arg)] ) ){
										returnStruct[lcase(arg)] = returnStruct[arg].toStruct( excludeKeys = excludeKeys );								
									}
								}else if( isNumeric( returnStruct[ lcase( arg ) ] ) 
										&& listLast( returnStruct[ lcase( arg ) ], '.' ) GT 0 ){
										
									returnStruct[ lcase( arg ) ] = javaCast( 'int', returnStruct[ lcase( arg ) ] );
								}
							}
						}

					}
				}
				catch (any e){ writeDump(e);abort;}
			}
		return returnStruct;
	}

	/**
    * @hint I return a JSON representation of the object in its current state.
    **/
	public string function toJSON( array excludeKeys = [] ){

		var json = serializeJSON( this.toStruct( excludeKeys = excludeKeys ) );

		return json;
	}
	
	/**
    * @hint I save the current state to the database. I either insert or update based on the isNew flag 
    **/
	public any function save( struct overrides = {} ){
		// set the modified info
/* 		this.setModified_Datetime(now());
		this.setModified_By_Users_Id(getCurrentUserID()); */
		var tempID = this.getID();

		// Either insert or update the record
		if ( isNew() ){			
			// This is a new record, so let's set the created info
			/* this.setCreated_Datetime( now() );
			this.setCreated_By_Users_ID( getCurrentUserID() ); */

			// set uuid for fields set to generator="uuid"
			var col = {};			
			/* Merges properties and extends.properties into a CF array */
			var props = deSerializeJSON( serializeJSON( variables.meta.extends.properties ) );
			props.addAll( deSerializeJSON( serializeJSON( variables.meta.properties ) ) );
			for ( col in props ){	

				if( structKeyExists( col, 'generator' ) && col.generator eq 'uuid' ){

					variables[ col.name ] = lcase( createUUID() );
					variables._isDirty = true;
				}
				if( structKeyExists( col, 'formula' ) && len( trim( col.formula ) ) ){
					variables[ col.name ] = evaluate( col.formula );
				}
				
			}
			// On an insert we save the child records in two passes.
			// the first pass (this one) will save one-to-one related data.
			// This is done first so that the parent's ID can be set into this
			// entity instance before we persist to the database.  The second
			// pass will save the one-to-many related entities as those require 
			// that this record have an ID first.
			_saveTheChildren();

			var DATA = duplicate( this.toStruct() );
			
			for ( var col in DATA ){
				// the entity cfc could have a different column name than the given property name.  If the meta property "column" exists, we'll use that instead.
				var columnName = structFindValue( variables.meta, col );
				columnName = arrayLen( columnName ) && structKeyExists( columnName[1].owner, 'column' ) ? columnName[1].owner.column : col;			
				DATA[ LOCAL.columnName ] = DATA[col];
			}
			
			if (structCount(arguments.overrides) > 0){
				for ( var override in overrides ){
					DATA[override] = overrides[override];
				}
			}

			/* 		
            // attach parent ID to child
			for ( var i = 1; i LT arrayLen( variables.meta.properties ); i++ ){
				var col = variables.meta.properties[i];
					
				if( structKeyExists( col, 'fieldType' ) && col.fieldType eq 'many-to-one' && structKeyExists( col, 'cfc' ) ){
					writeDump(this);abort;
					// insert child records here....
					
					variables[col.fkcolumn] = variables[col.name];
					//writeDump(col);abort;
				}
			} */
			
			var newID = variables.dao.insert(
				table = this.getTable(),
				data = DATA
			); 
			//this.setID(newID);
			variables['ID'] = this['ID'] = newID;			
            tempID = newID;

            // This is the second pass of the child save routine.
            // This pass will pick up those one-to-many relationships and
            // persist the data with the new parent ID (this parent)
			_saveTheChildren( tempID );


		}else if( isDirty() ){
			/* Merges properties and extends.properties into a CF array */
			var props = deSerializeJSON( serializeJSON( variables.meta.extends.properties ) );
			props.addAll( deSerializeJSON( serializeJSON( variables.meta.properties ) ) );
			
			for ( col in props ){
				/**
				*  Find any "formula" type fields to evaluate.  Used for things like udpate timestamps
				**/			
				if( structKeyExists( col, 'formula' ) && len( trim( col.formula ) ) ){					
					variables[ col.name ] = evaluate( col.formula );
				}
			}	
			
			// On updates, we only need to run the child save routine 
			// once since the parent ID (this parent) already exists.
			// Runing this routine now will inject the child ID(s) into
			// this entity instance.
			_saveTheChildren();

			var DATA = duplicate( this.toStruct() );
			for ( var col in DATA ){
				// the entity cfc could have a different column name than the given property name.  If the meta property "column" exists, we'll use that instead.
				var columnName = structFindValue( variables.meta, col );
				columnName = arrayLen( columnName ) && structKeyExists( columnName[1].owner, 'column' ) ? columnName[1].owner.column : col;			
				DATA[ LOCAL.columnName ] = DATA[col];
			}

            DATA[getIDField()] = getID();
			if (structCount(arguments.overrides) > 0){
				for ( var override in overrides ){
					DATA[override] = overrides[override];
				}
			}
			
			/*** update the thing ****/
			variables.dao.update(
				table = this.getTable(),
				data = DATA
			);
		}
        	
       
		
		this.load(ID = tempID);

		return this;
	}

	private void function _saveTheChildren( any tempID = getID() ){
	 /* Now save any child records */        
		// NOTE: In CF9 you cannot use a for-in loop on meta properties, so we're using the old style for loop
		for ( var i = 1; i LTE arrayLen( variables.meta.properties ); i++ ){
			col = variables.meta.properties[i]; 
			if( structKeyExists( col, 'fieldType' ) && col.fieldType eq 'one-to-many' && val( tempID ) ){
				for ( var child in variables[ col.name ] ){
					//var FKFunc = duplicate( child["set" & col.fkcolumn] );					
					//FKFunc( tempID );
					// Using evaluate is the only way in cfscript (cf9) to retain context when calling methods 
					// on a nested object otherwise I'd use the above to set the fk col value
					try{
						/* TODO: when we no longer need to support ACF9, change this to use invoke() */
						evaluate("child.set#col.fkcolumn#( tempID )");					
					}catch (any e){
						writeDump(e);
						writeDump(child );
						writeDump(variables[ col.name ] );abort;
					}
					// call the child's save routine;
					child.save();					
					
				}
				
			}else if( structKeyExists( col, 'fieldType' ) && col.fieldType eq 'one-to-one' ){
				try{
					/* Set the object's FK to the value of the new parent record  */
					/* TODO: when we no longer need to support ACF9, change this to use invoke() */
					if( structKeyExists( variables, col.name ) ){
						var tmp = variables[col.name];
						evaluate("this.set#col.fkcolumn#( tmp.get#col.inverseJoinColumn#() )");
					}
										
				}catch (any e){
					writeDump(e);					
					writeDump(col);
					writeDump(variables);

					abort;
				}
			}
		} 	
	}

	/**
    * @hint I delete either the current record.
    **/
	public void function delete( boolean soft = false){

		if( len( trim( getID() ) ) gt 0 && !isNew() ){

			/* First delete any child records */        
			// NOTE: In CF9 you cannot use a for-in loop on meta properties, so we're using the old style for loop
			for ( var i = 1; i LTE arrayLen( variables.meta.properties ); i++ ){
				var col = variables.meta.properties[i];
				if( structKeyExists( col, 'fieldType' ) 
					&& ( col.fieldType eq 'one-to-many' || col.fieldType eq 'one-to-one' ) 
					&& ( !structKeyExists( col, 'cascade') || col.cascade != 'save-update') 
					){
					for ( var child in variables[ col.name ] ){
						try{
							child.delete( soft );					
						}catch (any e){
							writeDump(variables);
							writeDump(child);
							writeDump(e);
							writeDump(col.name);
							writeDump(variables[ col.name ] );abort;
						}
						
					}
					
				}
			}
			variables.dao.execute(sql="
					DELETE FROM #this.getTable()#
					WHERE #this.getIDField()# = #variables.dao.queryParam(value=getID(),cfsqltype='int')#
				");	
			/* disabled for now.  re-instate when getters handle deleted flag */
			/* if( soft && structKeyExists( variables, 'deleted' ) ){
				// "Soft" delete 
				variables.dao.execute(sql="
					UPDATE #this.getTable()#
					SET deleted = #variables.dao.queryParam(value=this.getDeleteStatusCode(),cfqsltype='int')#
					WHERE #this.getIDField()# = #variables.dao.queryParam(value=getID(),cfsqltype='int')#
				");				
			}else{

				// Now delete the parent 
				variables.dao.execute(sql="
					DELETE FROM #this.getTable()#
					WHERE #this.getIDField()# = #variables.dao.queryParam(value=getID(),cfsqltype='int')#
				");	
				
			} */
			this.init( dao = variables.dao );
		}
	}
	
	/* SETUP/ALTER TABLE */	
	/**
    * @hint I drop the current table.
    **/
	private function dropTable(){
		variables.dao.execute( "DROP TABLE IF EXISTS `#this.getTable()#`" );
	}

	/**
    * @hint I create a table based on the current object's properties.
    **/
	private function makeTable(){
		//writeDump(variables.meta);
		var tableSQL = "CREATE TABLE `#this.getTable()#` (";
		var columnsSQL = "";
		var primaryKeys = "";
		var indexes = "";
		var autoIncrement = false;
		var tmpstr = "";
		var col = {};

		// NOTE: In CF9 you cannot use a for-in loop on meta properties, so we're using the old style for loop
		for ( var i = 1; i LTE arrayLen( variables.meta.properties ); i++ ){
			col = variables.meta.properties[i];
			col.type = structKeyExists( col, 'type' ) ? col.type : 'string';
			col.type = structKeyExists( col, 'sqltype' ) ? col.sqltype : col.type;
			col.name = structKeyExists( col, 'column' ) ? col.column : col.name;
			col.persistent = structKeyExists( col, 'persistent' ) ? col.persistent : true;
			if( col.persistent && !structKeyExists( col, 'cfc' ) ){
				switch( col.type ){
					case 'string':
						tmpstr = '`#col.name#` varchar(#structKeyExists( col, 'length' ) ? col.length : '255'#) #structKeyExists(col,'fieldType') && col.fieldType eq 'id' ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & col.default & "'": ''#';
					break;
					case 'numeric':
						tmpstr = '`#col.name#` int(#structKeyExists( col, 'length' ) ? col.length : '11'#) unsigned #structKeyExists(col,'fieldType') && col.fieldType eq 'id' ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & col.default & "'": ''# #structKeyExists(col,'generator') && col.generator eq 'increment' ? ' AUTO_INCREMENT' : ''#';
					break;
					case 'date':
						tmpstr = '`#col.name#` datetime #structKeyExists(col,'fieldType') && col.fieldType eq 'id' ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & col.default & "'": ''#';
					break;
					case 'boolean': case 'tinyint':
						tmpstr = '`#col.name#` tinyint(1) #structKeyExists(col,'fieldType') && col.fieldType eq 'id' ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & (col.default ? 1 : 0) & "'": ''# #structKeyExists(col,'generator') && col.generator eq 'increment' ? ' AUTO_INCREMENT' : ''#';
					break;
					case 'text':
						tmpstr = '`#col.name#` text #structKeyExists(col,'fieldType') && col.fieldType eq 'id' ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & (col.default ? 1 : 0) & "'": ''# #structKeyExists(col,'generator') && col.generator eq 'increment' ? ' AUTO_INCREMENT' : ''#';
					break;
					default:
						tmpstr = '`#col.name#` #col.type# #structKeyExists( col, 'length' ) ? '(' & col.length & ')' : '(255)'# #structKeyExists(col,'fieldType') && col.fieldType eq 'id' ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & col.default & "'": ''#';
					break;
				}

				if( structKeyExists( col, 'generator' ) && col.generator eq 'increment' ){
					autoIncrement = true;
					columnsSQL = listPrepend( columnsSQL, tmpstr );
				}else{
					columnsSQL = listAppend( columnsSQL, tmpstr );
				}

				if( structKeyExists( col, 'fieldType' ) && col.fieldType eq 'id' ){
					if( structKeyExists( col, 'generator' ) && col.generator eq 'increment' ){
						primaryKeys = listPrepend(primaryKeys, '`#col.name#`');
					}else{
						primaryKeys = listAppend(primaryKeys, '`#col.name#`');
					}
				}
			}

		}

		tableSQL &= columnsSQL;
		
		if( listLen( primaryKeys ) ){
			tableSQL &=  ', PRIMARY KEY (#primaryKeys#)';
		}
		tableSQL &= ') ENGINE=InnoDB DEFAULT CHARSET=utf8;';
	
		//writeDump(tablesql);abort;
		variables.dao.execute(tableSQL);
		this.setTabledef( new tabledef(tableName = getTable(), dsn = dao.getDSN()) );

	}
	
}