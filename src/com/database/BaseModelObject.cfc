/**
*	Copyright (c) 2013-2014, Abram Adams
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
*****************************************************************************************
*	Extend this component to add ORM like behavior to your model CFCs.
*	Requires CF10, Railo 4.x due to use of anonymous functions for lazy loading.
*	Can be altered to run on CF9 by commenting out the anonymous function code
*   aroud line ~521 with the heading: ****** ACF9 Dies when the below code exists *******
* 	and and uncomment the code above it using the setterFunc() call.
*   @version 0.0.82
*   @dependencies { "dao" : ">=0.0.64" }
*   @updated 12/30/2014
*   @author Abram Adams
**/

component accessors="true" output="false" {

	property name="_norm_version" type="string";
	property name="_norm_updated" type="string";

	/* properties */
	property name="table" type="string" persistent="false";
	property name="parentTable" type="string" persistent="false";
	property name="IDField" type="string" persistent="false";
	property name="IDFieldType" type="string" persistent="false";
	property name="IDFieldGenerator" type="string" persistent="false";
	property name="deleteStatusCode" type="numeric" persistent="false";

	/* Table make/reload options */
	property name="dropcreate" type="boolean" default="false" persistent="false";
	/* Relationship properties*/
	property name="autoWire" type="boolean" persistent="false" hint="If false, I prevent the load() method from auto wiring relationships.  Relationships can be bolted on after load, so this can be used for performance purposes.";
	property name="dynamicMappings" type="struct" persistent="false" hint="Defines alias to table name mappings.  So if you want the entity property to be OrderItems, but the table is order_items you would pass in { 'OrderItems' = 'order_items' } ";
	property name="__fromCache" type="boolean" persistent="false";
	property name="__cacheEntities" type="boolean" persistent="false";
	property name="cachedWithin" type="any" persistent="false";
	property name="__debugMode" type="boolean";

	/* Dependancies */
	property name="dao" type="dao" persistent="false";
	property name="tabledef" type="tabledef" persistent="false";

	// Some "private" variables
	_isNew = true;
	_isDirty = false;
	_children = [];

	public any function init( 	string table = "",
								string parentTable = "",
								string idField = "ID",
								string idFieldType = "",
								string idFieldGenerator = "",
								numeric deleteStatusCode = 1,
								any dao = "",
								boolean dropcreate = false,
								boolean createTableIfNotExist = false,
								struct dynamicMappings = {},
								boolean autoWire = true,
								boolean cacheEntities = false, /* 2014-11-12 still experimental */
								boolean debugMode = false,
								any cachedWithin = createTimeSpan( 0, 0, 0, 2 ) ){

		var LOCAL = {};
		set__FromCache( false );
		set__cacheEntities( cacheEntities );
        // If true, will tell logIt() to actually write to log.
		set__debugMode( debugMode );

		// Make sure we have a dao (see dao.cfc)
		if( isValid( "component", arguments.dao ) ){
			variables.dao = arguments.dao;
		} else {
			throw("You must have a dao" & arguments.dao );
		}

		variables.dropcreate = arguments.dropcreate;
		// used to introspect the given table.
        variables.meta =_getMetaData();

        // Convenience properties so developers can find out which version they are using.
        if( structKeyExists( variables.meta.extends, 'version' ) ){
	        set_Norm_Version( variables.meta.extends.version );
	        set_Norm_Updated( variables.meta.extends.updated );
        }else if( structKeyExists( variables.meta, 'version' ) ){
	        set_Norm_Version( variables.meta.version );
	        set_Norm_Updated( variables.meta.updated );
        }


		if( !len( trim( arguments.table ) ) ){
			// If the table name was not passed in, see if the table property was set on the component
			if( structKeyExists( variables.meta,'table' ) ){
				setTable( variables.meta.table );
			// If not, see if the table property was set on the component it extends
			}else if( structKeyExists( variables.meta.extends, 'table' ) ){
				setTable( variables.meta.extends.table );
			// If not, use the component's name as the table name
			}else if( structKeyExists( variables.meta, 'fullName' ) ){
                setTable( listLast( variables.meta.fullName, '.') );
			}else{
				throw('Argument: "Table" is required if the component declaration does not indicate a table.','variables','If you don''t pass in the table argument, you must specify the table attribute of the component.  I.e.  component table="table_name" {...}');
			}
		}else{
			setTable( arguments.table );
		}
		setParentTable( arguments.parentTable );
		setcachedWithin( arguments.cachedWithin );
		setDynamicMappings( arguments.dynamicMappings );

		// For development use only, will drop and recreate the table in the database
		// to give you a clean slate.
		if( variables.dropcreate ){
			logIt('droppping #this.getTable()#');
			dropTable();
			logIt('making #this.getTable()#');
			makeTable();
		}else{
			try{
				var mapping = _getMapping( getTable() );
				// load the table definition based on the given table.
				variables.tabledef = new tabledef( tableName = mapping.table, dsn = getDao().getDSN() );
			} catch (any e){
				// writeDump([e,arguments]);abort;
				if( e.type eq 'Database' ){
					if (e.Message neq 'Datasource #getDao().getDSN()# could not be found.'){
						// The table didn't exist, so let's make it
						if( createTableIfNotExist ){
							makeTable();
						}else{
							return  false;
						}
					}else{
						writeDump( this );
						throw( e.message );
					}
				}else{
					rethrow;
				}
			}
		}

		// Setup the ID (primary key) field.  This can be used to generate id values, etc..
		setIDField( arguments.IDField );
		setAutoWire( arguments.autoWire );
        setIDFieldType( variables.tabledef.getDummyType( variables.tabledef.getColumnType( getIDField() ) ) );
		setDeleteStatusCode( arguments.deleteStatusCode );
        variables.dao.addTableDef( variables.tabledef );

        variables.meta.properties =  structKeyExists( variables.meta, 'properties' ) ? variables.meta.properties : [];

		// If there are more columns in the table than there are properties, let's dynamically add them
		// This will allow us to dynamically stub out the entity "class".  So one could just create a
		// CFC without any properties, then point it to a table and get a fully instantiated entity, or they
		// could directly instantiate BaseModelObject and pass it a table name and get a fully instantiated entity.

		var found = false;
		if( structCount( variables.tabledef.instance.tablemeta.columns ) NEQ arrayLen( variables.meta.properties ) ){
			// We'll loop through each column in the table definition and see if we have a property, if not, create one.
			// @TODO when CF9 support is no longer needed, use an arrayFind with an anonymous function to do the search.
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

					variables[ col ] = this[ col ] = "";
					variables["set" & col] = this["set" & col] = this.methods["set" & col] = setFunc;
					variables["get" & col] = this["get" & col] = this.methods["get" & col] = getFunc;
					var mapping = _getMapping( col );
					var newProp = {
						"name" = mapping.property,
						"column" = col,
						"generator" = variables.tabledef.instance.tablemeta.columns[col].generator,
						"fieldtype" = variables.tabledef.instance.tablemeta.columns[col].isPrimaryKey ? "id" : "",
						"type" = variables.tabledef.getDummyType(variables.tabledef.instance.tablemeta.columns[col].type),
						"dynamic" = true
					};
					if( structKeyExists( getDynamicMappings(), col ) ){
						newProp["table"] = mapping.table;
						newProp["fkcolumn"] = col;
					}
					if( structKeyExists( mapping, 'cfc' ) ){
						newProp["cfc"] = mapping.cfc;
					}
					if ( structKeyExists( variables.tabledef.instance.tablemeta.columns[col], 'length' ) ){
						newProp["length"] = variables.tabledef.instance.tablemeta.columns[col].length;
					}
					if( !structIsEmpty( newProp ) ){
						arrayAppend( variables.meta.properties, newProp );
					}
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
					prop.type = structKeyExists( prop, 'type' ) ? prop.type : '';
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
					prop.type = structKeyExists( prop, 'type' ) ? prop.type : '';
					this[ "set" & prop.name ] = _getSetter( prop.type );
				}
			}
		}

	    return this;
	}

	/**
	* I inject a property into the current instance.  Shorthand for inserting the
	* property into the "this" and "variables" scope
	**/
	private function _injectProperty( required string name, required any val, struct prop = {} ){
		variables[ name ] = val;
		this[ name ] = val;
		if( structCount( prop ) ){
			// Define the property struct (including any existing mappings)
			var mapping = _getMapping( name );
			var newProp = {
							"name" = mapping.property,
							"column" = name,
							"generator" = "",
							"fieldtype" = "",
							"type" = "",
							"dynamic" = true
						};
		}else{
			// the prop was passed in, add that to the metadata.
			var newProp = prop;
		}
		if( !structIsEmpty( prop ) ){
			arrayAppend( variables.meta.properties, newProp );
		}
	}

	/**
	* I return the current object's metadata in a true CF struct
	**/
	private function _getMetaData(){
		return deSerializeJSON( serializeJSON( getMetadata( this ) ) );

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
	* Convenience method for synthesised setters.
	**/
	private function _setter( any value ){
		var propName = getFunctionCalledName();
		propName = mid( propName, 4, len( propName ) );
		variables[ propName ] = value;
		if( isSimpleValue( variables[ propName ] ) && !variables._isDirty ){
			variables._isDirty = compare( value, variables[ propName ] ) != 0;
		}else{
			this.set_isDirty( true );
		}
		// logIt('set called via _setter as #propname# and dirty is: #variables._isDirty#');
	}

	/**
	* Convenience method for synthesised getters.
	**/
	private function _getter( any value ){
		var propName = getFunctionCalledName();
		// logIt(propName);
		propName = mid( propName, 4, len( propName ) );
		return variables[ propName ];
	}

	/**
	* Convenience method for synthesised adders.
	**/
	private function _adder( any value ){
		var propName = getFunctionCalledName();
		propName = mid( propName, 4, len( propName ) );
		this.set_isDirty( true );
		try{
			if( !value.isNew() ){
				// Whole lot of rigmarole to see if the entity already exists (based on the "ID" value) before appending.
				// If it does, we'll replace it instead
				var found = structFindValue( { "test" = variables[ propName ] }, value.getID(), 'all');
				if( arrayLen( found ) ){
					for( var i = 1; i lte arrayLen( found ); i++ ){
						// If the value was found in the ID property, we have a match.
						if( found[ i ].key == getIDField() ){
							// This will extract the original array's index position for replacing.
							var idx = reReplaceNoCase( found[ i ].path, '.*\[(.*)\].*','\1', 'all' );
							variables[ propName ][ idx ] = value;
							this[ propName ][ idx ] = value;
							return;
						}
					}
				}
			}
			// If we made it this far, the entity wasn't found in the array.
			arrayAppend( variables[ propName ], value );
			arrayAppend( this[ propName ], value );

		}catch( any e ){
			writeDump([propName , value.getID(), e ]);abort;
		}
	}

	/**
	* Convenience method for synthesised removers.
	**/
	private function _remover( any index ){
		var propName = getFunctionCalledName();
		var idx = index;
		propName = mid( propName, 7, len( propName ) );
		this.set_isDirty( true );
		try{
			if( isObject( index ) ){
				idx = arrayFind( variables[ propName ], index );
			}
			if( idx > 0 ){
				arrayDeleteAt( variables[ propName ] , idx );
			}

		}catch( any e ){
			writeDump([propName , index, e ]);abort;
		}
		// TODO: work out a way to cascade delete the removed child...
	}

	/**
	* Convenience method for synthesised 'has' checks (i.e. hasOrders) .
	**/
	private function _has(){
		var propName = getFunctionCalledName();
		// logIt(propName);
		propName = mid( propName, 4, len( propName ) );
		return isArray( variables[ propName ] ) && arrayLen( variables[ propName ] );
	}

	/**
	* This function will replace each public setter so that the isDirty
	* flag will be set to true anytime data changes.
	**/
	private function setFunc( required any v ){
		// prevent infinite recursion
		if( getFunctionCalledName() == 'tmpFunc' ){
			return;
		}

		if( left( getFunctionCalledName(), 3) == "set" && getFunctionCalledName() != 'setterFunc' ){
			var propName = mid( getFunctionCalledName(), 4, len( getFunctionCalledName() ) );

			// If the property exists, compare the old value to the new value (case sensitive)
			if( structKeyExists( variables, propName ) && isSimpleValue( v ) ){
				// If the old value isn't identical to the new value, set the isDirty flag to true
				// This only needs to be set if it isn't already
				if( !variables._isDirty ){
					variables._isDirty = compare( v, variables[ propName ] ) != 0;
				}
			}

			// logIt('set called via setFunc as #getFunctionCalledName()# and dirty is: #variables._isDirty#: new value: "#v#" original value: "#variables[propname]#"');
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

		if( left( getFunctionCalledName(), 3) == "get" && getFunctionCalledName() != 'getterFunc' && getFunctionCalledName() != 'getter' ){

			var propName = mid( getFunctionCalledName(), 4, len( getFunctionCalledName() ) );
			return variables[ propName ];
		}

		return "";

	}

	/**
	* I return true if the current state represents a new record/document
	**/
	public boolean function isNew(){
		return variables._isNew;
	}

	/**
	* I return true if any of the original data has changed.  This is a read-only property because the
	* entity obejct properties' setters set this flag when data actually changes.
	**/
	public boolean function isDirty(){
		return variables._isDirty;
	}
	public function set_isDirty( required boolean isDirty ){
		variables._isDirty = isDirty;
	}

	/**
	* I provide support for dynamic method calls for loading data into model objects.
	* Use loadBy<column>And<column>And....() to load data using several column filters.
	* This generates an SQL statement to retrieve the desired data.
	* I also handle "lazy" loading methods like: lazyLoadAllBy<column>And<column>And...();
	*
	* Allowed function patterns:
	* loadBy<column>And<column>And....() <-- returns an array of instantiated entity objects matching criteria (or a single instantiated instance if only one record is returned)
	* loadTop( limit, order_by ) <-- returns array of instantiated entity objects
	* loadFirstBy<column>And<column>And....() <--- same as loadBy.. but always limits to the one record and only returns the instantiated object.
	* loadAll() <-- returns an array of instantiated entity objects for every record in the table (well it returns 100, then lazy loads the rest)
	* NOTE:
	* Prefix any of the above patterns with Lazy and it will only load the entity data and not any child data.  Instead, the child properties
	* are replaced with getter methods that trigger a load when called.  So when you lazy load Parent that has children, the children entities
	* don't get loaded until you call Parent.getChildren().getProperty(); (where Children is the actual name of the child entity and Propety is
	* the name of the actual property in the child entity)
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

		// ReturnType allows us to return a different representation of the object if loading an entity or getting related entities.
		var returnType = "object";
		if( right( arguments.missingMethodName, 7 ) == "asArray" ){
			returnType = "array";
			arguments.missingMethodName = mid( arguments.missingMethodName, 1, len( arguments.missingMethodName ) - 7 );
		}else if( right( arguments.missingMethodName, 8 ) == "asStruct" ){
			returnType = "struct";
			arguments.missingMethodName = mid( arguments.missingMethodName, 1, len( arguments.missingMethodName ) - 8 );
		}else if( right( arguments.missingMethodName, 6 ) == "asJSON" ){
			returnType = "json";
			arguments.missingMethodName = mid( arguments.missingMethodName, 1, len( arguments.missingMethodName ) - 6 );
		}

		// writeDump([missingMethodName,left( arguments.missingMethodName, 3 ),mid( arguments.missingMethodName, 4, len( arguments.missingMethodName ) ), missingMethodName contains "By"]);abort;
		// Handle dynamic getters for relationhsip entities
		if( left( arguments.missingMethodName, 3 ) is "get"){
			var getterInstructions = mid( arguments.missingMethodName, 4, len( arguments.missingMethodName ) );
			if( getterInstructions does not contain "By"){
				if( structKeyExists( variables, getterInstructions ) ){
					// Pretend to be a getter
					// Handle getters that may not have been assigned to dynamic properties
					return variables[ getterInstructions ];
				}
				// If the "getter" doesn't contain a "by" clause, we'll look to see if the current entity
				// has a FK matching the convention <name>_ID.  So if the method call was getUsers() and the
				// current entity has a users_ID property we will try to load an entity based on a Users table
				// and populate it with the record matching the current entitty's users_ID value.
				try{
					var newTableName = var propertyName = getterInstructions;
					var mapping = _getMapping( getterInstructions );
					var propertyName = propertyName == mapping.table ? mapping.property : propertyName;
					// newTableName = structKeyExists( getDynamicMappings(), getterInstructions ) ? getDynamicMappings()[ getterInstructions ] : newTableName;
					// MANY-TO-ONE
					if( structKeyExists( mapping, 'key') && ( structKeyExists( variables, mapping.table & "_ID" ) || structKeyExists( variables, mapping.key ) ) ){
						// NOTE: If mapping.key didn't exist that means the "getterInstructions" did not resolve to a table or a foriegn key to a parent table that we could decipher.
						// Loading Many to One relationship for getterInstructions
						// logIt('CALLING _getManyToOne() for #mapping.table# (#propertyName#) #returnType# (dynamically called via #arguments.missingMethodName# on #this.getTable()# for #this.getID()# [ #mapping.table# : #mapping.property# : #mapping.key#])');
						variables[ propertyName ] = this[ propertyName ] = _getManyToOne( table = lcase( mapping.table ), property = propertyName, fkColumn = mapping.key != mapping.table ? mapping.key : mapping.table & "_ID", returnType = returnType );
						// logIt('loaded child #variables[propertyName].getID()# from #mapping.table# into property #propertyName#');

					}else{

						// ONE-TO-MANY
						// If the current entity didn't have a FK to the table, maybe we need to load a one-to-many.
						// Let's try to find a table matching the getterInstructions and load all records matching the
						// current entity's ID value.

						// newTableName = structKeyExists( getDynamicMappings(), newTableName ) ? getDynamicMappings()[ newTableName ] : newTableName;
						// logIt('CALLING _getOneToMany() for #newTableName# (#propertyName#) #returnType# (dynamically called via #arguments.missingMethodName# on #this.getTable()# for #this.getID()# [ #mapping.table# : #mapping.property#])');
						var ret =  _getOneToMany( table = lcase( mapping.table ), property = propertyName, returnType = returnType );
						// logIt('And that returned an object? #isObject( ret )#');
						return isObject( ret ) ? ret : variables[ propertyName ];

					}
					return variables[ propertyName ];
				} catch ( any e ){
					if( e.type != 'BMO' ){
						// throw(e.detail);
						writeDump([e,mapping]);abort;
					}
				}
			}else if( getterInstructions contains "By"){
				try{
					var newTableName = var propertyName = left( getterInstructions, findNoCase( 'by', getterInstructions ) - 1 );
					var byClause = mid( getterInstructions, findNoCase( 'by', getterInstructions ) + 2, len( getterInstructions ) );

					var mapping = _getMapping( newTableName );
					var propertyName = propertyName == mapping.table ? mapping.property : propertyName;

					// writeDump([arguments,newTableName,byClause,variables[byClause],_getManyToOne( table = lcase( newTableName ), fkColumn = "modified_by_users_ID" ) ]);abort;
					if( structKeyExists( variables, byClause ) || structKeyExists( variables, mapping.key ) ){
						// MANY-TO-ONE
						// If the "getter" contains the "by" clause, we'll try to load
						// the child record based on the "by" clause.  For instance
						// if the method call was getUsersByCreated_Users_ID we would try to load
						// the record from the users table where users.ID == the current entity's
						// Created_Users_ID value.
						variables[ propertyName ] = this[ propertyName ] = _getManyToOne( table = lcase( mapping.table ), property = propertyName, fkColumn = byClause, returnType = returnType );
						return variables[ propertyName ];

					}else{
						// @TODO: add support for multiple By clauses (i.e. byInvoice_NumberAndCompanies_ID)
						// ONE-TO-MANY
						// If the by clause was not a property in the current entity, we'll try to load one-to-many
						// records from the given table based on the by clause.
						// variables[ propertyName ] = this[ propertyName ] = _getOneToMany( table = lcase( newTableName ), pkValue = this.getID(), fkColumn = byClause );
						// return variables[ propertyName ];
						//logIt('CALLING _getOneToMany() for #newTableName# using byClause #byClause# #right(arguments.missingMethodName, 8)#');
						var ret =  _getOneToMany( table = lcase( mapping.table ), property = propertyName, pkValue = this.getID(), fkColumn = byClause, returnType = returnType );
						return isObject( ret ) ? ret : variables[ propertyName ];
					}

				} catch ( any e ){
					if( e.type != 'BMO' ){
						// throw(e.detail);
						writeDump([e]);abort;
					}
				}
			}
			// return this;
		}else if( left( arguments.missingMethodName, 3 ) is "set" ){
			// Handle setters that may not have been assigned to dynamic properties
			var tableName = mid( arguments.missingMethodName, 4, len( arguments.missingMethodName ) );
			var mapping = _getMapping( tableName );
			_injectProperty( mapping.property, arguments.missingMethodArguments[ 1 ] );
			// this[ mapping.property ] = arguments.missingMethodArguments[ 1 ];
			// variables[ mapping.property ] = arguments.missingMethodArguments[ 1 ];
			this.set_isDirty( true );
			logIt('#arguments.missingMethodName# :: #isDirty()#');

			return this;

		}else if( left( arguments.missingMethodName, 7 ) is "hasMany" ){
			// Inject array of child objects
			var newTableName = mid( arguments.missingMethodName, 8, len( arguments.missingMethodName ) );
			//logIt('CALLING _getOneToMany() for #newTableName# using hasmany missing method handler');
			variables[ newTableName ] = this[ newTableName ] = _getOneToMany( table = lcase( newTableName ), returnType = returnType );

			return this;
		}else if( left( arguments.missingMethodName, 9 ) is "belongsTo" ){
			var newTableName = mid( arguments.missingMethodName, findNoCase( "belongsTo", arguments.missingMethodName ) - 1, len( arguments.missingMethodName ) );
			variables[ newTableName ] = this[ newTableName ] = _getManyToOne( table = lcase( newTableName ), fkColumn = newTableName & "_ID", returnType = returnType );

			return this;
		}else if( left( arguments.missingMethodName, 3 ) is "has" ){
			var propertyName =  mid( arguments.missingMethodName, 4, len( arguments.missingMethodName ) );
			return structKeyExists( variables, propertyName )
				&& ( ( isArray( variables[ propertyName ] ) && arrayLen( variables[ propertyName ] ) )
				|| ( isStruct( variables[ propertyName ] ) && structCount( variables[ propertyName ] ) ) );
		}else if( left( arguments.missingMethodName, 3 ) is "add" ){
			// Adder was called before relationship was wired up. Try to wire up the one-to-many relationship and add the item.
			var adderInstructions = mid( arguments.missingMethodName, 4, len( arguments.missingMethodName ) );
			var newTableName = var propertyName = adderInstructions;
			var mapping = _getMapping( adderInstructions );
			var propertyName = propertyName == mapping.table ? mapping.property : propertyName;

			variables[ newTableName ] = this[ newTableName ] = _getOneToMany( table = lcase( mapping.table ), property = propertyName, returnType = returnType );
			// try the call again.
			// writeDump(arguments.missingMethodArguments);abort;
			return evaluate("this.#arguments.missingMethodName#( arguments.missingMethodArguments[1] )");

		}

		// Allow "loadFirst" method to instantiate the entity and load it with the first
		// record returned per the "By" criteria
		if( left( arguments.missingMethodName, 9 ) is "loadFirst" ){
			limit = 1;
			abortlater = true;
			// arguments.missingMethodName = "load" & mid( arguments.missingMethodName, 10, len( arguments.missingMethodName ) );
			arguments.missingMethodName = reReplaceNoCase( arguments.missingMethodName, "loadFirst", "load", "one" );
		}

		if( left( arguments.missingMethodName, 6 ) is "loadBy"
			|| left( arguments.missingMethodName, 9 ) is "loadAllBy"
			|| left( arguments.missingMethodName, 8 ) is "lazyLoad"
			|| arguments.missingMethodName is "loadAll"
			|| arguments.missingMethodName is "loadTop"
			){

			var loadAll = ( left( originalMethodName, 7 ) is "loadAll"
						  	|| left( originalMethodName , 11 ) is "lazyLoadAll" );

			// Build where clause based on function name
			if( arguments.missingMethodName != "loadAll" && arguments.missingMethodName != "loadTop" ){
				queryArguments = listToArray( reReplaceNoCase( reReplaceNoCase( arguments.missingMethodName, 'loadBy|loadAllBy|lazyLoadAllBy|lazyLoadBy', '', 'all' ), 'And', '|', 'all' ), '|' );

				if( structKeyExists( arguments.missingMethodArguments, "orderBy" ) ){
					orderby = arguments.missingMethodArguments["orderBy"];
					structDelete( arguments.missingMethodArguments, "orderby" );
				}

				for ( i = 1; i LTE arrayLen( queryArguments ); i++ ){
					args[ queryArguments[ i ] ] = arguments.missingMethodArguments[ i ];

					// the entity cfc could have a different column name than the given property name.  If the meta property "column" exists, we'll use that instead.
					LOCAL.tmpCol = structFindValue( variables.meta, queryArguments[ i ], 'all' );
					LOCAL.columnName = arrayLen( tmpCol ) ? tmpCol[ 1 ] : {};
					if( !structKeyExists( LOCAL.columnName, 'owner' ) ){
						LOCAL.tmpCol = structFindValue( variables.meta, ListChangeDelims( queryArguments[ i ], '', '_', false ), 'all' );
						LOCAL.columnName = arrayLen( tmpCol ) ? tmpCol[ 1 ] : {};
					}

					LOCAL.columnName = structCount( LOCAL.columnName ) && structKeyExists( LOCAL.columnName.owner, 'column' ) ? LOCAL.columnName.owner.column : queryArguments[ i ];

					recordSQL &= " AND #LOCAL.columnName# = #getDao().queryParam(value="#arguments.missingMethodArguments[ i ]#")#";

					//Setup defaults
					// LOCAL.functionName = "set" & queryArguments[ i ];

					try{
						// LOCAL.tmpFunc = this[LOCAL.functionName];
						// LOCAL.tmpFunc(arguments.missingMethodArguments[ i ]);
						evaluate("this.set#queryArguments[ i ]#(arguments.missingMethodArguments[ i ])");
					} catch ( any err ){
						writeDump([ arguments,err, this ]);
						throw("Error Loading data into #this.getTable()# object.");
					}
				}

			}

			if( structCount( missingMethodArguments ) GT arrayLen( queryArguments ) ){
				where = missingMethodArguments[ arrayLen( queryArguments ) + 1 ];
				where = len( trim( where ) ) ? where : '1=1';
			}

			var columns = this.getDAO().getSafeColumnNames( this.getTableDef().getColumns() );
			// var columns = this.getDAO().getSafeColumnNames( this.getTableDef().getColumns( exclude = 'ID' ) );
			// columns = listPrepend( columns, this.getDAO().getSafeColumnName( getIDField() ) & (getIDField() != 'ID' ? ' as ID ' : '') );
			// columns = listPrepend( columns, this.getDAO().getSafeColumnName( getIDField() ) & (getIDField() != 'ID' ? ' as ID' : ''));

			record = variables.dao.read(
				table = this.getTable(),
				columns = columns,
				where = "WHERE #where# #recordSQL#",
				orderby = orderby,
				limit = limit,
				name = "model_load_by_handler"
			);
			// if( limit ){
			// 	writeDump([record,arguments,where, recordsql, getTable(), columns, originalMethodName]);abort;
			// }
			variables._isNew = record.recordCount EQ 0;

			//If a record existed, load it
			if( record.recordCount == 1 && !left( originalMethodName, 7 ) is "loadAll" && !left( originalMethodName, 11 ) is "lazyLoadAll"){
				return this.load( ID = record, lazy = left( originalMethodName , 4 ) is "lazy" );
			// If more than one record was returned, or method called was a "loadAll" type, return an array of data.
			}else if( record.recordCount > 1 || left( originalMethodName, 7 ) is "loadAll" || left( originalMethodName , 11 ) is "lazyLoadAll" ) {
				//logIt('lazy load all #this.getTable()# - [#originalMethodName# | #getParentTable()#]');
				var recordArray = [];
				var qn = queryNew( record.columnList );
				var recCount = record.recordCount;
				queryAddRow( qn, 1 );

				for ( var rec = 1; rec LTE recCount; rec++ ){
					// append each record to the array. Each record will be an instance of the model entity in represents.  If lazy loading
					// this will be an empty entity instance with "overloaded" getter methods that instantiate when needed.
					for( var col in listToArray( record.columnList ) ){
						querySetCell( qn, col, record[ col ][ rec ] );
					}
					var tmpLazy = left( originalMethodName , 4 ) is "lazy" || record.recordCount GTE 100 || this.getParentTable() != "";

					lock type="readonly" name="#this.getTable()#-#qn[ getIDField() ][ 1 ]#" timeout="1"{
						var cachedObject = cacheGet( '#this.getTable()#-#qn[ getIDField() ][ 1 ]#' );
					}
					//logIt('is object cached? #yesNoFormat(!isNull(cachedObject))#');
					if( !isNull( cachedObject ) ){
						// object cached, load from memory.
						var tmpNewEntity = cachedObject;
					}else{

						// Creating a new instance of the entity for each record.  Tried to use duplicate( this ), but that
						// does not appear to be thread safe and ends up causing concurrency issues.
						var tmpNewEntity = new(); //createObject("component", variables.meta.fullName ).init( dao = this.getDao() );
						tmpNewEntity.load( ID = qn , lazy = tmpLazy, parent = getParentTable() );

					}

					if( returnType is "struct" || returnType is "array" ){
						tmpNewEntity = tmpNewEntity.toStruct();
					}else if (returnType is "json"){
						tmpNewEntity = tmpNewEntity.toJSON();
					}

					arrayAppend( recordArray, tmpNewEntity );
				}
					// writeDump([tmplazy,this,variables.meta,arguments,getFunctionCalledName(),recordArray]);abort;
				if( returnType is "json" ){
					return "[" & arrayToList( recordArray ) & "]";
				}
				if( arraylen( recordArray ) == 1 ){
					recordArray = recordArray[ 1 ];
				}
				return recordArray;
			//Otherwise, set the passed in arguments and return the new entity
			}else{


				for ( i = 1; i LTE arrayLen(queryArguments); i++ ){
					//Setup defaults
					// LOCAL.functionName = "set" & queryArguments[ i ];
					 try{
						if( validateProperty( queryArguments[ i ], arguments.missingMethodArguments[ i ] ).valid ){
							evaluate("set#queryArguments[ i ]#(arguments.missingMethodArguments[ i ])");
						}
						// LOCAL.tmpFunc = this[ LOCAL.functionName ];
						// if( validateProperty( queryArguments[ i ], arguments.missingMethodArguments[ i ] ).valid ){
						// 	LOCAL.tmpFunc( arguments.missingMethodArguments[ i ] );
						// }
						this.set_isDirty( false );
					} catch ( any err ){
						// writeDump( err );
						// throw( message = "Setting the value for #queryArguments[ i ]# failed." );
						rethrow();
					}
				}

				return this;
			}
		}

		// throw error
		throw( message = "Missing method", type="variables", detail="The method named: #arguments.missingMethodName# did not exist in #getmetadata(this).path#.");

	}


	/**
	* Sets the current instance of the model object as a "new" record.  This will cause an insert instead
	* of an update when the save() method is called, retaining the original data, but generating a new record
	* with new primary key/generated ID values.  Use this when creating several records of the same entity
	* type to save on the instantiation costs. (i.e. reuse instance instead of doing 'entity = new BaseModelObject('....')')
	**/
	public function copy(){
		variables._isNew = true;
		variables[ getIDField() ] = '';
	}
	/**
	* Creates a new empty instance of the entity.  If properties are passed in the new instance will
	* be loaded with these properties.
	**/
	public function new( struct properties = {}, string table = getTable(), dao dao = getDao(), string IDField = getIDField() ){

		var newEntity = this;
		if( listLast( variables.meta.name , '.' ) == "BaseModelObject"){
			newEntity = createObject( "component", "BaseModelObject" ).init( dao = dao, table = table, dynamicMappings = getDynamicMappings(), cacheEntities = get__cacheEntities(), cachedWithin = getcachedWithin(), IDField = IDField, autoWire = getAutoWire() );
		}else{
			try{
				newEntity = createObject( "component", listDeleteAt( variables.meta.fullName, listLen( variables.meta.fullName, '.' ), '.' ) & '.' & table ).init( dao = dao );
			}catch( any e ){
				newEntity = createObject( "component", "BaseModelObject" ).init( dao = dao, table = table, dynamicMappings = getDynamicMappings(), cacheEntities = get__cacheEntities(), cachedWithin = getcachedWithin(), IDField = IDField, autoWire = getAutoWire() );
				// return createObject( "component", variables.meta.fullName ).init( dao = dao );
			}
		}
		// If properties are passed in (name/value pairs of entity fields), load it as a new object populated with the property data.
		if( structCount( properties ) ){
			// First delete the id field from the properties struct.  If the desire is to load record if it exists, use load() directly.
			structDelete( properties, getIDField() );
			// writeDump([serializeJSON(properties),arguments,newEntity.load( id = properties ), load( id = properties )]);abort;
			newEntity.load( id = properties );
		}
		return newEntity;
	}
	/**
	* Resets the current instance (empty all data). This way the object can be re-used without having to be completely re-instantiated.
	**/
	public function reset(){
		// Could just load(0), but properties dynamically added will persist in the variables scope
		// and the variables.properties is readonly.
		for ( var prop in variables.meta.properties ){
			this[ prop.name ] = variables[ prop.name ] = '';
		}
		return this;
	}

	/**
	* A conveniece method for loading an object with pre-existing data.
	* I take a struct that contains keys that match properties on the given
	* entity and return an instance of the entity with the passed in values
	* "loaded" into the entity.  If the properties argument contains a key
	* with the same name as the entity's "IDField" then I will attempt to
	* load the record from the database.  If no matching record is found, or
	* the properties did not contain the IDField I will return an instance
	* of the entity, loaded with the key/values specified by the properties arg.
	**/
	public any function populate( required any properties, boolean lazy = false ){
		// Note: The ID passed into load() can either be the PK field value of the record
		// you wish to load, or a struct containg the key/values you want to load.
		return load( ID = properties, lazy = lazy );
	}

	/**
	* A convenience method to force the lazy loading of the entity.  I make code
	* more self-documenting.
	**/
	public any function lazyLoad( required any ID ){
		return load( ID = ID, lazy = true );
	}

	/**
	* Loads data into the model object. If lazy == true the child objects will be lazily loaded.
	* Lazy loading allows us to inject "getter" methods that will instantiate the related data
	* only when requested.  This makes the loading much quicker and only instantiates child
	* objects when needed.
	*
	* The ID argument can be either the id value (ie the primary key value of the record) or a
	* struct containing the keys that relate to the entity's keys.  This could be used to fully
	* populate an instance of the entity, or to load an existing entity and override it's properties.
	* One use case would be to pass it the form scope where the form contained fields that directly
	* correspond (via name) to properties in the entity.  See convenience function 'populate()'
	*
	**/
	public any function load( required any ID, boolean lazy = false, string parentTable = getParentTable() ){
		var props = variables.meta.properties;

		// If the ID was a simple value, chances are we may have the object alreayd cached, let's try to load it.
		// Typically we'd only use a short lived cache to help resolve circular dependancies and loading the same
		// object multiple times in quick succession.  However, the cachedWithin property can be altered to extend
		// the chache's life as long as you'd like.  Note that the cached object is only updated when relationships
		// are added via hasMany or belongsTo, or the entity is persisted to the database (.save() is called )

		if( isSimpleValue( ID ) && len( trim( ID ) ) && get__cacheEntities() ){
			// Load from cache if we've got it
			// cacheremove( '#this.getTable()#-#ID#' );
			lock type="readonly" name="#this.getTable()#-#ID#" timeout="1"{
				var cachedObject = cacheGet( '#this.getTable()#-#ID#' );
			}
			// logIt('Loaded #this.getTable()#-#ID# from cache');
			// if cachedObject is null that means the object didn't exist in cache, so we'll just move on with loading
			if( !isNull( cachedObject ) && len( trim( cachedObject.getID() ) ) ){
				// If we made it this far, the object was found in cache.  Now, to "laod" the cache object's data into the
				// current object is going to take some trickery.
				// First, we'll set the "fromCache" flag so that later we can see this was loaded from cache.
				cachedObject.set__FromCache( true );

				// When an object is loaded from cache the variables.meta.properties doesn't
				// know about any relationships that were added after the object was originally loaded.
				// So though we'd normally iterate the variables.meta.properties array to flesh out the entity,
				// in this case we'll just iterate the cachedObject directly (NOTE: calling getMetaData() on the
				// cachedObject will just return the metadata of BaseModelObject, and not the instantiated object's
				// injected properties )

				for( var prop in cachedObject ){
					if(!isCustomFunction( cachedObject[prop] ) && prop != "METHODS" ){
						var mapping = _getMapping( prop );
						// var newProp = structKeyExists( getDynamicMappings(), prop ) ? getDynamicMappings()[ prop ] : prop;
						var cachedPropName = structKeyExists( cachedObject, mapping.property ) ? mapping.property : prop;

						this[ mapping.property ] = cachedObject[ cachedPropName ];
						variables[ mapping.property ] = cachedObject[ cachedPropName ];
						cachedObject[ mapping.property ] = cachedObject[ cachedPropName ];
						// logIt('Pumping #prop# into the object from cache...');
						var newProp = { 'table' = mapping.table, 'name' = mapping.property, 'column' = mapping.property, 'type' = isObject( cachedObject[ cachedPropName ] ) ? "object" : "string" };
						if( structKeyExists( mapping, 'cfc' ) ){
							newProp['cfc'] = mapping.cfc;
						}
						if( !structIsEmpty( newProp ) ){
							arrayAppend( variables.meta.properties, newProp );
						}
					}
				}

				// Now that we've loaded the data, we need to identify if it is a new record or not.
				variables._isNew = !len( trim( this.getID() ) );
				// HACK ALERT - Somehow, sometimes, the object pulled from cache is empty, even though we check for
				// an empty getID() before we even get here.... nutso, right?  All cache operations are locked, so
				// not really sure why this happens.  So when it does happen, we'll just bypass the cache and load
				// the object from scratch.  If this didn't happen, we'll return the cached object.
				if( len( trim( this.getID() ) ) ){
					return cachedObject;
				}
			}
		}


		// If we've made it this far, the object wasn't in cache so we'll need to load it manually.  Now, let's
		// set a flag to tell us later that this object was not pulled from cache.
		this.set__FromCache( false );

		if ( isStruct( arguments.ID ) || isArray( arguments.ID ) ){
			// If the ID field was part of the struct, load the record first. This allows updating vs inserting
			if ( structKeyExists( arguments.ID, getIDField() ) && arguments.ID[ getIDField() ] != -1 ){
				this.load( ID = arguments.ID[ getIDField() ] );
			}
			// Load the object based on the pased in struct. This may be a new record, or an update to an existing one.
			for ( var prop in props ){
				//Load the properties based on the passed in struct.
				if ( listFindNoCase( structKeyList( arguments.ID ), prop.name )/*  && prop.name != getIDField()  */){
					// We'll need to check some data types first though.
					if ( prop.type == 'date' && findNoCase( 'Z', arguments.ID[ prop.name ] ) ){
						variables[ prop.name ] = this[ prop.name ] = convertHttpDate( arguments.ID[ prop.name ] );
					}else{
						variables[ prop.name ] = this[ prop.name ] = arguments.ID[ prop.name ];
					}
					this.set_isDirty( true ); // <-- may not be, but we can't tell so better safe than sorry
				}
			}
			if ( structKeyExists( arguments.ID, getIDField() ) && !this.isNew() ){
				// If loading an existing entity, we can short-circuit the rest of this method since we've already loaded the entity
				// First let's put this guy in our cache for faster retrieval.
				lock type="exclusive" name="#this.getTable()#-#this.getID()#" timeout="1"{
					cachePut( '#this.getTable()#-#this.getID()#', this, getcachedWithin() );
				}
				return this;
			}

		}else{

			if ( isQuery( arguments.ID ) ){
				var record = arguments.ID;
			}else{
				var record = this.getRecord( ID = arguments.ID );
			}
			for ( var fld in listToArray( record.columnList ) ){
				// var setterFunc = this["set" & fld ];
				// setterFunc(record[ fld ][ 1 ]);
				// // or set directly - doesn't work in cf9
				// variables[ fld ] = record[ fld ][ 1 ];

				// Using evaluate is the only way in cfscript (cf9) to retain context when calling methods
				// on a nested object otherwise I'd use the above to set the fk col value
				try{
					if( validateProperty( fld, record[ fld ][ 1 ] ).valid  ){
						evaluate("set#fld#(record[ fld ][ 1 ])");
					}
					this[ fld ] = record[ fld ][ 1 ];
					variables[ fld ] = record[ fld ][ 1 ];

				}catch( any e ){
					// Setter failed, probably invalid type or something not caught by validateProperty.
					// bypass setter and move on already.
					this[ fld ] = record[ fld ][ 1 ];
					variables[ fld ] = record[ fld ][ 1 ];
				}
				this.set_isDirty( false );
			}
		}
		/*  Now iterate the properties and see if there are any relationships we can resolve */
		for ( var col in props ){
			var tmpChildObj = false;
			// Dynamically load one to many relationships by convention.  This will check to see if the current property
			// ends with _ID, and does not have a cfc associated with it. If both of those statements are true we'll try
			// to load the child table via BaseModelObject.
			if( ( !structKeyExists( col, 'cfc' )
				&& ( ( listLen( col.name, '_') GT 1
					&& listLast( col.name, '_' ) == 'ID' )
				|| structKeyExists( getDynamicMappings(), col.name )
				|| ( structKeyExists( col, 'column' )
					&& structKeyExists( getDynamicMappings(), col.column ) ) ) )
				&& getAutoWire() ){
				// We have a field ending with _ID, which typically indicates a "foriegn key" property to a tabled named whatever prefixes the _ID
				// Using this convention, if the parent table is "orders" and the field name is "orders_ID" we can load the parent
				try{
					// Resolve any dynamic mappings
					var mapping = _getMapping( col.name );
					// set the table to the mapped table, or the column name
					var table = var property = structKeyExists( getDynamicMappings(), col.name ) ? mapping.table : listDeleteAt( col.name, listLen( col.name, '_' ), '_' );
					// If this is a field that ends with _ID, and col.name didn't
					// exist we will fall back on the col.column property.
					if( listLast( col.name, '_' ) != 'ID'
						&& !structKeyExists( getDynamicMappings(), col.name )
						&& structKeyExists( col, 'column' )
						&& structKeyExists( getDynamicMappings(), col.column ) ){
						// Resolve any dynamic mappings for col.column
						mapping = _getMapping( col.column );
						table = mapping.table;
						property = mapping.property;
						// table = structKeyExists( getDynamicMappings(), col.column ) ? mapping.table : table;
						// logIt( "Does col.column: #col.column# have a dynamicMappings? #structKeyExists( getDynamicMappings(), col.column )#");
					}

					if( parentTable != table && structKeyExists( mapping, 'IDField' ) ){
						// If the above mapping attempts returned a map without an IDField that means we couldn't find a parent entity to tie to so we'll skip this.
						logIt('[#parentTable#] [#table#] :#col.name#: dynamic #structKeyExists(col, "dynamic") ? col.dynamic : 'false'# -- #getFunctionCalledName()#');
						// wire up the relationship
						tmpChildObj = _getManyToOne( table = lcase( table ), property = property, fkColumn = structKeyExists( col, 'column' ) ? col.column : col.name, pkColumn = mapping.IDField );
						// If a table matches the table, a relationship was found and tmpChildObj would be an object, otherwise it would have returned
						// false.  We only need to inject it if it was an object.
						if( isObject( tmpChildObj ) ){
							variables[ table ] = this[ table ] = tmpChildObj;
							variables[ property ] = this[ property ] = tmpChildObj;
						}
					}
				} catch ( any e ){

					if( e.type != 'BMO' ){
						// throw(e.detail);
						writeDump([e]);abort;
					}
				}
			}

			// Load all child objects
			if( structKeyExists( col, 'cfc' ) ){
				var tmp = createObject( "component", col.cfc ).init( dao = this.getDao(), dropcreate = this.getDropCreate(), dynamicMappings = getDynamicMappings() );
				// Skip if setter doesn't exist (happens on dynamic child properties)
				if( !structKeyExists( this, "set" & col.name ) ){
					if( structKeyExists( this, "add" & col.name ) ){
						var setterFunc = this["add" & col.name ];
					}else{
						continue;
					}
				}else{
					var setterFunc = this["set" & col.name ];
				}

				var childWhere = structKeyExists( col, 'where' ) ? col.where : '1=1';

				if( structKeyExists( col, 'fieldType' )
					&& col.fieldType == 'one-to-many'
					&& structKeyExists( col, 'cfc' )
					&& structKeyExists( col, 'inverseJoinColumn' ) ){
					// load child records here....
					col.fkcolumn = structKeyExists( col, 'fkcolumn' ) ? col.fkcolumn : col.name & this.getIDField();

					// If lazy == false we will aggressively load all child entities (this is expensive, so use sparingly)
					if( !lazy ){
						// Using evaluate because the onMissingMethod doesn't exist when using the dynamic function method (i.e.: func = this['getsomething']; func())
						setterFunc( evaluate("tmp.loadAllBy#col.fkcolumn#( this.get#col.inverseJoinColumn#(), childWhere )") );

					//If lazy == true, we will just overload the "getter" method with an anonymous method that will instantiate the child entity when called.
					}else{

						setterFunc( evaluate("tmp.lazyLoadAllBy#col.fkcolumn#( this.get#col.inverseJoinColumn#(), childWhere )") );
						/****** ACF9 Dies when the below code exists ******
						// // First, set the property (child column in parent entity) to an array with a single index containing the empty child entity (to be loaded later)
						// this[col.name] = ( structKeyExists( col, 'type' ) && col.type is 'array' ) ? [ duplicate( tmp ) ] : duplicate( tmp );
						// // Add a helper property to the parent object.  This will store the data necessary for the "getter" function to instantiate
						// // the object when called.
						// this["____lazy#hash(lcase(col.name))#"] = {
						// 		"id" : this.getID(),
						// 		"loadFuncName" : "LoadAllBy#col.fkcolumn#",
						// 		"childWhere" : childWhere
						// 	};
						// // Now, override the getter for the property.  Instead of returning the value of the property, it will load the child data and return that.
						// this["get" & col.name] = function( boolean lazy = true ) {
						// 	// The function name will help us to reference the "helper" struct attached to the parent instance earlier
						// 	var name = GetFunctionCalledName();
						// 		name = mid( name, 4, len( name ) );
						// 	var args = this["____lazy#hash(lcase(name))#"];
						// 	var tmp = this[name][ 1 ];

						// 	// Now load the child object into the entity property
						// 	this[name] = evaluate('tmp.#(lazy)?'lazy':''##args['loadFuncName']#( args.id, args.childWhere )');
						// 	// So that the getter doesn't re-load the child entity each time it is called, we'll just replace the
						// 	// getter funcction with a more sensible "return value" function. Much faster this way.
						// 	this[GetFunctionCalledName()] = function(){ return this[name];};
						// 	return this[name];
						// };

					}

				}else if( structKeyExists( col, 'fieldType' ) && col.fieldType eq 'one-to-one' && structKeyExists( col, 'cfc' ) ){
					if( !lazy ){
						//logIt('aggressively loading one-to-one object: #col.cfc# [#col.name#]');
						var tmpID = len( trim( evaluate("this.get#col.fkcolumn#()") ) ) ? variables[ col.fkcolumn ] : '0';
						setterFunc( tmp.load( tmpID ) );

					}else{

						setterFunc( evaluate("tmp.load( this.get#col.fkcolumn#() )") );
						// /****** ACF9 Dies when the below code exists *******/
						// // First, set the property (child column in parent entity) as the empty child entity (to be loaded later)
						// this[col.name] = duplicate( tmp );
						// // Add a helper property to the parent object.  This will store the data necessary for the "getter" function to instantiate
						// // the object when called.
						// this["____lazy#hash(lcase(col.name))#"] = {
						// 		"id" : variables[col.fkcolumn],
						// 		"loadFuncName" : "Load",
						// 		"childWhere" : childWhere
						// 	};
						// // Now, override the getter for the property.  Instead of returning the value of the property, it will load the child data and return that.
						// this["get" & col.name] = function( boolean lazy = true ) {
						// 	// The function name will help us to reference the "helper" struct attached to the parent instance earlier
						// 	var name = GetFunctionCalledName();
						// 		name = mid( name, 4, len( name ) );
						// 	var args = this["____lazy#hash(lcase(name))#"];
						// 	var tmp = this[name];

						// 	// Now load the child object into the entity property
						// 	// since we are calling a static method, we don't need to use evaluate as we do in the one-to-many routine
						// 	this[name] = tmp.load( args.id, lazy );
						// 	// So that the getter doesn't re-load the child entity each time it is called, we'll just replace the
						// 	// getter funcction with a more sensible "return value" function. Much faster this way.
						// 	this[GetFunctionCalledName()] = function(){ return this[name];};
						// 	return this[name];
						// };


					}
				}
			}
		}

		if( isSimpleValue( ID ) && !this.isNew() ){
			// Now cache this thing.  The next time we need to call it (within the cachedwithin timespan) we can just pull it from memory.
			lock type="exclusive" name="#this.getTable()#-#this.getID()#" timeout="1"{
				cachePut( '#this.getTable()#-#this.getID()#', this, getcachedWithin() );
			}
		}
		return this;

	}
	/**
	* Returns the value of the Primary Key (whatever is set as IDField)
	**/
	public any function getID(){
		if( structKeyExists( variables, getIDField() ) ){
			return variables[ getIDField() ];
		}else{
			return "";
		}
	}

	/************************************************************************
	* DYNAMIC ENTITY RELATIONSHIPS
	************************************************************************/
	/**
	* I return an array of any child entities related to (and loaded into) the current entity.
	**/
	public array function getChildEntities(){
		return variables._children;
	}

	public function registerChildEntity( struct definition ){
		arrayAppend( variables._children, definition );
	}
	/**
	* Loads One-To-Many relationships into the current entity
	* Example: On an Order entity you have multiple OrderItems
	**/
	private any function _getOneToMany( required string table, any pkValue = getID(), string property = arguments.table, string fkColumn = getTable() & "_ID", string returnType = "object", string where = "", boolean returnFirst = false ){

		var mapping = _getMapping( table );
		var propertyName = property == table ? mapping.property : property;
		try{
			// try to load the table into a new object.  If the table doesn't
			// exist we'll just return void;
			var newObj = new( table = mapping.table, dao = this.getDao() );
		}catch( any e ){
			throw( message = "Table #propertyName# does not exist", type="BMO", detail="Table #propertyName# does not exist in #getDao().getDSN()#");
			// writeDump([arguments,e,this]);abort;
			// return variables[ propertyName ];
		}
		if( !isObject( newObj ) ){
			throw( message = "Table #propertyName# does not exist", type="BMO", detail="Table #propertyName# does not exist in #getDao().getDSN()#");
			// writeDump([mapping, variables[ propertyName ], arguments,newObj,this]);abort;
			// return variables[ propertyName ];
			// return false;
		}
		newObj.setTable( mapping.table );
		newObj.setParentTable( getTable() );

		// Append the relationship propertyName to the meta properties
		arrayAppend( variables.meta.properties, {
						"column" = propertyName,
						"name" = propertyName,
						"dynamic" = true,
						"cfc" = "BaseModelObject",
						"table" = table,
						"fkcolumn" = fkColumn,
						"fieldType" = "one-to-many"
					} );
		// logIt('adding adders/getters/setters for #propertyName#');
		this[ "add" & propertyName ] = variables[ "add" & propertyName ] = _adder;
		this[ "set" & propertyName ] = variables[ "set" & propertyName ] = _setter;
		this[ "remove" & propertyName ] = variables[ "remove" & propertyName ] = _remover;
		this[ "get" & propertyName ] = variables[ "get" & propertyName ] = _getter;
		this[ "has" & propertyName ] = _has;

		this.registerChildEntity( { name = propertyName, table = lcase( mapping.table ), type = "one-to-many", childIDField = fkColumn, parentIDField = getIDField() } );

		// Update Cache
		lock type="exclusive" name="#this.getTable()#-#this.getID()#" timeout="1"{
			cachePut( '#this.getTable()#-#this.getID()#', this, getcachedWithin() );
		}

		// logIt('Loading dynamic one-to-many relationship entity #table# with #fkcolumn# of #pkValue# - parent #this.getTable()# [#newObj.getParentTable()#]');
		if( table == getTable() || returnType == "array" || returnType == "struct" || returnType == "json" ){
			this[ propertyName ] = variables[ propertyName ] = evaluate("newObj.lazyLoadAllBy#fkColumn#As#returnType#(#pkValue#,'#where#')");
			return this[ propertyName ];

		}else{
			// Return an array of child objects.
			if( !val( pkValue ) ){
				// No pkValue, which probably means this is a new record not yet persisted.  Return an empty array
				this[ propertyName ] = variables[ propertyName ] = [];
				return [];
			}
			logIt("newobject table: #newObj.getTable()#");
			logIt('newObj.lazyLoadAllBy#fkColumn#(#pkValue#,''#where#'')');
			this[ propertyName ] = variables[ propertyName ] = evaluate("newObj.lazyLoadAllBy#fkColumn#(#pkValue#,'#where#')");
			if( isArray( this[ propertyName ] ) ){
				if( returnFirst ){
					return this[ propertyName ][ 1 ];
				}else{
					return this[ propertyName ];
				}
			}
			return [ this[ propertyName ] ];

		}
	}

	/**
	* Tells BMO about one-to-many relationships.  This is needed if the column names don't follow convention (and are not mapped via dynamicMappings)
	* Example: order = new BaseModelObject( table = "orders", dao = dao );
	* 		   order.load(123);
	* 		   order.hasMany( table = "order_items", fkColumn = "orders_ID", property = "OrderItem" );
	* 		^^ Assumes table order_items has a column named orders_ID, which points to the PK column in orders.
	**/
	public any function hasMany( required string table, string fkColumn = getIDField(), string property = arguments.table, string returnType = "object", string where = "" ){

		variables[ property ] = this[ property ] = _getOneToMany( table = lcase( table ), property = property, pkValue = getID(), fkColumn = fkColumn, returnType = returnType, where = where );

		// Update Cache
		lock type="exclusive" name="#this.getTable()#-#this.getID()#" timeout="1"{
			cachePut( '#this.getTable()#-#this.getID()#', this, getcachedWithin() );
		}
		return this;
	}

	/**
	* Loads Many-To-One relationships into the current entity
	* Example: Many OrderItems entities belong to the same Order
	**/
	private any function _getManyToOne( required string table, required string fkColumn, string pkColumn = getIDField(), string property = arguments.table, string returnType = "object", string where = "" ){
		if( !structKeyExists( variables, fkColumn) ){
			throw( message = "Unknown Foreign Key Property", type="BMO", detail="The Foreign Key: #fkColumn# did not exist in #table#.");
		}
		var fkValue = variables[ fkColumn ];
		var mapping = _getMapping( arguments.table );
		var propertyName = arguments.property;

		// Reverse lookup for an alias name in the dynamicMappings.  This is used in case the load() method
		// is auto-wiring relationships and doesn't know that a column has a mapping.
		if( propertyName == arguments.table && arrayLen( structFindValue( getDynamicMappings(), mapping.table ) ) ){
			if( structFindValue( getDynamicMappings(), mapping.table )[1].key != "table" ){
				propertyName = structFindValue( getDynamicMappings(), mapping.table )[1].key;
			}
		}

		this[ "set" & propertyName ] = variables[ "set" & propertyName ] = _setter;
		this[ "get" & propertyName ] = variables[ "get" & propertyName ] = _getter;

		this.registerChildEntity( { name = propertyName, table = lcase( mapping.table ), type = "many-to-one", parentIDField = arguments.fkColumn, childIDField = pkColumn } );

		if( !isSimpleValue(fkValue) ){
			// logIt('Value for #table# : #mapping.table# [#property#] was alread an object');
			var newObj = fkValue;
			fkValue = newObj.getID();
		}else{
			var newObj = new( table = mapping.table, dao = this.getDao(), idField = mapping.idField );
		}

		if( !isObject( newObj ) ){
			return newObj;
		}
		newObj.setTable( mapping.table );
		// Load data into new object
		// logIt('Loading dynamic many-to-one relationship entity #table#[#mapping.table#] [from #getFunctionCalledName()#] with id (#fkColumn#) of #isSimpleValue( variables[fkColumn] ) ? variables[fkColumn] : 'complex object'#. Lazy? #yesNoFormat(getParentTable() eq mapping.table)#');
		if( len( trim( fkValue ) ) ){
			newObj.load( ID = fkValue, lazy = getParentTable() == mapping.table, where = where );
		}

		// logIt('Well, was there anything to load?: #yesNoFormat( !newObj.isNew() )#');
		// Now set the relationhsip property value to the newly created and instantiated object.
		variables[ propertyName ] = this[ propertyName ] = variables.properties[ propertyName ] = newObj;

		// Append the relationship propertyName to the meta properties
		arrayAppend( variables.meta.properties, {
							"column" = propertyName,
							"name" = propertyName,
							"dynamic" = true,
							"cfc" = "BaseModelObject",
							"table" = mapping.table,
							"inverseJoinColumn" = newObj.getIDField(),
							"fkcolumn" = fkColumn,
							"fieldType" = "many-to-one"
						} );

		// Update Cache
		lock type="exclusive" name="#this.getTable()#-#this.getID()#" timeout="1"{
			cachePut( '#newObj.getTable()#-#newObj.getID()#', newObj, getcachedWithin() );
			cachePut( '#this.getTable()#-#this.getID()#', this, getcachedWithin() );
		}
		if( returnType is "struct" || returnType is "array" ){
			return newObj.toStruct();
		}else if( returnType is "json" ){
			return newObj.toJSON();
		}

		return newObj;
	}

	public any function belongsTo( required string table, string fkColumn = arguments.table & "_ID", string property = arguments.table, string pkColumn = getIDField(), string returnType = "object", string where = "" ){
		variables[ property ] = this[ property ] = _getManyToOne( table = lcase( arguments.table ), fkColumn = arguments.fkColumn, property = arguments.property, pkColumn = arguments.pkColumn, returnType = arguments.returnType, where = arguments.where );
		this[ "set" & property ] = variables[ "set" & property ] = _setter;
		// Update Cache
		lock type="exclusive" name="#this.getTable()#-#this.getID()#" timeout="1"{
			cachePut( '#this.getTable()#-#this.getID()#', this, getcachedWithin() );
		}
		return this;
	}

	/**
	* I return the field/relationship mapping for a given table or property
	* NOTE: getIDField() will get the current entity ID field, not
	* the ID field of whatever arguments.table is.
	* The mapping struct consists of the following keys:
	* 	table : The name of the table the mapping applies to. OR property that will be used to reverse lookup a table.
	* 	property: (defaults to table) - The name or alias to use in cfml code.
	* 			  This will create the property with the given name, so if the table is named
	* 			  Users, but you want to refer to it as User, set the property to User.
	* 	key: The foriegn key used when loading this table in a manytoone relationship
	*   IDField: They "primary key" field name of the "table".  This will be used when loading
	* 			 the entity data and/or mapping relationships
	* 	tableDef: An instance of the tabledef initialized for the given table.
	**/
	private any function _getMapping( required string table ){

		var mapping = { "table" = table, "property" = table, key = table };
		logIt('looking for mapping for #table#');
		if( structKeyExists( this.getDynamicMappings(), table ) ){
			logIt('mapping for #table# exists.');
			mapping = this.getDynamicMappings()[ table ];
			if( !isStruct( mapping ) ){
				logIt('mapping for #table# exists but is not a struct, creating new one now');
				// mapping was not found or was not initialized
				var tableDef = new tabledef( tableName = table, dsn = getDao().getDsn() );
				mapping = { "table" = mapping, "property" = mapping, "key" = mapping, "IDField" = tableDef.getPrimaryKeyColumn(), "tableDef" = tableDef };
			}else{
				// mapping was found, but no key found. Update with table data
				if( !structKeyExists( mapping, "key" ) ){
					logIt('mapping for #table# exists and is a struct, but didn''t have a key');
					mapping["table"] = table;
					mapping["key"] = table;
					// mapping["IDField"] = mapping["tableDef"].getPrimaryKeyColumn();
				}
			}
		}else{
			logIt('mapping for #table# did not exist');
			// table was not found in the current mappings.
		  	// Let's see if the passed in table is a real table and if so create a generic mapping and return it.
			var tableDef = new tabledef( tableName = table, dsn = getDao().getDsn() );
			logIt('is #table# a table? #tableDef.getIsTable()#');
			if( tableDef.getIsTable() ){
				// passed in table was actually a table, now map it.
				mapping = { "table" = table, "property" = table, "key" = tableDef.getPrimaryKeyColumn(), "IDField" = tableDef.getPrimaryKeyColumn(), "tableDef" = tableDef };
				logIt('added generic mapping for table #table#');
			}else{
				// Not a table, so we'll see if the "table" argument matches any keys in the dynamic mappings. This is used to find a mapping for a foriegn key to a given table.
				logIt('iterating each in #serializeJSON( getDynamicMappings())#');
				// iterate mappings and look-up properties to find the key
				for( var map in getDynamicMappings() ){

					logIt("mappings for #table#: " & serializeJSON( getDynamicMappings()[ map ] ));
					if( isStruct( getDynamicMappings()[ map ] )
						&& structKeyExists( getDynamicMappings()[ map ], 'property' )
						&& getDynamicMappings()[ map ].property == table ){
						logIt('table that was passed in was found as a property in a dynamic mapping.  Using that to create new mapping');
						return { "table" = getDynamicMappings()[ map ].table, "property" = getDynamicMappings()[ map ].property, "key" = map, "IDField" = tableDef.getPrimaryKeyColumn(), "tableDef" = tableDef };

					}
				}
			}
		}

		return mapping;
		// return isStruct( mapping ) ? mapping.table : mapping;
	}

	/************************************************************************
	* END: DYNAMIC ENTITY RELATIONSHIPS
	************************************************************************/


	public query function getRecord( any ID ){
		var LOCAL = {};
		LOCAL.ID = structKeyExists( arguments, 'ID' ) ? arguments.ID : this.getID();

		try{
			logIt("columns in #this.getTable()#: " & this.getDAO().getSafeColumnNames( this.getTableDef().getColumns() ) );
			var record = this.getDAO().read(
					table = this.getTable(),
					// columns = "#this.getIDField()##this.getIDField() neq 'ID' ? ' as ID, #this.getIDField()#' : ''#, #this.getDAO().getSafeColumnNames( this.getTableDef().getColumns( exclude = 'ID,#this.getIDField()#' ) )#",
					columns = this.getDAO().getSafeColumnNames( this.getTableDef().getColumns() ),
					where = "WHERE #this.getIDField()# = #this.getDAO().queryParam( value = val( LOCAL.ID ), cfsqltype = this.getIDFieldType() )#",
					name = "#this.getTable()#_getRecord"
				);
		}catch( any e ){
			writeDump( [this, e ]);abort;
		}

		variables._isNew = record.recordCount EQ 0;
		return record;
	}

	/**
	* I return a query object containing a single record from the database.  If ID
	* is specified I will return the record matching that ID.  If not, I will return
	* the record of the currently instantiated entity.
	**/
    public query function get( any ID ){
        return getRecord( ID );
    }

    /**
    * The 'where' argument should be the entire SQL where clause, i.e.: "where a=queryParam(b) and b = queryParam(c)"
    **/
	/* string columns = "#this.getDAO().getSafeColumnName( this.getIDField() )##this.getIDField() NEQ 'ID' ? ' as ID,  #this.getIDField()#' : ''#, #this.getDAO().getSafeColumnNames( this.getTableDef().getColumns( exclude = 'ID,#this.getIDField()#' ) )#", */
	public query function list(
		string columns = this.getDAO().getSafeColumnNames( this.getTableDef().getColumns() ),
		string where = "",
		string limit = "",
		string orderby = "",
		string offset = "",
		array excludeKeys = []){

		var cols = replaceList( lcase( arguments.columns ), lcase( arrayToList( arguments.excludeKeys ) ) , "" );
		cols = reReplace( cols, "#this.getDao().getSafeIdentifierStartChar()##this.getDao().getSafeIdentifierEndChar()#|\s", "", "all" );
		cols = arrayToList( listToArray( cols, ',', false ) );

		var record = variables.dao.read(
				table = this.getTable(),
				columns = cols,
				where = where,
				orderby = orderby,
				limit = limit,
				offset = offset
			);
		return record;
	}

	/**
	* I return a JSON array of structs representing the records matching the specified criteria; one record per array indicie.
	**/
    public string function listAsJSON(string where = "", string limit = "", string orderby = "", numeric row = 0, string offset = "", array excludeKeys = [] ){
        return serializeJSON( listAsArray( where = arguments.where, limit = arguments.limit, orderby = arguments.orderby, row = arguments.row, offset = arguments.offset, excludeKeys = arguments.excludeKeys ) );
    }
    /**
    * Returns a CF array of structs representing the records matching the specified criteria; one record per array indicie.
    **/
    public array function listAsArray(string where = "", string limit = "", string orderby = "", numeric row = 0, string offset = "", array excludeKeys = [] ){
        var LOCAL = {};
        var query = list( where = arguments.where, limit = arguments.limit, orderby = arguments.orderby, row = arguments.row, offset = arguments.offset, excludeKeys = arguments.excludeKeys );

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

        // At this point, we have an array of structure objects tha
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
    * I return a struct representation of the object in its current state.
    **/
	public struct function toStruct( array excludeKeys = [], numeric top = 0, boolean preserveCase = true, numeric nestLevel = 1 ){

			var arg = "";
			var LOCAL = {};
			var returnStruct = {};
			var keysToExclude = "dynamicMappings,__fromCache,__cacheEntities,parenttable,autowire,cachedwithin,_norm_version,_norm_updated,meta,prop,arg,arguments,tmpfunc,this,dao,idfield,idfieldtype,idfieldgenerator,table,tabledef,deleteStatusCode,dropcreate,dynamicMappings#ArrayToList(excludeKeys)#";
			var props = duplicate( variables.meta.properties );

			// Iterate through each property and generate a struct representation
			// writeDump(props);abort;
			for ( var prop in props ){
				// Somehow empty props make their way in with MSSQL connectors... this will weed'm out.
				if( structIsEmpty( prop ) ){
					continue;
				}
				arg = preserveCase ? prop.name : lcase( arg );

				// If the property name is different than the table name ( i.e. relationship created using get<object>() method or
				// relationship identified in the dynamicMappings ), chances are we hve the meta property
				// twice - once with the table name and once with the alias.  This will remove the table name
				// property so that the alias name will be used instead
				if( structKeyExists( prop, 'table' ) && structKeyExists( returnStruct, prop.table ) ){
					structDelete( returnStruct, prop.table );
				// }else if( structKeyExists( returnStruct, prop.name ) ){
				// 	structDelete( returnStruct, prop.name );
				// 	// continue;
				}
				LOCAL.functionName = "get" & arg;
				try
				{
					// We will bypass internal properties, as well as any "excludeKeys" we find.
					if( !findNoCase( '$$_', arg )
						&& ( !structKeyExists( this, arg ) || !isCustomFunction( this[ arg ] ) )
						&& !listFindNoCase( keysToExclude, arg ) ){

						// Now, append the property to the struct we will be returning
						if( structKeyExists( variables, arg ) ){
							returnStruct[ arg ] = variables[ arg ];
						}

						// Checking to see if the property was appended to the struct. This prevents errors that sometimes occur if the variables[ arg ] is null (i.e. returned null from Java call )
						if( structKeyExists( returnStruct, arg ) ){
							// If it's not a simple value, we'll need to recursively call toStruct() to resolve all the nested structs.
							if( !isSimpleValue( returnStruct[ arg ] )){
								if(  top == 0 || nestLevel < arguments.top ){
									if( isArray( returnStruct[ arg ] ) ){
										for( var i = 1; i LTE arrayLen( returnStruct[ arg ] ); i++ ){
											if( isObject( returnStruct[ arg ][ i ] ) ){
												// returnStruct['__level'] = nestLevel;
												returnStruct[ arg ][ i ] = returnStruct[ arg ][ i ].toStruct( excludeKeys = excludeKeys, preserveCase = preserveCase, nestLevel = nestLevel+1 );
											}
										}
									}else if( isObject( returnStruct[ arg ] ) ){
										// returnStruct['__level'] = nestLevel;
										returnStruct[ arg ] = returnStruct[ arg ].toStruct( excludeKeys = excludeKeys, preserveCase = preserveCase, nestLevel = nestLevel+1 );
									}
								}else{
									returnStruct[ arg ] = isArray( returnStruct[ arg ] ) ? '[ additional array of entities excluded due to "top=#arguments.top#" nesting limit ]' : '[ additional entity properties excluded due to "top=#arguments.top#" nesting limit ]';
								}
							}else if( isNumeric( returnStruct[ arg ] )
									&& listLast( returnStruct[ arg ], '.' ) GT 0 ){
								// Since CF likes to convert our numbers to strings, let's javacast it as an int
								try{
									if( findNoCase( '.', returnStruct[ arg ] ) ){
										returnStruct[ arg ] = javaCast( 'double', returnStruct[ arg ] );
									}else{
										returnStruct[ arg ] = javaCast( 'int', returnStruct[ arg ] );
									}
								}catch( any e ){
									returnStruct[ arg ] = returnStruct[ arg ];
								}
							}else{
								returnStruct[ arg ] = returnStruct[ arg ];
							}
						}
					}
				}
				catch (any e){
					throw(message='Error in toStruct method: #e.message#', detail=e.detail);
				}
			}
		return returnStruct;
	}

	/**
    * I return a JSON representation of the object in its current state.
    **/
	public string function toJSON( array excludeKeys = [], numeric top = 0, boolean preserveCase = true ){

		return serializeJSON( this.toStruct( excludeKeys = excludeKeys, top = top, preserveCase = preserveCase ) );;
	}

	/**
    * I save the current state to the database. I either insert or update based on the isNew flag
    **/
	public any function save( struct overrides = {}, boolean force = false, any callback ){

		var tempID = this.getID();
		var callbackArgs = { ID = this.getID(), method = 'save' };
		// writeDUmp(['is new?', this.isNew(), 'is dirty?', this.isDirty()]);
		// remove object from cache (if it exists)
		// Removing #this.getTable()#-#this.getID()# from cache
		lock type="exclusive" name="#this.getTable()#-#this.getID()#" timeout="1"{
			cacheRemove( '#this.getTable()#-#this.getID()#' );
		}

		// Either insert or update the record
		if ( isNew() ){

			callbackArgs.isNew = true;
			var col = {};
			var props = deSerializeJSON( serializeJSON( variables.meta.properties ) );
			/* Merges properties and extends.properties into a CF array */
			if( structKeyExists( variables.meta, 'extends' ) && structKeyExists( variables.meta.extends, 'properties' )){
				props.addAll( deSerializeJSON( serializeJSON( variables.meta.extends.properties ) ) );
			}

			for ( col in props ){

				// set uuid for fields set to generator="uuid"
				if( structKeyExists( col, 'generator' ) && col.generator eq 'uuid' ){
					variables[ col.name ] = lcase( createUUID() );
					this.set_isDirty( true );
				}
				if( structKeyExists( col, 'formula' ) && len( trim( col.formula ) ) ){
					variables[ col.name ] = evaluate( col.formula );
				}

			}
			// On an insert we save the child records in two passes.
			// the first pass (this one) will save one-to-many related data.
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
				// we can only send simple values to be saved.  If the value is a struct/array that means it was a relationship entity and
				// should already have been taken care of in the _saveTheChildren() method above.
				DATA[ LOCAL.columnName ] = isSimpleValue( DATA[col] ) ? DATA[col] : '';
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
			transaction{
				var newID = variables.dao.insert(
					table = this.getTable(),
					data = DATA
				);
			}

			callbackArgs.newID = variables['ID'] = this['ID'] = newID;
            tempID = newID;

            // This is the second pass of the child save routine.
            // This pass will pick up those one-to-many relationships and
            // persist the data with the new parent ID (this parent)
			_saveTheChildren( tempID );


		}else if( isDirty() || arguments.force ){

			callbackArgs.isNew = false;

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

			callbackArgs.ID = DATA[getIDField()] = this.getID();

			if (structCount(arguments.overrides) > 0){
				for ( var override in overrides ){
					DATA[override] = overrides[override];
				}
			}

			/*** update the thing ****/
			transaction{
				variables.dao.update(
					table = this.getTable(),
					data = DATA
				);
			}
		}else{
			logIt('_savethechildren: nothing to do for this entity, but maybe a child entity needs to be saved?');
			_saveTheChildren();
		}

		variables._isNew = false;

		this.load(ID = tempID);

		// Fire callback function (if provided). Could be used for AOP
		if( structKeyExists( arguments, 'callback' ) && isCustomFunction( arguments.callback ) ){
			callback( this, callbackArgs );
		}

		// Cache saved object
		lock type="exclusive" name="#this.getTable()#-#this.getID()#" timeout="1"{
			cachePut( '#this.getTable()#-#this.getID()#', this, getcachedWithin() );
		}

		return this;
	}

	private void function _saveTheChildren( any tempID = this.getID() ){
	 /* Now save any child records */
	 logIt('_savethechildren: saving the children for #this.getTable()#:#arguments.tempID#');
		for ( var col in variables.meta.properties ){
	 		logIt('_savethechildren: is #col.name# a fk to a relationship?');
	 		logIt('_savethechildren: #serializeJSON(col)#');

			if( structKeyExists( col, 'fieldType' )
				&& col.fieldType eq 'one-to-many'
				&& ( structKeyExists( arguments, 'tempID' ) && len( trim( arguments.tempID ) ) )
				&& ( !structKeyExists( col, 'cascade') || col.cascade != "none" ) ){
				//**************************************************************************************************
				// ONE TO MANY.   This will iterate all child records and persist them to the back end storage (DB)
				//**************************************************************************************************
				logIt('_savethechildren: Saving #arrayLen( variables[ col.name ] )# child records for #this.getTable()#:#tempID#');
				if ( !structKeyExists( variables , col.name ) || !isArray( variables[ col.name ] ) ){
					logIt('_savethechildren: nothing to do for #col.name# - #this.getTable()#:#tempID#');
					continue;
				}
				for ( var child in variables[ col.name ] ){
					try{
						// evaluate retains the scope where anonymous methods don't
						evaluate("child.set#col.fkcolumn#( #tempID# )");
					}catch (any e){
						writeDump(['Error in setFunc',e,child, arguments, variables[ col.name ] ]);abort;

					}
					logIt('_savethechildren: Saving child [#child.getTable()#] record for #this.getTable()#:#tempID#');
					// call the child's save routine;
					child.save( force = true );

				}

			}else if( structKeyExists( col, 'fieldType' )
				&& col.fieldType eq 'many-to-one'
				&& ( structKeyExists( arguments, 'tempID' ) && len( trim( arguments.tempID ) ) )
				&& ( !structKeyExists( col, 'cascade') || col.cascade != "none" ) ){
				//**************************************************************************************************
				// MANY TO ONE.   This will and persist the child record to the back end storage (DB)
				//**************************************************************************************************
				var child = variables[ col.name ];
				child.save();

			}else if( structKeyExists( col, 'fieldType' ) && col.fieldType eq 'one-to-one' ){
				//**************************************************************************************************
				// ONE TO ONE.   This will update the parent with the child's ID and defer to the parent's save to
				// persist to the back end (DB)
				//**************************************************************************************************
				try{
					/* Set the object's FK to the value of the new parent record  */
					/* TODO: when we no longer need to support ACF9, change this to use invoke() */
					if( structKeyExists( variables, col.name ) ){
						var tmp = variables[col.name];
						evaluate("this.set#col.fkcolumn#( tmp.get#col.inverseJoinColumn#() )");
					}

				}catch (any e){
					writeDump('Error in _saveTheChildren');
					writeDump([e]);
					writeDump(col);
					writeDump(variables);

					abort;
				}
			}
		}
	}

	/**
    * I delete the current record
    **/
	public void function delete( boolean soft = false, any callback ){
		var callbackArgs = { ID = getID(), method = 'delete', deletedChildren = []};
		// Remove deleted object from cache
		lock type="exclusive" name="#this.getTable()#-#this.getID()#" timeout="1"{
			cacheRemove( '#this.getTable()#-#this.getID()#' );
		}

		if( len( trim( getID() ) ) gt 0 && !isNew() ){

			/* First delete any child records */
			for ( var col in variables.meta.properties ){
				if( structKeyExists( col, 'fieldType' )
					&& ( col.fieldType eq 'one-to-many' || col.fieldType eq 'one-to-one' )
					&& ( !structKeyExists( col, 'cascade') || col.cascade != 'save-update')
					){
					for ( var child in variables[ col.name ] ){
						try{
							arrayAppend( callbackArgs.deletedChildren, child.getID() );
							child.delete( soft );
						}catch (any e){
							writeDump('Error in delete');
							writeDump(variables);
							writeDump(child);
							writeDump([e]);
							writeDump(col.name);
							writeDump(variables[ col.name ] );abort;
						}

					}

				}
			}
			transaction{
				variables.dao.execute(sql="
						DELETE FROM #this.getTable()#
						WHERE #this.getIDField()# = #variables.dao.queryParam(value=getID(),cfsqltype='int')#
				");
			}
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
			//this.init( dao = getDao(), table = getTable() );
		}

		//this.init( dao = getDao(), table = getTable() );
		reset();
		// Fire callback function (if provided). Could be used for AOP
		if( structKeyExists( arguments, 'callback' ) && isCustomFunction( arguments.callback ) ){
			callback( this, callbackArgs );
		}

	}

	/**
	* I validate each value in the entity per set validation rules (if any)
	* and return an array of errors (or blank array if no errors)
	**/
	public array function validate( array properties = variables.meta.properties ){
		// validate each property in the entity based on the table definition
		var errors = [];
		var error = "";

		for( var prop in properties ){
			if( !structKeyExists( variables, prop.name ) ){
				continue;
			}
			error = _validate( prop, variables[ prop.name ] );
			if( len( trim( error ) ) ){
				arrayAppend( errors, error );
			}
			error = "";
		}

		return errors;
	}
	/**
	* I validate a single field and return an error (or "true" if no errors)
	**/
	public any function validateProperty( required string property, any value ){
		var val = structKeyExists( arguments, value ) ? arguments.value : ( structKeyExists( variables, property ) ) ? variables[ property ] : '';
		var ret = { valid = false, message = "Property '#property#' was not found" };
		var error = "";
		for( var prop in variables.meta.properties ){
			if( prop.name == property ){
				error = _validate( prop, val );
				// if (len(error)){
				// 	logIt( error);
				// }
				return { valid = len( error ), message = error };
			}
		}
		return ret;
	}
	/**
	* Private helper to validate that the given value is legal for the the given property.
	**/
	private string function _validate( required struct property, required any value ){
		var error = "";
		if( structKeyExists( variables, property.name )
			&& structKeyExists( property, 'type' ) ){

			var type = _safeValidationTypeName( property.type );
			if( type == "range" ){
				if( structKeyExists( property, 'min' )
					&& structKeyExists( property, 'max' )
					&& !isValid( type, value, property.min, property.max ) ){
					error = "#property.name# is not within the valid range: #property.min# - #property.max#";
				}
			}else if( type == "regex" ){
				if( structKeyExists( property, 'regex' )
					&& !isValid( type, value, property.regex ) ){
					error = "#property.name# did not match the format: '#property.regex#'";
				}
			}else if( !ArrayFindNoCase( ['any','array','Bit','Boolean','date','double','numeric','query','string','struct','UUID','GUID','binary','integer','float','eurodate','time','creditcard','email','ssn','telephone','zipcode','url','regex','range','component','variableName'], type ) ){
				// The "type" was not a valid type accepted by the isValid function.  We'll assume it is a specific cfc.
				if( !isValid( "component", value )
					|| !isInstanceOf( value, type ) ){
					error = "#property.name# was not an instance of: '#type#'";
				}
			}else if( structKeyExists( property, 'allowNulls' )
				&& !property.allowNulls
				&& ( !len( trim( value.toString() || isNull( value ) ) ) ) ){
				// Whatever the type, if we don't allow nulls, we don't allow nulls....
				error = "#property.name# does not allow nulls, yet the currenty value empty.";

			}else{
				// If we don't have a value, there's nothing to check.  Null checks were done earlier.
				if( !len( trim( value.toString() ) ) ){
					return "";
				}
				try{
					if( !isValid( type, value ) ){
						error = "The value provided for #property.name# ('#value.toString()#') is not a valid #type#";
					}
				}catch( any e ){
					writeDump( [arguments, e] );abort;
				}
			}
		}
		return error;
	}

	private any function _safeValidationTypeName( string typeName ){
		var type = arguments.typeName;

		switch( arguments.typeName) {
			case "varchar" : type = 'string';
			break;
			case "double" : type = 'numeric';
			break;
			case "bit" : type = 'boolean';
			break;
		}

		return type;
	}


	/* SETUP/ALTER TABLE */
	/**
    * I drop the current table.
    **/
	private function dropTable(){
		variables.dao.dropTable( this.getTable() );
	}

	/**
    * I create a table based on the current object's properties.
    **/
	private function makeTable(){
		// Throw a helpful error message if the BaseModelObject was instantiated directly.
		if( listLast( variables.meta.name , '.' ) == "BaseModelObject"){
			if( variables.meta.fullName == "basemodelobject"){
				throw( message = "Table #this.getTable()# does not exist", type = 'bmo' );
			}else{
				throw("If invoking BaseModelObject directly the table must exist.  Please create the table: '#this.getTable()#' and try again.");
			}
		}

		var tableDef = new tabledef( tableName = getTable(), dsn = getDao().getDSN(), loadMeta = false );
		/* var propLen = ArrayLen(variables.meta.properties);
		var prop = [];
		var col = {};
		// the for (prop in variables.meta.properties) loop was throwing a java error for me (-sy)
		for ( var loopVar=1; loopVar <= propLen; loopVar += 1 ){
			prop = variables.meta.properties[loopVar]; */
		for ( var col in variables.meta.properties ){
			col.type = structKeyExists( col, 'type' ) ? col.type : 'string';
			col.type = structKeyExists( col, 'sqltype' ) ? col.sqltype : col.type;
			col.name = structKeyExists( col, 'column' ) ? col.column : col.name;
			col.persistent = !structKeyExists( col, 'persistent' ) ? true : col.persistent;
			col.isPrimaryKey = col.isIndex = structKeyExists( col, 'fieldType' ) && col.fieldType == 'id';
			col.isNullable = !( structKeyExists( col, 'fieldType' ) && col.fieldType == 'id' );
			col.defaultValue = structKeyExists( col, 'default' ) ? col.default : '';
			col.generator = structKeyExists( col, 'generator' ) ? col.generator : '';
			col.length = structKeyExists( col, 'length' ) ? col.length : '';

			if( col.persistent && !structKeyExists( col, 'CFC' ) ){

				switch( col.type ){
					case 'string': case 'varchar':
						col.length = structKeyExists( col, 'length' ) && val( col.length ) > 0 ? col.length : 255;
					break;
					case 'numeric': case 'int':
						col.length = structKeyExists( col, 'length' ) && val( col.length ) > 0 ? col.length : 11;
					break;
					case 'date':
						col.length = '';
					break;
					case 'tinyint':
						col.length = structKeyExists( col, 'length' ) && val( col.length ) > 0 ? col.length : 1;
					break;
					case 'boolean': case 'bit':
						col.length = '';
					break;
					case 'text':
						col.length = '';
					break;
					default:
						col.length = structKeyExists( col, 'length' ) && val( col.length ) > 0 ? col.length : 255;
					break;
				}

				// Manually create the tabledef object (to be used to create the table in the DB)
				tableDef.addColumn(
					column = col.name,
					type =  col.type,
					sqlType = col.type,
					length = col.length,
					isIndex = col.isIndex,
					isPrimaryKey = col.isPrimaryKey,
					isNullable = col.isNullable,
					defaultValue = col.defaultValue,
					generator = col.generator,
					comment = '',
					isDirty = false
				);
			}

		}

		// create table and set the tabledef property
		this.setTabledef( getDao().makeTable( tableDef ) );

	}


	/* Utilities */
	/**
	* tries to camelCase based on naming conventions. For instance if the field name is "isdone" it will convert to "isDone".
	**/
	private function camelCase( required string str ){
		str = lcase( str );
		return reReplaceNoCase( str, '\b(is|has)(\w)', '\1\u\2', 'all' );
	}
	/**
	* Converts http date to CF date object (since one cannot natively in CF9).
	* @TODO Make this better :)
	**/
	private date function convertHttpDate( required string httpDate ){
		return parseDateTime( listFirst( httpDate, 'T' ) & ' ' & listFirst( listLast( httpDate, 'T' ), 'Z' ) );
	}
	/**
	* Will write the value of str to the server's application.log if norm_debugMode == true.
	**/
	private void function logIt( str ){
		if( get__DebugMode() ){
			writeLog( str );
		}
	}

/* *************************************************************************** */
/* BreezeJS interface */
/* *************************************************************************** */
	public function getBreezeMetaData( array excludeKeys = [] ){
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
		            "property" = generateBreezeProperties( excludeKeys =  excludeKeys )
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

	public array function listAsBreezeData( string filter = "", string orderby = "", string skip = "", string top = "", array excludeKeys = [] ){
		if( len(trim( filter ) ) ){
			/* parse breezejs filter operators */
			filter = reReplaceNoCase( filter, '\s(eq|==|Equals)\s(.*?)(\)|$)', ' = $queryParam(value=\2,cfsqltype="varchar")$\3', 'all' );
			filter = reReplaceNoCase( filter, '\s(ne|\!=|NotEquals)\s(.*?)(\)|$)', ' != $queryParam(value=\2)$\3', 'all' );
			filter = reReplaceNoCase( filter, '\s(lte|<=|LessThanOrEqual)\s(.*?)(\)|$)', ' <= $queryParam(value=\2)$\3', 'all' );
			filter = reReplaceNoCase( filter, '\s(gte|>=|GreaterThanOrEqual)\s(.*?)(\)|$)', ' >= $queryParam(value=\2)$\3', 'all' );
			filter = reReplaceNoCase( filter, '\s(lt|<|LessThan)\s(.*?)(\)|$)', ' < $queryParam(value=\2)$\3', 'all' );
			filter = reReplaceNoCase( filter, '\s(gt|>|GreaterThan)\s(.*?)(\)|$)', ' > $queryParam(value=\2)$\3', 'all' );
			/* fuzzy operators */
			filter = reReplaceNoCase( filter, '\s(substringof|contains)\s(.*?)(\)|$)', ' like $queryParam(value="%\2%")$\3', 'all' );
			filter = reReplaceNoCase( filter, '\s(startswith)\s(.*?)(\)|$)', ' like $queryParam(value="\2%")$\3', 'all' );
			filter = reReplaceNoCase( filter, '\s(endswith)\s(.*?)(\)|$)', ' like $queryParam(value="%\2")$\3', 'all' );
			/* TODO: figure out what "any|some" and "all|every" filters are for and factor them in here */
		}

		var list = listAsArray(
								where = len( trim( filter ) ) ? "WHERE " & preserveSingleQuotes( filter ) : "",
								orderby = arguments.orderby,
								offset = arguments.skip,
								limit = arguments.top,
								excludeKeys = arguments.excludeKeys
							);

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

	public array function toBreezeJSON( array excludeKey = [] ){
		var data  = this.toStruct( excludeKeys = arguments.excludeKeys );
		data["$type"] = "#getBreezeNameSpace()#.#getBreezeEntityName()#, DAOBreezeService";
		data["$id"] = data[ getIDField() ];

		return [data];
	}

	/**
	*   I accept an array of breeze entities and perform the appropriate DB interactions based on the metadata. I return the Entity struct with the following:
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
					// for adds this will represent the temporary ID value given by BreezeJS (i.e. -1, -2, etc..)
					var tempValue = entity[ this.getIDField() ];
					transaction{
						this.save();
					}
					// Now setup some return data for breeze client
					entity[ '$type' ] = "#getBreezeNameSpace()#.#getBreezeEntityName()#";
					entity[ this.getIDField() ] = this.getID();
					if ( structKeyExists( entity.entityAspect.originalValuesMap, entity.entityAspect.autoGeneratedKey.propertyName ) ){
						arrayAppend( keyMappings, { "EntityTypeName" = entity['$type'], "TempValue" = entity.entityAspect.originalValuesMap[ entity.entityAspect.autoGeneratedKey.propertyName ], "RealValue" = this.getID() } );
					}else if ( entity.entityAspect.entityState == 'Added' ){
						arrayAppend( keyMappings, { "EntityTypeName" = entity['$type'], "TempValue" = tempValue, "RealValue" = this.getID() } );
					}
				} catch( any e ){
					// append any errors found to return data for breeze client;
					arrayAppend( errors, {"ErrorName" = e.error, "EntityTypeName" = entity.entityAspect.entityTypeName, "KeyValues" = [], "PropertyName" = "", "ErrorMessage" = e.detail } );
				}
			}

			// remove the entityAspect key from the struct.  We don't need it in the returned data; in fact breeze will error if it exists..
			structDelete( entity, 'entityAspect' );
		}

		var ret = { "Entities" = arguments.entities, "KeyMappings" = keyMappings };
		if ( arrayLen( errors ) ){
			ret["Errors"] = errors;
		}

		return ret;
	}

	/**
	*  I return the namespace to be used by breeze to contain this entity.
	*  To ensure uniqueness I use a reverse dir path plus the DSN (in dot notation).
	*  Example: Com.Model.Dao
	**/
	private function getBreezeNameSpace(){
		// windows uses backslash instead of forwards slash and this messes up regex
		// so we escape them if they are present  (-sy)
		var basePath = replace(getDirectoryFromPath(getbaseTemplatePath()),"\","\\","all");
		var curpath = replace(expandPath('/'),"\","\\","all");
		var m = reReplace( basepath, "#curpath#",chr(888));
		m = listRest( m, chr(888) );
		m = listChangeDelims(m ,".", '/');
		var reversed = "";
		for( var i = listLen( m ); i GT 0; i-- ){
			reversed = listAppend( reversed, listGetAt( m, i ) );
		}
		return "#reReplace( len( trim( reversed ) ) ? reversed : 'model', '\b(\w)', '\u\1', 'all')#.#reReplace( dao.getDSN(), '\b(\w)' ,'\u\1', 'all')#";
	}

	/**
	* I return the name of the entity container, i.e. the table name. We'll use either the table name or a singularName if defined.
	**/
	private function getBreezeEntityName(){
		return structKeyExists( variables.meta, 'singularName' ) ? variables.meta.singularName : this.getTable();
	}

	/**
	* I return an array of structs containing all of the breeze friendly properties of the entity (table).
	**/
	private function generateBreezeProperties( array excludeKeys = [] ){
		var props = [];
		//var prop = { "validators" = [] };
		var prop = { };

		for ( var col in variables.meta.properties ){
			/* TODO: flesh out relationships here */
			if( !structKeyExists( col, 'type') || ( structKeyExists( col, 'persistent' ) && !col.persistent ) || arrayFindNoCase( excludeKeys, col.name ) ){
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

	/**
	* Given a CF or DB data type, I return the equivalent Breeze data type.
	**/
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