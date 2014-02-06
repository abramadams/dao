/**
*	@hint Extend this component to add ORM like behavior to your model CFCs.  Requires CF10, Railo 4.x due to use of anonymous functions for lazy loading.
*   @version 0.0.54
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
		if( structCount( variables.tabledef.instance.tablemeta.columns ) NEQ arrayLen( variables.meta.properties ) ){			
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
					if ( structKeyExists( variables.tabledef.instance.tablemeta.columns[col], 'length' ) ){
						newProp["length"] = variables.tabledef.instance.tablemeta.columns[col].length;
					}
					arrayAppend( variables.meta.properties, newProp );				
				}

				found = false;

			}
		}


       /** 
       * This will hijack all of the setters and inject a function that will set the 
       * isDirty flag to true anytime data changes
       **/
       var setter = setFunc;
		for ( var prop in variables.meta.properties ){
			if( ( !structKeyExists( prop, 'setter' ) || prop.setter ) && ( !structKeyExists( prop, 'fieldType' ) ||  prop.fieldType does not contain '-to-' ) ){

				// copy the real setter function to a temp variable.
				if( structKeyExists( this, "set" & prop.name ) ){
					variables[ "$$__set" & prop.name ] = this[ "set" & prop.name ];
					
					// now override the setter with the new function that will set the dirty flag.					
					this[ "set" & prop.name ] = _getSetter( prop.type );					
				}
			}

		}
		/* Now if the model was extended, include those properties as well */
		if( structKeyExists( variables.meta, 'extends' ) && structKeyExists( variables.meta.extends, 'properties' )){
			for ( var prop in variables.meta.extends.properties ){
				if( ( !structKeyExists( prop, 'setter' ) || prop.setter ) && ( !structKeyExists( prop, 'fieldType' ) ||  prop.fieldType does not contain '-to-' ) ){
					// copy the real setter function to a temp variable.
					variables[ "$$__set" & prop.name ] = this[ "set" & prop.name ];
					// now override the setter with the new function that will set the dirty flag.

					this[ "set" & prop.name ] = _getSetter( prop.type );;
				}
			}
		}

	    return this;
	}
	/**
	* Convenience method for choosing the correct setter for the type. 
	**/
	private function _getSetter( any type = "" ){
		switch ( type ){
			case 'numeric':
			setter = setNumberFunc;
			case 'date':
			setter = setDateFunc;
			case 'boolean':
			setter = setBooleanFunc;
			default:
			setter = setFunc;
		}

		return setter;
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
				// If the property exists, compare the old value to the new value (case sensitive)
				if( structKeyExists( variables, propName ) ){
					//If the old value isn't identical to the new value, set the isDirty flag to true
					variables._isDirty = compare( v, variables[ propName ] ) != 0;
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
	private function setNumberFunc( required numeric v ){
		setFunc( v );
	}
	private function setBooleanFunc( required boolean v ){
		setFunc( v );
	}
	private function setDateFunc( required date v ){
		setFunc( v );
	}

	private any function getFunc( any name = "" ){

		if( len( trim( name ) ) ){
			return this[ name ];
		}

		if( left( getFunctionCalledName(), 3) == "get" && getFunctionCalledName() != 'getterFunc' ){

			var propName = mid( getFunctionCalledName(), 4, len( getFunctionCalledName() ) );
			return variables[ propName ];
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
		var limit = arguments.missingMethodName is "loadTop" ? arguments.missingMethodArguments[ 1 ] : "";
		var orderby = arguments.missingMethodName is "loadTop" ? "ORDER BY " & arguments.missingMethodArguments[2] : '';
		var where = "1=1";

		if( left( arguments.missingMethodName, 6 ) is "loadBy" 
			|| left( arguments.missingMethodName, 9 ) is "loadAllBy" 
			|| left( arguments.missingMethodName, 8 ) is "lazyLoad" 
			|| arguments.missingMethodName is "loadAll"
			|| arguments.missingMethodName is "loadTop"
			){
			
			var loadAll = ( left( originalMethodName, 7 ) is "loadAll" 
						  	|| left( originalMethodName , 11 ) is "lazyLoadAll" );
			/* if( left( originalMethodName, 7 ) is "loadAll" && arrayLen( arguments.missingMethodArguments ) EQ 1 ){
				loadAll = false;			
				limit = arguments.missingMethodArguments[ 1 ];				
			} */

			// Build where clause based on function name
			if( arguments.missingMethodName != "loadAll" && arguments.missingMethodName != "loadTop" ){
				arguments.missingMethodName = reReplaceNoCase(reReplaceNoCase(arguments.missingMethodName,'loadBy|loadAllBy|lazyLoadAllBy|lazyLoadBy','','all'), 'And','|','all' );
				queryArguments = listToArray( arguments.missingMethodName, '|' );
				for ( i = 1; i LTE arrayLen( queryArguments ); i++ ){
					args[ queryArguments[ i ] ] = arguments.missingMethodArguments[ i ];
					// the entity cfc could have a different column name than the given property name.  If the meta property "column" exists, we'll use that instead.
					LOCAL.columnName = structFindValue( variables.meta, queryArguments[ i ], 'all' )[ 1 ];
					if( !structKeyExists( LOCAL.columnName, 'owner' ) ){					
						LOCAL.columnName = structFindValue( variables.meta, ListChangeDelims( queryArguments[ i ], '', '_', false ), 'all' )[ 1 ];
					}
					
					LOCAL.columnName = structCount( LOCAL.columnName ) && structKeyExists( LOCAL.columnName.owner, 'column' ) ? LOCAL.columnName.owner.column : queryArguments[ i ];
					
					//if( structKeyExists( variables.meta.properties, ))
					recordSQL &= " AND #LOCAL.columnName# = #getDao().queryParam(value="#arguments.missingMethodArguments[ i ]#")#";
					//Setup defaults
					LOCAL.functionName = "set" & queryArguments[ i ];
					try{
						LOCAL.tmpFunc = this[LOCAL.functionName];
						LOCAL.tmpFunc(arguments.missingMethodArguments[ i ]);
					} catch ( any err ){}
				}											
			}
			if( structCount( missingMethodArguments ) GT arrayLen( queryArguments ) ){
				where = missingMethodArguments[ arrayLen( queryArguments ) + 1 ];
				where = len( trim( where ) ) ? where : '1=1';
			}

			record = variables.dao.read( 
				table = this.getTable(), 
				columns = "#( this.getIDField() NEQ 'ID' ) ? this.getIDField() & ' as ID,' : ''# #this.getDAO().getSafeColumnNames( this.getTableDef().getColumns() )#", 
				where = "WHERE #where# #recordSQL#", 
				orderby = orderby, 
				limit = limit, 
				name = "model_load_by_handler"
			);

			variables._isNew = record.recordCount EQ 0;
			
			//If a record existed, load it		
			if( record.recordCount == 1 && !left( originalMethodName, 7 ) is "loadAll" && !left( originalMethodName, 11 ) is "lazyLoadAll"){
				return this.load( ID = record, lazy = left( originalMethodName , 4 ) is "lazy" );
			// If more than one record was returned, or method called was a "loadAll" type, return an array of data.
			}else if( record.recordCount > 1 || left( originalMethodName, 7 ) is "loadAll" || left( originalMethodName , 11 ) is "lazyLoadAll" ) {
				var recordArray = [];
				var qn = queryNew( record.columnList );
				queryAddRow( qn, 1 );
				
				for ( var rec = 1; rec LTE record.recordCount; rec++ ){
					// append each record to the array. Each record will be an instance of the model entity in represents.  If lazy loading
					// this will be an empty entity instance with "overloaded" getter methods that instantiate when needed.
					for( var col in listToArray( record.columnList ) ){
						querySetCell( qn, col, record[ col ][ rec ] );
					}
					arrayAppend( recordArray, duplicate( this.load( ID = qn , lazy = ( left( originalMethodName , 4 ) is "lazy" ) || record.recordCount GTE 100 ) ) );    				    		

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
						variables._isDirty = false;
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
		var LOCAL = {};
		var props = variables.meta.properties;
		
		if ( isStruct( arguments.ID ) || isArray( arguments.ID ) ){
			// If the ID field was part of the struct, load the record first. This allows updating vs inserting
			if ( structKeyExists( arguments.ID, getIDField() ) && arguments.ID[ getIDField() ] != -1 ){
				this.load( ID = arguments.ID[ getIDField() ] );				
			}
			// Load the object based on the pased in struct. This may be a new record, or an update to an existing one.
			for ( var prop in props ){			
				//Load the properties based on the passed in struct.
				if ( listFindNoCase( structKeyList( arguments.ID ), prop.name ) && prop.name != getIDField() ){
					// We'll need to check some data types first though.					
					if ( prop.type == 'date' && findNoCase( 'Z', arguments.ID[ prop.name ] ) ){
						variables[ prop.name ] = convertHttpDate( arguments.ID[ prop.name ] );
					}else{
						variables[ prop.name ] = arguments.ID[ prop.name ];
					}
					variables._isDirty = true; // <-- may not be, but we can't tell so better safe than sorry					
				}
			}
			if ( structKeyExists( arguments.ID, getIDField() ) && !this.isNew() ){
				// If loading an existing entity, we can short-circuit the rest of this method since we've already loaded the entity
				return this;
			}

		}else{

			if ( isQuery( arguments.ID ) ){
				var record = arguments.ID;
			}else{
				var record = getRecord( ID = arguments.ID );			
			}
		
			for ( var fld in listToArray( record.columnList ) ){
				variables[ fld ] = record[ fld ][ 1 ];
				variables._isDirty = false;			
			}
		}
		/*  Now iterate the properties and see if there are any relationships we can resolve */		
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
							var tmp = this[name][ 1 ];
							
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

    /**
    * @hint The 'where' argument should be the entire SQL where clause, i.e.: "where a=queryParam(b) and b = queryParam(c)" 
    **/    
	public query function list(	
		string columns = "#this.getDAO().getSafeColumnName( this.getIDField() )# #( this.getIDField() NEQ 'ID' ) ? ' as ID' : ''#, #this.getDAO().getSafeColumnNames( this.getTableDef().getColumns() )#", 
		string where = "", 
		string limit = "", 
		string orderby = "", 
		string offset = ""){

		var LOCAL = {};
		var record = variables.dao.read( 
				table = this.getTable(), 
				columns = columns, 
				where = where, 
				orderby = orderby, 
				limit = limit,
				offset = offset
			);
		return record;
	}

    public string function listAsJSON(string where = "", string limit = "", string orderby = "", numeric row = 0, string offset = ""){
        return serializeJSON( listAsArray( where = arguments.where, limit = arguments.limit, orderby = arguments.orderby, row = arguments.row, offset = arguments.offset ) );
    }

    public array function listAsArray(string where = "", string limit = "", string orderby = "", numeric row = 0, string offset = ""){
        var LOCAL = {};
        var query = list( where = arguments.where, limit = arguments.limit, orderby = arguments.orderby, row = arguments.row, offset = arguments.offset );

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
        LOCAL.columns = ListToArray( camelCase(query.columnList) );
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
                //writeDump( [listLast( getTableDef().getCFSQLType( LOCAL.columnName ), '_' ) ]);
                if ( listLast( getTableDef().getCFSQLType( LOCAL.columnName ), '_' ) == "BIT"){
                	LOCAL.dataArray[ LOCAL.dataArrayIndex ][ LOCAL.columnName ] = val( query[ LOCAL.columnName ][ LOCAL.rowIndex ] ) ? true : false;
                }else{
                	LOCAL.dataArray[ LOCAL.dataArrayIndex ][ LOCAL.columnName ] = query[ LOCAL.columnName ][ LOCAL.rowIndex ];
                }

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
						&& ( !structKeyExists( this, arg ) || !isCustomFunction( this[ arg ] ) )
						&& !listFindNoCase( "meta,prop,arg,arguments,tmpfunc,this,dao,idfield,idfieldtype,idfieldgenerator,table,tabledef,deleteStatusCode,dropcreate,#ArrayToList(excludeKeys)#",arg ) ){
						
						if( structKeyExists( this, LOCAL.functionName ) ){
							//LOCAL.tmpFunc = structKeyExists( this, 'methods' ) ? this.methods[LOCAL.functionName] : this[LOCAL.functionName];							
							
							if( structKeyExists( variables, arg ) ){						
								returnStruct[ lcase( arg ) ] = variables[ arg ];
								//writeDump(variables[ arg ]);
								//returnStruct[ lcase( arg ) ] = LOCAL.tmpFunc( arg ); 							
							}

							if( structKeyExists( returnStruct, arg ) ){
								if( !isSimpleValue( returnStruct[ arg ] ) ){

									if( isArray( returnStruct[ arg ] ) ){

										for( var i = 1; i LTE arrayLen( returnStruct[ arg ] ); i++ ){
											if( isObject( returnStruct[ lcase( arg ) ][ i ] ) ){
												returnStruct[ lcase( arg ) ][ i ] = returnStruct[ lcase( arg ) ][ i ].toStruct( excludeKeys = excludeKeys );
											}
										}
									}else if( isObject( returnStruct[ lcase( arg ) ] ) ){
										returnStruct[ lcase( arg ) ] = returnStruct[ arg ].toStruct( excludeKeys = excludeKeys );								
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
		//writeDump(this.toStruct( excludeKeys = excludeKeys ));abort;
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
			var props = deSerializeJSON( serializeJSON( variables.meta.properties ) );
			/* Merges properties and extends.properties into a CF array */
			if( structKeyExists( variables.meta, 'extends' ) && structKeyExists( variables.meta.extends, 'properties' )){
				props.addAll( deSerializeJSON( serializeJSON( variables.meta.extends.properties ) ) );
			}

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
				columnName = arrayLen( columnName ) && structKeyExists( columnName[ 1 ].owner, 'column' ) ? columnName[ 1 ].owner.column : col;			
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
				var col = variables.meta.properties[ i ];
					
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

			var props = deSerializeJSON( serializeJSON( variables.meta.properties ) );
			/* Merges properties and extends.properties into a CF array */
			if( structKeyExists( variables.meta, 'extends' ) && structKeyExists( variables.meta.extends, 'properties' )){
				props.addAll( deSerializeJSON( serializeJSON( variables.meta.extends.properties ) ) );
			}
			
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
				columnName = arrayLen( columnName ) && structKeyExists( columnName[ 1 ].owner, 'column' ) ? columnName[ 1 ].owner.column : col;				
				DATA[ LOCAL.columnName ] = DATA[col];
			}
			
			DATA[getIDField()] = this.getID();
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
			col = variables.meta.properties[ i ]; 
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
				var col = variables.meta.properties[ i ];
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
    * @TODO Make the table creation db platform agnostic (using underlying dao)
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

		// Throw a helpful error message if the BaseModelObject was instantiated directly.		
		if( listLast( variables.meta.name , '.' ) == "BaseModelObject"){
			throw("If invoking BaseModelObject directly the table must exist.  Please create the table: '#this.getTable()#' and try again.");
		}
		// NOTE: In CF9 you cannot use a for-in loop on meta properties, so we're using the old style for loop				
		for ( var i = 1; i LTE arrayLen( variables.meta.properties ); i++ ){
			col = variables.meta.properties[ i ];
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
					case 'tinyint':
						tmpstr = '`#col.name#` tinyint(1) #structKeyExists(col,'fieldType') && col.fieldType eq 'id' ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & (col.default ? 1 : 0) & "'": ''# #structKeyExists(col,'generator') && col.generator eq 'increment' ? ' AUTO_INCREMENT' : ''#';
					break;
					case 'boolean': case 'bit':
						tmpstr = '`#col.name#` BIT #structKeyExists(col,'fieldType') && col.fieldType eq 'id' ? 'NOT' : ''# NULL #structKeyExists(col,'default') ? "DEFAULT '" & (col.default ? true : false) & "'": ''#';
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
	/* Utilities */
	/**
	* @hint tries to camelCase based on nameing conventions. For instance if the field name is "isdone" it will convert to "isDone".
	**/
	private function camelCase( required string str ){
		str = lcase( str );
		return reReplaceNoCase( str, '\b(is|has)(\w)', '\1\u\2', 'all' );
	}
	/**
	* @hint Converts http date to CF date object (since one cannot natively in CF9).
	* @TODO Make this better :)
	**/
	private date function convertHttpDate( required string httpDate ){
		return parseDateTime( listFirst( httpDate, 'T' ) & ' ' & listFirst( listLast( httpDate, 'T' ), 'Z' ) );
	}


/* *************************************************************************** */
/* BreezeJS interface */
/* *************************************************************************** */
	public function getBreezeMetaData(){
    	var breezeMetaData = {
		    "schema" = {
		        "namespace" = "#getBreezeNameSpace()#",
		        "alias" = "Self",
		        "d4p1 =UseStrongSpatialTypes" = "false",
		        "xmlns =d4p1" = "http://schemas.microsoft.com/ado/2009/02/edm/annotation",
		        "xmlns" = "http://schemas.microsoft.com/ado/2009/11/edm",
		        "cSpaceOSpaceMapping" = [
		            [
		                "#getBreezeNameSpace()#.#getBreezeEntityName()#",
		                "#getBreezeNameSpace()#.#getBreezeEntityName()#"
		            ]
		        ],
		        "entityType" = {
		            "name" = getBreezeEntityName(),
		            "key" = {
		                "propertyRef" = {
		                    "name" = lcase( getIDField() ) 
		                }
		            },
		            "property" = generateBreezeProperties()
		        },
		        "entityContainer" = {
		            "name" = "#getDao().getDSN()#Context",
		            "entitySet" = {
		                "name" = "#getBreezeNameSpace()#",
		                "entityType" = "Self.#getBreezeEntityName()#"
		            }
		        }
		    }
		};

		return breezeMetaData;
	}

	public array function listAsBreezeData( string filter = "", string orderby = "", string skip = "", string top = "" ){
		if( len(trim( filter ) ) ){
			/* parse breezejs filter operators */
			filter = reReplaceNoCase( filter, ' (eq|==|Equals) (\b.*\w)(\)|)', ' = $queryParam(value=\2)$\3', 'all' );
			filter = reReplaceNoCase( filter, ' (ne|\!=|NotEquals) (\b.*\w)(\)|)', ' != $queryParam(value=\2)$\3', 'all' );
			filter = reReplaceNoCase( filter, ' (lte|<=|LessThanOrEqual) (\b.*\w)(\)|)', ' <= $queryParam(value=\2)$\3', 'all' );
			filter = reReplaceNoCase( filter, ' (gte|>=|GreaterThanOrEqual) (\b.*\w)(\)|)', ' >= $queryParam(value=\2)$\3', 'all' );
			filter = reReplaceNoCase( filter, ' (lt|<|LessThan) (\b.*\w)(\)|)', ' < $queryParam(value=\2)$\3', 'all' );
			filter = reReplaceNoCase( filter, ' (gt|>|GreaterThan) (\b.*\w)(\)|)', ' > $queryParam(value=\2)$\3', 'all' );
			/* fuzzy operators */
			filter = reReplaceNoCase( filter, ' (substringof|contains) (\b.*\w)(\)|)', ' like $queryParam(value="%\2%")$\3', 'all' );
			filter = reReplaceNoCase( filter, ' (startswith) (\b.*\w)(\)|)', ' like $queryParam(value="\2%")$\3', 'all' );
			filter = reReplaceNoCase( filter, ' (endswith) (\b.*\w)(\)|)', ' like $queryParam(value="%\2")$\3', 'all' );
			/* TODO: figure out what "any|some" and "all|every" filters are for and factor them in here */
		}
		var list = listAsArray( where = len( trim( filter ) ) ? "WHERE " & preserveSingleQuotes( filter ) : "", orderby = arguments.orderby, offset = arguments.skip, limit = arguments.top );		
		var row = "";
		var data = [];
		for( var i = 1; i LTE arrayLen( list ); i++ ){
			row = list[ i ];			
			row["$type"] = "#getBreezeNameSpace()#.#getBreezeEntityName()#, DAOBreezeService";				
			row["$id"] = row[ getIDField() ];
			arrayAppend( data, row );
			row = "";
		}
		return data;

	}

	public array function toBreezeJSON(){
		var data  = this.toStruct();
		data["$type"] = "#getBreezeNameSpace()#.#getBreezeEntityName()#, DAOBreezeService";				
		data["$id"] = data[ getIDField() ];

		return [data];
	}
	
	/**
	* @hint I accept an array of breeze entities and perform the appropriate DB interactions based on the metadata. I return the Entity struct with the following:
	* 	Entities: An array of entities that were sent to the server, with their values updated by the server. For example, temporary ID values get replaced by server-generated IDs.
	* 	KeyMappings: An array of objects that tell Breeze which temporary IDs were replaced with which server-generated IDs. Each object has an EntityTypeName, TempValue, and RealValue.
	* 	Errors (optional): An array of EntityError objects, indicating validation errors that were found on the server. This will be null if there were no errors. Each object has an ErrorName, EntityTypeName, KeyValues array, PropertyName, and ErrorMessage.
	* 
	**/
	public struct function breezeSave( required any entities ){
		var errors = [];
		var keyMappings = [];

		for (var entity in arguments.entities ){
			this.load( entity );
			if( entity.entityAspect.EntityState == "Deleted" ){ // other states: Added, Modified
				this.delete();
			}else{
				try{
					this.save();
					// Now setup some return data for breeze client 
					entity['$type'] = "#getBreezeNameSpace()#.#getBreezeEntityName()#";
					if ( structKeyExists( entity.entityAspect.originalValuesMap, entity.entityAspect.autoGeneratedKey.propertyName ) ){
						arrayAppend( keyMappings, { "EntityTypeName" = entity['$type'], "TempValue" = entity.entityAspect.originalValuesMap[ entity.entityAspect.autoGeneratedKey.propertyName ], "RealValue" = this.getID() } );
					}else if ( entity.entityAspect.entityState == 'Added' ){							
						arrayAppend( keyMappings, { "EntityTypeName" = entity['$type'], "TempValue" = -1, "RealValue" = this.getID() } );
					}
					// remove the entityAspect key from the struct.  We don't need it in the returned data; in fact breeze will error if it exists..
					structDelete( entity, 'entityAspect' );
				} catch( any e ){	
					// append any errors found to return data for breeze client;
					arrayAppend( errors, {"ErrorName" = e.error, "EntityTypeName" = entity.entityAspect.entityTypeName, "KeyValues" = [], "PropertyName" = "", "ErrorMessage" = e.detail } );
				}
			}
		}

		var ret = { "Entities" = arguments.entities, "KeyMappings" = keyMappings };			
		if ( arrayLen( errors ) ){
			ret["Errors"] = errors;
		}

		return ret;
	}

	private function getBreezeNameSpace(){
		var basePath = getDirectoryFromPath(getbaseTemplatePath());
		var curpath = expandPath('/');		
		var m = reReplace( basepath, "#curpath#",chr(888));
		m = listRest( m, chr(888) );
		var reversed = "";
		m = listChangeDelims(m ,".", '/');
		for( var i = listLen( m ); i GT 0; i-- ){
			reversed = listAppend( reversed, listGetAt( m, i ) );
		}
		return "#reReplace( len( trim( reversed ) ) ? reversed : 'model', '\b(\w)', '\u\1', 'all')#.#reReplace( dao.getDSN(), '\b(\w)' ,'\u\1', 'all')#";		
	}
	private function getBreezeEntityName(){
		return structKeyExists( variables.meta, 'singularName' ) ? variables.meta.singularName : this.getTable();
	}
	
	public function generateBreezeProperties(){
		var props = [];
		//var prop = { "validators" = [] };
		var prop = { };

		//variables.meta = deSerializeJSON( serializeJSON( variables.meta ) );		
		for ( var col in variables.meta.properties ){
			/* TODO: flesh out relationships here */
			if( !structKeyExists( col, 'type') || ( structKeyExists( col, 'persistent' ) && !col.persistent ) ){ 
				continue;
			} 
			prop["name"] = col.name;

			prop["type"] = getBreezeType( col.type );
			//prop["defaultValue"] = structKeyExists( col, 'default' ) ? col.default : "";					
			prop["nullable"] = structKeyExists( col, 'notnull' ) ? !col.notnull : true;

			/* is part of a key? */
			if( structKeyExists( col, 'fieldType' ) && col.fieldType == 'id' 
				|| structKeyExists( col, 'uniquekey' ) ){
			 	prop["name"] = lcase( col.name );
				//prop["isPartOfKey"] = true;
				prop["d4p1:StoreGeneratedPattern"] = "Identity";
				prop["nullable"] = "false";
			} 

			/* define validators */
		/* 	var validators = [];
			if ( !prop["nullable"] ){
				arrayAppend( validators, {"validatorName" = "required"} );
			} */

			/* max length */
			if( structKeyExists( col, 'length' ) ){
				prop["fixedLength"] = "false";
				prop["maxLength"] = col.length;
				/* arrayAppend( validators, {
											"maxLength"= col.length,
                        					"validatorName"= "maxLength"
                        				});	 */
			}
			if( prop["type"] == "Edm.String" ){
				prop["unicode"] = "true";
			}
			/* if( arrayLen( validators ) ){
			//	arrayAppend( prop["validators"], validators );
			} */
			arrayAppend( props, prop );
			prop = {};
		}

		return props;
	}

	private function getBreezeType( required string type ){
		var CfToBreezeTypes = {
			"string" = "String",
			"varchar" = "String",
			"char" = "String",
			"boolean" = "Boolean",
			"bit" = "Boolean",
			"numeric" = "Int32",
			"int" = "Int32",
			"integer" = "Int32",
			"date" = "DateTime",
			"datetime" = "DateTime",
			"guid" = "Guid"
		};

		return "Edm." & ( structKeyExists( CfToBreezeTypes, type ) ? CfToBreezeTypes[ type ] : type );

	}

}