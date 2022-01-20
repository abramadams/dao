/**
*	Copyright (c) 2013-2018, Abram Adams
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
*	Tested on CF10/11, Railo 4.x, Lucee 4.x, will not work on CF9+ due to use of function expressions and closures
*   @version 1.0.0
*   @dependencies { "dao" : ">=0.0.80" }
*   @updated 10/20/2021
*   @author Abram Adams
**/

component accessors="true" output="false" {

	property name="_norm_version" type="string" norm_persistent="false";
	property name="_norm_updated" type="string" norm_persistent="false";

	/* properties */
	property name="table" type="string" norm_persistent="false";
	property name="parentTable" type="string" norm_persistent="false";
	property name="IDField" type="string" norm_persistent="false";
	property name="IDFieldType" type="string" norm_persistent="false";
	property name="IDFieldGenerator" type="string" norm_persistent="false";
	property name="deleteStatusCode" type="numeric" norm_persistent="false";

	/* Table make/reload options */
	property name="dropcreate" type="boolean" default="false" norm_persistent="false";
	property name="createTableIfNotExist" type="boolean" default="false" norm_persistent="false";
	/* Relationship properties*/
	property name="autoWire" type="boolean" norm_persistent="false" hint="If false, I prevent the load() method from auto wiring relationships.  Relationships can be bolted on after load, so this can be used for performance purposes.";
	property name="dynamicMappings" type="struct" norm_persistent="false" hint="Defines alias to table name mappings.  So if you want the entity property to be OrderItems, but the table is order_items you would pass in { 'OrderItems' = 'order_items' } ";
	property name="dynamicMappingFKConvention" type="string" norm_persistent="false" hint="Defines naming convention used to guess foriegn key names.  Use {table} as a placeholder for the table name.  For example if the table was Order_Itms: {table}_Id would match order_items_Id";
	property name="excludedEntities" type="array" norm_persistent="false" hint="Array of table/entities that should not be autowired.";
	property name="__fromCache" type="boolean" norm_persistent="false";
	property name="__cacheEntities" type="boolean" norm_persistent="false";
	property name="cachedWithin" type="any" norm_persistent="false";
	property name="__debugMode" type="boolean" norm_persistent="false";
	property name="__threaded" type="boolean" norm_persistent="false";
	/* OData properties*/
	property name="oDataVersion" type="numeric" norm_persistent="false";
	property name="oDataBaseUri" type="string" norm_persistent="false";

	/* Dependancies */
	property name="dao" type="dao" norm_persistent="false";
	property name="tabledef" type="tabledef" norm_persistent="false";

	// Some "private" variables
	_isNew = true;
	_isDirty = false;
	_children = [];
	_pristine = {};
	_tableDefs = {};
	_aliases = {};
	_cacheEnabled = "";


	/* *************************************************************************** */
	/* Mixins for extended functionality (i.e. oData )							   */
	/* *************************************************************************** */
	include "oData.cfm";


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
								string dynamicMappingFKConvention = "{table}_ID",
								array excludedEntities = [],
								boolean autoWire = true,
								boolean cacheEntities = false, /* 2015-1-19 still experimental DO NOT USE */
								boolean debugMode = false,
								boolean threaded = true,
								numeric oDataVersion = 3,
								string oDataBaseUri = "/",
								any cachedWithin = createTimeSpan( 0, 0, 0, 2 ) ){
		var LOCAL = {};
		set__FromCache( false );
		set__cacheEntities( cacheEntities );
		if( get__cacheEntities() && !__cacheEnabled() ){
			set__cacheEntities( false );
		}
        // If true, will tell logIt() to actually write to log.
		set__debugMode( debugMode );
		set__threaded( threaded );

		setODataVersion( oDataVersion );
		setODataBaseUri( oDataBaseUri );

		setExcludedEntities( excludedEntities );
		// Make sure we have a dao (see dao.cfc)
		if( isValid( "component", arguments.dao ) ){
			variables.dao = arguments.dao;
		} else {
			// If DAO wasn't supplied, see if there is a default dsn and if so, create an instance of DAO with it.
			var = appMetaData = getApplicationMetadata();
			if( !isNull( appMetaData.datasource ) ){
				arguments.dsn = isSimpleValue( appMetaData.datasource ) ? appMetaData.datasource : appMetaData.datasource.name;
				variables.dao = new dao();
			}else{
				throw(
						type = "NORM.MissingDAO",
						message = "You must pass in an instance of DAO or have a default Datasource set",
						detail = "You must either pass in an instance of DAO or set a default datasource in Application.cfc.  CAUTION: Not passing in a DAO will result in a new instance of DAO to be instantiated for each Norm instance.  It is more efficient to create a globally scoped DAO and pass it in."
					);
			}

		}
		setDropcreate( dropcreate );
		setCreateTableIfNotExist( createTableIfNotExist );
		// used to introspect the given table.
        variables.meta = _getMetaData();
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
			logIt('Table was not provided, ended up using #getTable()#');
		}else{
			setTable( arguments.table );
		}

		// rewrite table to meta in case the name changed above.
		variables.meta.table = getTable();

		setParentTable( arguments.parentTable );
		setcachedWithin( arguments.cachedWithin );
		setDynamicMappings( arguments.dynamicMappings );
		setDynamicMappingFKConvention( arguments.dynamicMappingFKConvention );
		// For development use only, will drop and recreate the table in the database
		// to give you a clean slate.
		if( getDropCreate() ){
			logIt('droppping #this.getTable()#');
			dropTable();
			logIt('making #this.getTable()#');
			makeTable();
		}else{
			try{
				logIt('Loading any mappings for #this.getTable()#');
				var mapping = _getMapping( getTable() );
				// load the table definition based on the given table.
				setTableDef( _loadTableDef( mapping.table ) );
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
						// writeDump( this );
						throw( e.message );
					}
				}else{
					rethrow;
				}
			}
		}
		// Setup the ID (primary key) field.  This can be used to generate id values, etc..
		setIDField( variables.tabledef.hasColumn( arguments.IDField ) ? arguments.IDField : variables.tabledef.getPrimaryKeyColumn() );
		setIDFieldType( variables.tabledef.getDummyType( variables.tabledef.getColumnType( getIDField() ) ) );
		setAutoWire( arguments.autoWire );
		setDeleteStatusCode( arguments.deleteStatusCode );
		variables.dao.addTableDef( variables.tabledef );

		variables.meta.properties =  structKeyExists( variables.meta, 'properties' ) ? variables.meta.properties : [];
		// If there are more columns in the table than there are properties, let's dynamically add them
		// This will allow us to dynamically stub out the entity "class".  So one could just create a
		// CFC without any properties, then point it to a table and get a fully instantiated entity, or they
		// could directly instantiate Norm and pass it a table name and get a fully instantiated entity.

		var found = false;

		// We'll loop through each column in the table definition and see if we have a property, if not, create one.
		for( var col in variables.tabledef.instance.tablemeta.columns ){
			var colName = _alias( col );
			for ( var existingProp in variables.meta.properties ){
				if ( ( structKeyExists( existingProp, 'column' ) && existingProp.column EQ col )
					|| ( structKeyExists( existingProp, 'name' ) && existingProp.name EQ col )
					|| ( structKeyExists( existingProp, 'column' ) && existingProp.column EQ colName )
					|| ( structKeyExists( existingProp, 'name' ) && existingProp.name EQ colName ) ){
					//property exists skip to the next column
					found = true;
					break;
				}
			}
			// table column didn't exist as a property, let's add it.
			if ( !found ){

				variables[ col ] = this[ col ] = "";
				// _setter/_getter are generic setters/getters that allow us to do things like dirty checking
				variables["set" & col] = this["set" & col] = this.methods["set" & col] = _setter;
				variables["get" & col] = this["get" & col] = this.methods["get" & col] = _getter;
				// if set to autowire, we'll check for any entity mappings and set those up now.
				var mapping = getAutoWire()
					? _getMapping( colName )
					: structKeyExists( getDynamicMappings(), colName )
						? _getMapping(
								structKeyExists( getDynamicMappings()[ colName ], 'table' )
									? getDynamicMappings()[ colName ]['table']
									: getDynamicMappings()[ colName ] )
						: { property: col, table: colName, 'createdBy': "autoWire" };
				var newProp = {
					"name": mapping.property,
					"column": col,
					"generator": variables.tabledef.instance.tablemeta.columns[col].generator,
					"fieldtype": variables.tabledef.instance.tablemeta.columns[col].isPrimaryKey ? "id" : "",
					"type": variables.tabledef.getDummyType(variables.tabledef.instance.tablemeta.columns[col].type),
					"dynamic": true
				};
				if( structKeyExists( getDynamicMappings(), col ) ){
					var tableDef = _loadTableDef( mapping.table );
					if( tableDef.getIsTable() && !arrayFindNoCase( getExcludedEntities(), mapping.table) ){
						newProp["table"] = mapping.table;
						newProp["fkcolumn"] = col;
					}
				}
				if( structKeyExists( mapping, 'cfc' ) ){
					newProp["cfc"] = mapping.cfc;
				}
				if ( structKeyExists( variables.tabledef.instance.tablemeta.columns[col], 'length' ) ){
					newProp["length"] = variables.tabledef.instance.tablemeta.columns[col].length;
				}
				if ( structKeyExists( variables.tabledef.instance.tablemeta.columns[col], 'where' ) ){
					newProp["where"] = variables.tabledef.instance.tablemeta.columns[col].length;
				}
				if( !structIsEmpty( newProp ) ){
					arrayAppend( variables.meta.properties, newProp );
				}
			}

			found = false;

			if( getAutoWire() ){
				resolveChildEntity( col );
			}
		}
		// }

     /**
     * This will hijack all of the setters and inject a function that will set the
     * isDirty flag to true anytime data changes
     **/
		// var setter = _setter;
		for ( var prop in variables.meta.properties ){
			if( ( !structKeyExists( prop, 'setter' ) || prop.setter )
					&& ( !structKeyExists( prop, 'fieldType' ) ||  prop.fieldType does not contain '-to-' ) ){

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
				if( ( !structKeyExists( prop, 'setter' ) || prop.setter )
						&& ( !structKeyExists( prop, 'fieldType' ) ||  prop.fieldType does not contain '-to-' ) ){
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
	* Overloads the setter for the table variable.  This will check for the proper table name (case sensitive) and cache an instance of the tabledef.
	**/
	public void function setTable( table ){
		// This will make sure the table name is properly cased
		var tableDef = _loadTableDef( table );
		if( tableDef.getIsTable() ){
			variables.table = tableDef.getTableName();
		}else if( getCreateTableIfNotExist() ){
			// If the table does not exist and we were told to create if it doesn't, create it.
			// writeDump(table);abort;
			variables.table = table;
			makeTable();
			var tableDef = _loadTableDef( table );
		}else{
			throw( message = "Table #table# does not exist", type="NORM.setTable", detail="Table #table# does not exist in #getDao().getDSN()#");
		}

	}

	/**
	* Tries to access the cache object, if it errors that means there is not a default object cache setup
	**/
	private function __cacheEnabled(){
		if( len( trim( this?._cacheEnabled ) ) ){
			return _cacheEnabled;
		}
		this?._cacheEnabled = true;
		try{
			cacheCount('');
		}catch(any e){
			_cacheEnabled = false;
		}
		return this?._cachEnabled?:false;
	}
	/**
	* Convenience "factory" function to grab an instance of tabledef for the given table (or create one of one doesn't exist)
	**/
	private function _loadTableDef( table, ignoreCache = false ){
		// Pull from cache if it exists, and we aren't told not to
		if( !ignoreCache && get__cacheEntities() ){
			var tableDefFromCache = cacheGet( "#this.getDao().getDsn()#-tabledef-#table#" );
			if( !isNull( tableDefFromCache )){
				if( tableDefFromCache.getIsTable() ){
					variables._tableDefs[ table ] = tableDefFromCache;
				}
				return tableDefFromCache;
			}
		}
		if( structKeyExists( variables._tableDefs, table )  && get__cacheEntities() ){
			cachePut( "#this.getDao().getDsn()#-tabledef-#table#", variables._tableDefs[ table ], createTimeSpan( 0, 0, 30, 0 ) );
			return variables._tableDefs[ table ];
		}
		var tableDef = new tabledef( tableName = table, dsn = getDao().getDSN() );
		if( tableDef.getIsTable() ){
			variables._tableDefs[ table ] = tableDef;
		}
		if( get__cacheEntities() ){
			cachePut( "#this.getDao().getDsn()#-tabledef-#table#", tableDef, createTimeSpan( 0, 0, 30, 0 ) );
		}

		return tableDef;
	}
	/**
	* I inject a property into the current instance.  Shorthand for inserting the
	* property into the "this" and "variables" scope
	**/
	private function _injectProperty( required string name, required any val, struct prop = {} ){
		variables[ name ] = val;
		this[ name ] = val;
		var exists = variables.meta.properties.find( function( a ){
		    return a.name == name;
		});
		if( exists ){
			arrayDeleteAt(variables.meta.properties, exists );
		}
		if( structIsEmpty( prop ) ){
			// Define the property struct (including any existing mappings)
			var mapping = _getMapping( name );
			var newProp = {
							"name": mapping.property,
							"column": name,
							"generator": "",
							"fieldtype": "",
							"type": "",
							"addedBy": "_injectProperty",
							"dynamic": true
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
		var metadata = deSerializeJSON( serializeJSON( getMetadata( this ) ) );
		var privateKeys = [];
		// writeDump( metadata );abort;
		if( structKeyExists( metadata, 'properties' ) ){
			for( var prop in metadata.properties ){
				// privateKeys will be used as a default excludeKeys argument for returning
				// the entity as a struct or json.  We only need to return norm_persistent properties in those cases.
				if( ( !structKeyExists( prop, 'norm_persistent' ) || prop.norm_persistent == false )
					  && !structKeyExists( prop, 'cfc') ){
					arrayAppend( privateKeys, prop.name );
				}
			}
		}
		metadata["privateKeys"] = privateKeys;
		metadata["childEntities"] = getChildEntities();
		return metadata;
	}

	/**
	* Convenience method for choosing the correct setter for the type.
	**/
	private function _getSetter( any type = "" ){
		switch ( type ){
			case 'numeric':
			setter = _setNumberFunc;
			case 'date':
			setter = _setDateFunc;
			case 'boolean':
			setter = _setBooleanFunc;
			default:
			setter = _setter;
		}

		return setter;
	}

	/**
	* Convenience method for synthesised getters.
	**/
	private any function _getter( any name = "" ){

		if( len( trim( name ) ) ){
			return this[ name ];
		}
		var functionName = getFunctionCalledName();

		if( left( functionName, 3) == "get" && functionName != 'getterFunc' && functionName != 'getter' ){

			var propName = mid( functionName, 4, len( functionName ) );
			return variables[ propName ];
		}

		return "";

	}


	/**
	* Convenience method for synthesised setters.
	* This function will replace each public setter so that the isDirty
	* flag will be set to true anytime data changes.
	**/
	private function _setter( required any v, string propertyName = getFunctionCalledName() ){
		var functionName = getFunctionCalledName();
		// prevent infinite recursion
		if( functionName == 'tmpFunc' ||  propertyName == 'setterFunc'  ){
			return;
		}
		// We use the calling function's name to determine the propertyName
		// if this was called via a set function on a property.
		if( left( propertyName, 3) == "set" ){
			propertyName = mid( propertyName, 4, len( propertyName ) );
		}
		// If the property exists, compare the old value to the new value (case sensitive)
		if( structKeyExists( variables, propertyName ) && isSimpleValue( v ) ){
			// If the old value isn't identical to the new value, set the isDirty flag to true
			// This only needs to be set if it isn't already
			if( !variables._isDirty ){
				this._setisDirty( compare( v, variables[ propertyName ] ) != 0 );
			}
		}

		// Dynamically added properties won't have setters.  This will manually stuff the value into the property
		this[ propertyName ] = variables[ propertyName ] = v;

		if( structKeyExists( variables, "$$__" & functionName ) ){
			logIt('set called via _setter as #functionName# and dirty is: #variables._isDirty#: new value: "#v#" original value: "#variables[propertyName]#"');
			// Get the original setter function that we set aside in the init routine.
			this.__tmpFunc = variables[ "$$__" & functionName ];
			// tmpFunc is now the original setter so let's fire it.  The calling page
			// will not know this happened.
			this.__tmpFunc( v );
			structDelete( this, '__tmpFunc' );
			logIt('set called via _setter as #functionName#... finished');
		}

	}
	private function _setNumberFunc( required numeric v ){
		_setter( v );
	}
	private function _setBooleanFunc( required boolean v ){
		_setter( v );
	}
	private function _setDateFunc( required date v ){
		_setter( v );
	}

	/**
	* Convenience method for synthesised adders.
	**/
	private function _adder( any value ){
		var propName = getFunctionCalledName();
		propName = mid( propName, 4, len( propName ) );
		this._setIsDirty( true );
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
			if( isArray( variables[ propName ] ) ){
				arrayAppend( variables[ propName ], value );
				arrayAppend( this[ propName ], value );
			}

		}catch( any e ){
			throw( message = "There was a problem adding to #propName#", type="NORM.adder", detail="There was a problem adding to #propName#. #e.message#: #e.detail#");
			// writeDump([propName , value.getID(), e, this]);abort;
		}
	}
	// Generic set/get functions
	public void function set( required string property, required any value ){
		_setter( value, property );
	}
	public any function get( required string property ){
		return this[ property ];
	}

	/**
	* Convenience method for synthesised removers.
	**/
	private function _remover( any index ){
		var propName = getFunctionCalledName();
		var idx = index;
		propName = mid( propName, 7, len( propName ) );
		this._setIsDirty( true );
		try{
			if( isObject( index ) ){
				idx = arrayFind( variables[ propName ], index );
			}
			if( idx > 0 ){
				arrayDeleteAt( variables[ propName ] , idx );
			}

		}catch( any e ){
			// writeDump([propName , index, e ]);abort;
			throw( message = "There was a problem removing item from #propName#", type="NORM.remover", detail="There was a problem removing item from #propName#. #e.message#: #e.detail#");
		}
		// TODO: work out a way to cascade delete the removed child...
	}

	/**
	* Convenience method for synthesised 'has' checks (i.e. hasOrders) .
	**/
	private function _has(){
		var propName = getFunctionCalledName();
		propName = mid( propName, 4, len( propName ) );
		return isArray( variables[ propName ] ) && arrayLen( variables[ propName ] );
	}
	
	/**
	* I return true if the supplied column exists on the current enttity
	**/
	public function columnExists( column ){
		return variables.tabledef.hasColumn(column );
	}

	/**
	* I return true if the current state represents a new record/document
	**/
	public boolean function isNew(){
		return variables._isNew;
	}
	public void function _setIsNew( boolean val = true ){
		variables._isNew = val;
	}

	/**
	* I return true if any of the original data has changed.  This is a read-only property because the
	* entity obejct properties' setters set this flag when data actually changes.
	**/
	public boolean function isDirty(){
		return variables._isDirty;
	}
	public function _setIsDirty( required boolean isDirty ){
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
					// Using defined naming convention to create a potential fk column name to check for.
					var potentialFkColumn = getPotentialFKColumnName( mapping.table );
					// MANY-TO-ONE
					if( structKeyExists( mapping, 'key')
							&& ( structKeyExists( variables, potentialFkColumn )
						|| structKeyExists( variables, mapping.key ) )
					){
						// NOTE: If mapping.key didn't exist that means the "getterInstructions" did not resolve to a table or a foriegn key to a parent table that we could decipher.
						// Loading Many to One relationship for getterInstructions
						logIt('CALLING _getManyToOne() for #mapping.table# (#propertyName#) #returnType# (dynamically called via #arguments.missingMethodName# on #this.getTable()# for #this.getID()# [ #mapping.table# : #mapping.property# : #mapping.key#])');
						variables[ propertyName ] = this[ propertyName ] = _getManyToOne(
																			table = lcase( mapping.table ),
																			property = propertyName,
																			fkColumn = mapping.key != mapping.table ? mapping.key : potentialFkColumn,
																			returnType = returnType );
						logIt('loaded child #variables[propertyName].getID()# from #mapping.table# into property #propertyName#');
						return variables[ propertyName ];
					}else{

						// ONE-TO-MANY
						// If the current entity didn't have a FK to the table, maybe we need to load a one-to-many.
						// Let's try to find a table matching the getterInstructions and load all records matching the
						// current entity's ID value.

						logIt('CALLING _getOneToMany() for #newTableName# (#propertyName#) #returnType# (dynamically called via #arguments.missingMethodName# on #this.getTable()# for #this.getID()# [ #mapping.table# : #mapping.property#])');
						var ret =  _getOneToMany( table = lcase( mapping.table ), property = propertyName, returnType = returnType, fkColumn = mapping.key != mapping.table ? mapping.key : potentialFkColumn );
						logIt('And that returned an object? #isObject( ret )#');
						return isObject( ret ) ? ret : variables[ propertyName ];

					}

				} catch ( any e ){
					if( e.type != 'NORM' ){
						writeDump(["test",e,mapping]);abort;
						throw(e.message?:e.detail);
					}
					rethrow;
					// writeDump(["another test",arguments,e,mapping,variables]);abort;
				}
			}else if( getterInstructions contains "By"){
				try{
					var newTableName = var propertyName = left( getterInstructions, findNoCase( 'by', getterInstructions ) - 1 );
					var byClause = mid( getterInstructions, findNoCase( 'by', getterInstructions ) + 2, len( getterInstructions ) );

					var mapping = _getMapping( newTableName );
					var propertyName = propertyName == mapping.table ? mapping.property : propertyName;

					if( structKeyExists( variables, byClause ) || structKeyExists( variables, mapping.key ) ){
						// MANY-TO-ONE
						// If the "getter" contains the "by" clause, we'll try to load
						// the child record based on the "by" clause.  For instance
						// if the method call was getUsersByCreated_Users_ID we would try to load
						// the record from the users table where users.ID == the current entity's
						// Created_Users_ID value.
						variables[ propertyName ] = this[ propertyName ] = _getManyToOne(
																				table = lcase( mapping.table ),
																				property = propertyName,
																				fkColumn = byClause,
																				returnType = returnType );
						return variables[ propertyName ];

					}else{
						// @TODO: add support for multiple By clauses (i.e. byInvoice_NumberAndCompanies_ID)
						// ONE-TO-MANY
						// If the by clause was not a property in the current entity, we'll try to load one-to-many
						// records from the given table based on the by clause.
						// variables[ propertyName ] = this[ propertyName ] = _getOneToMany( table = lcase( newTableName ), pkValue = this.getID(), fkColumn = byClause );
						// return variables[ propertyName ];
						logIt('CALLING _getOneToMany() for #newTableName# using byClause #byClause# #right(arguments.missingMethodName, 8)#');
						var ret =  _getOneToMany( table = lcase( mapping.table ), property = propertyName, pkValue = this.getID(), fkColumn = byClause, returnType = returnType );
						return isObject( ret ) ? ret : variables[ propertyName ];
					}

				} catch ( any e ){
					if( e.type != 'NORM' ){
						throw(e.detail);
						// writeDump([e]);abort;
					}
				}
			}

		}else if( left( arguments.missingMethodName, 3 ) is "set" ){
			if( structKeyExists( this, missingMethodName ) ){
				var propertyName = removeChars( missingMethodName, 1, 3 );
				// Handles cases when the onMissingMethod was called directly
				// but a setter exists.
				this[ missingMethodName ] = variables[ missingMethodName ] = _setter;
				// place the tmp func inside the current object.  This way when it fires
				// it will fire in the context of the "this" object, referencing and affecting
				// properties in that object.
				this.__tmpFunc = this[ missingMethodName ];
				this.__tmpFunc( missingMethodArguments[ 1 ], propertyName );
				structDelete( this, '__tmpFunc' );
				variables[ propertyName ] = this[ propertyName ];
				return this;
			}
			// Handle setters that may not have been assigned to dynamic properties
			var tableName = mid( arguments.missingMethodName, 4, len( arguments.missingMethodName ) );
			var mapping = _getMapping( tableName );
			_injectProperty( mapping.property, arguments.missingMethodArguments[ 1 ] );
			this._setIsDirty( true );
			logIt('#arguments.missingMethodName# :: #isDirty()#');

			return this;

		}else if( left( arguments.missingMethodName, 7 ) is "hasMany" ){

			// Inject array of child objects
			var newTableName = mid( arguments.missingMethodName, 8, len( arguments.missingMethodName ) );
			logIt('CALLING _getOneToMany() for #newTableName# using hasmany missing method handler');
			variables[ newTableName ] = this[ newTableName ] = _getOneToMany( table = lcase( newTableName ), returnType = returnType );

			return this;

		}else if( left( arguments.missingMethodName, 9 ) is "belongsTo" ){

			var newTableName = mid( arguments.missingMethodName, findNoCase( "belongsTo", arguments.missingMethodName ) - 1, len( arguments.missingMethodName ) );
			// Using defined naming convention to create a potential fk column name to check for.
			var potentialFkColumn = getPotentialFKColumnName(  newTableName );
			var tableDef = _loadTableDef( newTableName );
			logIt('is #table# a table? #tableDef.getIsTable()#');
			if( tableDef.getIsTable() ){
				variables[ "get" & newTableName ] = this[ "get" & newTableName ] = function(){
					return _getOneToMany( table = lcase( newTableName ), returnType = returnType );
				};
			}

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
			var tableDef = _loadTableDef( newTableName );
			logIt('is #table# a table? #tableDef.getIsTable()#');
			if( tableDef.getIsTable() ){
				variables[ "get" & newTableName ] = this[ "get" & newTableName ] = function(){
					return _getOneToMany( table = lcase( newTableName ), returnType = returnType );
				};
			}

		}

		// Allow "loadFirst" method to instantiate the entity and load it with the first
		// record returned per the "By" criteria
		if( left( arguments.missingMethodName, 9 ) is "loadFirst" ){
			limit = 1;
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
					try{
						// Dynamically calling a function is not supported very well on ACF.
						// so one cannot just this["set#queryArguments[ i ]#"]( value )
						// There are a few ways to do this, we can inject a temporary function
						// to the object"
						//   this.__tmpFunc = this['set#queryArguments[ i ]#'];
						//   this.__tmpFunc( arguments.missingMethodArguments[ i ] );
						//   structDelete( this, '__tmpFunc' );
						// We can use the dreaded evaluate:
						//   evaluate("this.set#queryArguments[ i ]#(arguments.missingMethodArguments[ i ])");
						// We could use a wrapper function (i.e. call( funcName, args ) )
						// We could use invoke (though not portable between engines/versions)
						// Or we can directly invoke the onMissingMethod:
						this.onMissingMethod( "set#queryArguments[ i ]#", { 1:arguments.missingMethodArguments[ i ] } );

					} catch ( any err ){
						throw("Error Loading data into #this.getTable()# object.");
					}
				}

			}

			if( structCount( missingMethodArguments ) > arrayLen( queryArguments ) ){
				where = missingMethodArguments[ arrayLen( queryArguments ) + 1 ];
				where = len( trim( where ) ) ? where : '1=1';
			}

			var columns = this.getDAO().getSafeColumnNames( this.getTableDef().getColumns() );

			record = variables.dao.read(
				table = this.getTable(),
				columns = columns,
				where = "WHERE #where# #recordSQL#",
				orderby = orderby,
				limit = limit,
				name = "model_load_by_handler_#arguments.missingMethodName#"
			);


			variables._isNew = record.recordCount EQ 0;

			//If a record existed, load it
			if( record.recordCount == 1 && !left( originalMethodName, 7 ) == "loadAll" && !left( originalMethodName, 11 ) == "lazyLoadAll" && returnType == "object" ){
				return this.load( ID = record, lazy = left( originalMethodName , 4 ) is "lazy" );
			// If more than one record was returned, or method called was a "loadAll" type, return an array of data.
			}else if( record.recordCount >= 1 || left( originalMethodName, 7 ) == "loadAll" || left( originalMethodName , 11 ) == "lazyLoadAll" ) {
				logIt('lazy load all #this.getTable()# - [#originalMethodName# | #getParentTable()#]');
				var recordArray = [];
				var recCount = record.recordCount;
				// var tmpLazy = left( originalMethodName , 4 ) is "lazy" || record.recordCount GTE 3 || this.getParentTable() != "";
				// If there are a bunch of child records, this can bring down the server. We'll short circuit that and
				// just return the query results as an array.
				if( returnType == "array" ){
					return getDao().queryToArray( record );
				}
				var tmpNewEntity = $new( dao = this.getDao(), table = this.getTable() );
				if( get__threaded() && 1==0 ){
					var threads = "";
					for ( var rec = 1; rec <= recCount; rec++ ){
						var threadName = "thread"&hash("load-child-#this.getTable()#-#createUUID()#-#rec#");
						threads = listAppend( threads, threadName );
						logIt('iterating #rec# of #recCount# records');
						thread action="run"
							name="#threadName#"
							recordArray="#recordArray#"
							parentTable="#getParentTable()#"
							returnType="#returnType#"
							tmpNewEntity="#tmpNewEntity#" rec="#rec#" record="#record#" table="#this.getTable()#" idField="#getIDField()#" cacheEntities="#get__cacheEntities()#" {
							// thread.recordArray = recordArray;
							param name="thread.recordArray" default="#[]#";
	 						var qn = queryNew( record.columnList );
							queryAddRow( qn, 1 );
							// append each record to the array. Each record will be an instance of the model entity in represents.  If lazy loading
							// this will be an empty entity instance with "overloaded" getter methods that instantiate when needed.
							var colList = listToArray( record.columnList );
							for( var col in colList ){
								querySetCell( qn, col, record[ col ][ rec ] );
							}
							if( cacheEntities ){
								lock type="readonly" name="#this.getDao().getDsn()#-#qn[ idField ][ 1 ]#" timeout="3"{
									var cachedObject = cacheGet( '#this.getDao().getDsn()#-#table#-#qn[ idField ][ 1 ]#' );
								}
							}
							logIt('is object cached? #yesNoFormat(!isNull(cachedObject))#');
							if( !isNull( cachedObject ) ){
								// object cached, load from memory.
								var tmpNewEntity = cachedObject;
							}else{

								// Creating a new instance of the entity for each record.  Tried to use duplicate( this ), but that
								// does not appear to be thread safe and ends up causing concurrency issues.
								// var tmpNewEntity = $new();
								logIt('instantiating new object for #this.getTable()# as part of a loadAll call. [#arguments.missingMethodName# : #serializeJSON(arguments.missingMethodArguments)#');
								// var tmpNewEntity = createObject( "component", variables.meta.fullName ).init( dao = this.getDao(), table = this.getTable(), dynamicMappings = getDynamicMappings(), excludedEntities = getExcludedEntities() );
								// var tmpNewEntity = new "#variables.meta.fullName#"( argumentCollection:this );

								// var start = getTickCount();
								tmpNewEntity.lazyLoad( ID = qn, parenttable = parentTable );
								logIt("took #(getTickCount()-start)/1000# seconds to lazily load one of #recCount# child objects for #getTable()#");
							}

							if( returnType is "struct" /* || returnType is "array"  */){
								tmpNewEntity = tmpNewEntity.toStruct();
							}else if (returnType is "json"){
								tmpNewEntity = tmpNewEntity.toJSON();
							}
							arrayAppend( thread.recordArray, tmpNewEntity );

						}
					}
					thread action="join" name="#threads#";
					recordArray = cfthread[listLast(threads)].recordArray;
				}else{

					for ( var rec = 1; rec <= recCount; rec++ ){
						logIt('iterating #rec# of #recCount# records');
						var qn = queryNew( record.columnList );
						queryAddRow( qn, 1 );
						// append each record to the array. Each record will be an instance of the model entity in represents.  If lazy loading
						// this will be an empty entity instance with "overloaded" getter methods that instantiate when needed.
						var colList = listToArray( record.columnList );
						for( var col in colList ){
							querySetCell( qn, col, record[ col ][ rec ] );
						}
						if( get__cacheEntities() ){
							lock type="readonly" name="#this.getDao().getDsn()#-#this.getTable()#-#qn[ getIDField() ][ 1 ]#" timeout="3"{
								var cachedObject = cacheGet( '#this.getDao().getDsn()#-#this.getTable()#-#qn[ getIDField() ][ 1 ]#' );
							}
						}
						logIt('is object cached? #yesNoFormat(!isNull(cachedObject))#');
						if( !isNull( cachedObject ) ){
							// object cached, load from memory.
							var tmpNewEntity = cachedObject;
						}else{

							// Creating a new instance of the entity for each record.  Tried to use duplicate( this ), but that
							// does not appear to be thread safe and ends up causing concurrency issues.
							// var tmpNewEntity = $new();
							logIt('instantiating new object for #this.getTable()# as part of a loadAll call. [#arguments.missingMethodName# : #serializeJSON(arguments.missingMethodArguments)#');
							// var tmpNewEntity = createObject( "component", variables.meta.fullName ).init( dao = this.getDao(), table = this.getTable(), dynamicMappings = getDynamicMappings(), excludedEntities = getExcludedEntities() );
							// var tmpNewEntity = new "#variables.meta.fullName#"( argumentCollection:this );

							var start = getTickCount();
							tmpNewEntity.lazyLoad( ID = qn, parenttable = getParentTable() );
							logIt("took #(getTickCount()-start)/1000# seconds to lazily load one of #recCount# child objects for #getTable()#");
						}

						if( returnType is "struct" /* || returnType is "array"  */){
							tmpNewEntity = tmpNewEntity.toStruct();
						}else if (returnType is "json"){
							tmpNewEntity = tmpNewEntity.toJSON();
						}

						arrayAppend( recordArray, duplicate( tmpNewEntity ) );
					}
				}
				if( returnType is "json" ){
					return "[" & arrayToList( recordArray ) & "]";
				}
				if( arraylen( recordArray ) == 1 && returnType != "array" ){
					recordArray = recordArray[ 1 ];
				}

				return recordArray;

			//Otherwise, set the passed in arguments and return the new entity
			}else{

				for ( i = 1; i LTE arrayLen(queryArguments); i++ ){
					//Setup defaults
					 try{
						if( validateProperty( queryArguments[ i ], arguments.missingMethodArguments[ i ] ).valid ){
							this.onMissingMethod( 'set#queryArguments[ i ]#', { 1:arguments.missingMethodArguments[ i ] } );
						}
						this._setIsDirty( false );
					} catch ( any err ){
						rethrow;
					}
				}

				return this;
			}
		}
		if( missingMethodName != '__tmpFunc' ){
			// throw error
			throw( message = "Missing method", type="variables", detail="The method named: #arguments.missingMethodName# did not exist in #getmetadata(this).path#.");
		}

	}


	/**
	* Sets the current instance of the model object as a "new" record.  This will cause an insert instead
	* of an update when the save() method is called, retaining the original data, but generating a new record
	* with new primary key/generated ID values.  Use this when creating several records of the same entity
	* type to save on the instantiation costs. (i.e. reuse instance instead of doing 'entity = new Norm('....')')
	**/
	public function $copy(){
		variables._isNew = true;
		variables[ getIDField() ] = '';
	}
	/**
	* Creates a new empty instance of the entity.  If properties are passed in the new instance will
	* be loaded with these properties.
	**/
	public function $new(
			 struct properties = {}
			,string table = getTable()
			,dao dao = getDao()
			,string IDField = getIDField()
			,struct dynamicMappings = getDynamicMappings()
			,string dynamicMappingFKConvention = getDynamicMappingFKConvention()
			,array excludedEntities = getExcludedEntities()
			,boolean autoWire = getAutoWire()
			,boolean cacheEntities = get__cacheEntities()
			,any cachedWithin = getcachedWithin()
			,debugMode = get__debugMode()
			,string cfc = ""
		){
		// Pull from cache if it exists
		var cacheName = "#this.getDao().getDsn()#-empty-NORM-#table#";
		logIt('newObj $new() called for table: #table#');
		var tableDef = _loadTableDef( table );
		if( !tableDef.getIsTable() ){
			if( len( trim( cfc ) ) && structKeyExists( getComponentMetadata( cfc ), 'table' ) ){
				arguments.table = getComponentMetadata( cfc ).table;
			}else{
				throw("Cannot create new instance of #table#. Table: #table# not found in #dao.getDsn()#");
			}
		}

		var newEntity = get__cacheEntities() ? cacheGet( cacheName ) : javaCast( "null", "" );
		if( isNull( newEntity) ){
			// If not in cache, create a new instance.
			if( listLast( variables.meta.name , '.' ) == "Norm"){
					logIt('newObj : initializing #variables.meta.name# as #table#');
					newEntity = new Norm( argumentCollection:arguments );
			}else{
				// If the current entity was loaded from an entity cfc it is important to also load the new entity using the same cfc. The reason
				// is that the cfc may have defined relationships and/or other custom properties that would be lost if using the generic Norm
				// entity to load the new instance.
				try{
					var cfcName = len( trim( cfc ) )
											? cfc
											: listDeleteAt( variables.meta.fullName, listLen( variables.meta.fullName, '.' ), '.' ) & '.' & uCase(left(table,1)) & lCase(mid(table,2,len(table)));
					logIt('newObj : initializing #cfcName# [#table# instead of #getComponentMetadata( cfcName ).table#] ---- #listDeleteAt( variables.meta.fullName, listLen( variables.meta.fullName, '.' ), '.' ) & '.' & table#');
					newEntity = new "#cfcName#"( argumentCollection:arguments );
				}catch( any e ){
					logIt('newObj : initializing #cfcName# FAILED #e.message#');
					newEntity = new Norm( argumentCollection:arguments );
				}
			}
		}
		newEntity._setIsNew( true );
		// Cache the empty instance for later retrieval
		if( get__cacheEntities() ){
			cfthread( action = "run", name = createUUID() & "-" & table, cacheName = cacheName, newEntity = newEntity ){
				cachePut( cacheName, newEntity );
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
	public void function $reset(){
		// Could just load(0), but properties dynamically added will persist in the variables scope
		// and the variables.properties is readonly.
		/*for ( var prop in variables.meta.properties ){
			this[ prop.name ] = variables[ prop.name ] = '';
		}*/
		this.load(0);
	}

	/**
	* A convenience method for loading an object with pre-existing data.
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
		var tmpEntity = load( ID = properties, lazy = lazy, dirty = true );
		
		// If this entity was loaded via populate, we'll assume it's dirty data
		tmpEntity._setIsDirty( true );

		return tmpEntity;
	}

	/**
	* A convenience method to force the lazy loading of the entity.  I make code
	* more self-documenting.
	**/
	public any function lazyLoad( required any ID, string parentTable = getParentTable() ){
		return load( ID = ID, lazy = true, parenTable = parentTable );
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
	public any function load( required any ID, boolean lazy = true, string parentTable = getParentTable() ){
		var props = variables.keyExists( 'meta' ) ? variables.meta.properties : _getMetaData();
		// Fire the beforeLoad the event handler
		logIt( 'Executing beforeLoad event for #getTable()#' );
		if( isNull( this.beforeLoad ) ){
			beforeLoad( this );
		}else{
			this.beforeLoad( this );
		}
		// If the ID was a simple value, chances are we may have the object already cached, let's try to load it.
		// Typically we'd only use a short lived cache to help resolve circular dependancies and loading the same
		// object multiple times in quick succession.  However, the cachedWithin property can be altered to extend
		// the chache's life as long as you'd like.  Note that the cached object is only updated when relationships
		// are added via hasMany or belongsTo, or the entity is persisted to the database (.save() is called )

		if( isSimpleValue( ID ) && len( trim( ID ) ) && !!val(get__cacheEntities()) ){
			// Load from cache if we've got it
			// cacheremove( '#this.getTable()#-#ID#' );
			lock type="readonly" name="#this.getDao().getDsn()#-#this.getTable()#-#ID#" timeout="3"{
				var cachedObject = cacheGet( '#this.getDao().getDsn()#-#this.getTable()#-#ID#' );
			}
			logIt('Loaded #this.getTable()#-#ID# from cache');
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
				// cachedObject will just return the metadata of Norm, and not the instantiated object's
				// injected properties )

				for( var prop in cachedObject ){
					if(!isCustomFunction( cachedObject[prop] ) && prop != "METHODS" ){
						var mapping = _getMapping( prop );
						var cachedPropName = structKeyExists( cachedObject, mapping.property ) ? mapping.property : prop;

						this[ mapping.property ] = cachedObject[ cachedPropName ];
						variables[ mapping.property ] = cachedObject[ cachedPropName ];
						cachedObject[ mapping.property ] = cachedObject[ cachedPropName ];
						logIt('Pumping #prop# into the object from cache...');
						var newProp = {
								'table': mapping.table,
								'name': mapping.property,
								'column': mapping.property,
								'type': isObject( cachedObject[ cachedPropName ] ) ? "object" : "string"
						};
						if( structKeyExists( mapping, 'cfc' ) ){
							newProp['cfc'] = mapping.cfc;
						}
						if( !structIsEmpty( newProp ) ){
							// arrayAppend( variables.meta.properties, newProp );
							_injectProperty( name = mapping.property, val = cachedObject[ cachedPropName ] , prop = newProp );
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
					// Save the pristine state of this entity instance
					lock name="#this.getTable()#-#ID#-pristine" type="exclusive" timeout="3"{
						variables._pristine = cachedObject;
					}
					// Fire the afterLoad the event handler
					logIt( 'Executing afterLoad event for #getTable()#' );
					afterLoad();
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
				this.load( ID = arguments.ID[ getIDField() ], lazy = lazy );
			}
			// Load the object based on the pased in struct. This may be a new record, or an update to an existing one.
			for ( var prop in props ){
				//Load the properties based on the passed in struct.
				if ( listFindNoCase( structKeyList( arguments.ID ), prop.name ) ){
					param prop.type = "";
					// We'll need to check some data types first though.
					if ( prop.type == 'date' && findNoCase( 'Z', arguments.ID[ prop.name ] ) ){
						variables[ prop.name ] = this[ prop.name ] = convertHttpDate( arguments.ID[ prop.name ] );
					}else{
						variables[ prop.name ] = this[ prop.name ] = arguments.ID[ prop.name ];
					}
				}
			}

			if ( structKeyExists( arguments.ID, getIDField() ) && !this.isNew() ){
				// If loading an existing entity, we can short-circuit the rest of this method since we've already loaded the entity
				// First let's put this guy in our cache for faster retrieval.
				if( get__cacheEntities() ){
					lock type="exclusive" name="#this.getDao().getDsn()#-#this.getTable()#-#this.getID()#" timeout="3"{
						cachePut( '#this.getDao().getDsn()#-#this.getTable()#-#this.getID()#', this, getcachedWithin() );
					}
				}
				// Save the pristine state of this entity instance
				lock name="#this.getTable()#-#this.getID()#-pristine" type="exclusive" timeout="3"{
					variables._pristine = structCopy( this );
				}
				// Fire the afterLoad the event handler
				logIt( 'Executing afterLoad event for #getTable()#' );
				afterLoad();
				return this;
			}
		}else{
			if ( isQuery( arguments.ID ) ){
				var record = arguments.ID;
			}else{
				var record = this.getRecord( ID = arguments.ID );
			}
			for ( var fld in listToArray( record.columnList ) ){
				try{
					this[ fld ] = record[ fld ][ 1 ];
					variables[ fld ] = record[ fld ][ 1 ];
					if( validateProperty( fld, record[ fld ][ 1 ] ).valid  ){
						this.onMissingMethod( 'set#fld#', { 1:record[ fld ][ 1 ] } );
					}

				}catch( any e ){
					// Setter failed, probably invalid type or something not caught by validateProperty.
					// bypass setter and move on already.
					this[ fld ] = record[ fld ][ 1 ];
					variables[ fld ] = record[ fld ][ 1 ];
				}
				this._setIsDirty( false );
			}
		}
		/*  Now iterate the properties and see if there are any relationships we can resolve */
		// if( structKeyExists(arguments, 'blue')){
		// 	writeDump([props,arguments]);abort;
		// }
		for ( var col in props ){
			col.column = structKeyExists( col,'column' ) ? col.column : col.name;
			logIt( 'Checking for child properties for: ' & col.name );
			if( arrayFindNoCase( variables.meta.privateKeys, col.name )
					|| arrayFindNoCase( getExcludedEntities(), getTable() )
					|| ( structKeyExists( col, 'norm_persistent' ) && col.norm_persistent == false ) ){
				logIt('No need to autowire #getTable()#.#col.name#.  Skipping.');
				continue;
			}
			// writeLog( this.getTable() & " : " &  col.column );
			var tmpChildObj = false;
			// Dynamically load one to many relationships by convention.  This will check to see if the current property
			// ends with _ID, and does not have a cfc associated with it. If both of those statements are true we'll try
			// to load the child table via Norm.
			var regex = reReplaceNoCase( getDynamicMappingFKConvention(), '(.*?){table}(.*)', '^\1(\w*?)\2$', 'all' );
			// var regexMatch = reMatch( regex, structKeyExists( col, 'column' ) ? col.column : col.name );
			var regexMatch = reMatch( regex, col.column );
			if( ( !structKeyExists( col, 'cfc' )
				&& ( arrayLen( regexMatch ) // If we found a field name with tihs signature, let's add the mapping
					|| structKeyExists( getDynamicMappings(), col.name )
					|| structKeyExists( getDynamicMappings(), col.column ) ) )
				&& getAutoWire() ){
				// We have a field ending with _ID, which typically indicates a "foriegn key" property to a tabled named whatever prefixes the _ID
				// Using this convention, if the parent table is "orders" and the field name is "orders_ID" we can load the parent
				// writeLog( col.name & " has no cfc but looks like a entity relationship");

				try{
					// Resolve any dynamic mappings
					var mapping = _getMapping( ( structKeyExists( col, 'table' ) && len( trim( col.table ) ) ) ? col.table : col.name );
					// set the table to the mapped table, or the column name
					var table = var property = structKeyExists( getDynamicMappings(), col.name )
												|| ( structKeyExists( col, 'singularName' ) && structKeyExists( getDynamicMappings(), col.singularName ) )
												? mapping.table
												: listDeleteAt( col.name, listLen( col.name, '_' ), '_' );
					if( table == "" ){
						mapping = _getMapping( col.column );
						table = property = len( trim( mapping.table ) ) ? mapping.table : col.name;
						if( table == "" ){
							table = property = listDeleteAt( col.column, listLen( col.column, '_' ), '_' );
						}
					}
					var key = structKeyExists( mapping, 'key' ) ? mapping.key : property;
					// writeLog("key : #key#, table : #table#");
					// If this is a field that ends with _ID, and col.name didn't
					// exist we will fall back on the col.column property.
					if( !arrayLen( regexMatch )
						&& !structKeyExists( getDynamicMappings(), col.name )
						&& structKeyExists( getDynamicMappings(), col.column ) ){
						// Resolve any dynamic mappings for col.column
						mapping = _getMapping( col.column );
						table = mapping.table;
						property = mapping.property;
						key = mapping.key;
						// table = structKeyExists( getDynamicMappings(), col.column ) ? mapping.table : table;
						logIt( "Does col.column: #col.column# have a dynamicMappings? #structKeyExists( getDynamicMappings(), col.column )#" );
					}
					// skip if table is in excludedEntities
					if( arrayFindNoCase( getExcludedEntities(), table ) ) continue;

					if( table != "" && parentTable != table && structKeyExists( mapping, 'IDField' ) ){
						// If the above mapping attempts returned a map without an IDField that means we couldn't find a parent entity to tie to so we'll skip this.
						logIt('[#parentTable#] [#table#] :#col.name#: dynamic #structKeyExists(col, "dynamic") ? col.dynamic : 'false'# -- #getFunctionCalledName()#');
						// wire up the relationship
						// CF10+/Railo4+ way:
						var tableDef = _loadTableDef( table );
						logIt('is #table# a table? #tableDef.getIsTable()#');
						if( tableDef.getIsTable() ){
							if(!structKeyExists(col,'fkcolumn')){
								col[ "fkcolumn" ] = col.column;
							}
							// lazy = true;
							if( !lazy ){
								logIt('injecting closure to immediately load related entity for #table#/#property# with an id of #this[ mapping.key ]#: parent table #parentTable#');
								variables[table] = this[table] =
								variables[property] = this[property] = _getManyToOne(
																				 table = lcase( table )
																				,property = property
																				,fkColumn = mapping.key
																				,pkColumn = mapping.IDField
																				,fkValue = this[ col.fkcolumn ]
																			);
							}else{
								logIt('injecting closure to lazy load related entity for #table#/#property#');
								variables[table] = this[table] =
								variables[property] = this[property] =
								variables[ "get" & table ] = this[ "get" & table ] =
								variables[ "get" & property ] = this[ "get" & property ] = _closure_getManyToOne(
																								 table = lcase( table )
																								,property = property
																								,pkColumn = mapping.key
																								,fkColumn = mapping.IDField
																								,fkValue = this[ col.fkcolumn ]
																							);
							}
						}
						// CF9 Way
						// tmpChildObj = _getManyToOne( table = lcase( table ), property = property, fkColumn = structKeyExists( col, 'column' ) ? col.column : col.name, pkColumn = mapping.IDField );
						// // If a table matches the table, a relationship was found and tmpChildObj would be an object, otherwise it would have returned
						// // false.  We only need to inject it if it was an object.
						// if( isObject( tmpChildObj ) ){
						// 	variables[ table ] = this[ table ] = tmpChildObj;
						// 	variables[ property ] = this[ property ] = tmpChildObj;
						// }
					// }else{
					// 	writeLog("relationships not found for #table#");
					}
				} catch ( any e ){

					if( e.type != 'NORM' ){
						// throw(e.detail);
						/*writeDump([e]);abort;*/
						rethrow;
					}
				}
			}

			// Load all child objects
			if( structKeyExists( col, 'cfc' ) ){
				logIt("_save " & col.name & ' has cfc definition #structKeyExists( col, 'table' ) ? col.table : getComponentMetadata( col.cfc ).table# :: #getComponentMetadata( col.cfc )?.table?:""#');
				var childMeta = getComponentMetadata( col.cfc );
				var tmp = new "#col.cfc#"(
						table = structKeyExists( childMeta, 'table' ) ? table : structKeyExists( col, 'table' ) ? col.table : col.name,
						dao = this.getDao(),
						dropcreate = this.getDropCreate(),
						dynamicMappings = getDynamicMappings(),
						dynamicMappingFKConvention = getDynamicMappingFKConvention(),
						excludedEntities = getExcludedEntities(),
						autoWire = getAutoWire(),
						lazy = lazy
					);

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
					&& ( structKeyExists( col, 'cfc' ) && col.cfc != 'Norm' ) ){
					// load child records here....
					col.fkcolumn = structKeyExists( col, 'fkcolumn' ) ? col.fkcolumn : col.name & this.getIDField();
					col.inverseJoinColumn = structKeyExists( col, 'inverseJoinColumn' ) ? col.inverseJoinColumn : this.getIDField();
					var colName = col.name;

					logIt('is loading onetomany for #getComponentMetadata( col.cfc ).table#');
					var tmpFunc = this[ "get" & col.name ] =
						variables[ "get" & col.name ] = _closure_getOneToMany(
							table = getComponentMetadata( col.cfc ).table,
							property = col.name,
							pkColumn = this.getIDField(),
							fkColumn = col.fkColumn,
							pkValue = this[ col.inverseJoinColumn ],
							where = childWhere,
							cfc = col.cfc
						);
					logIt('is done loading onetomany for #getComponentMetadata( col.cfc ).table#');
					// If lazy == false we will aggressively load all child entities (this is expensive, so use sparingly)
					if( !lazy ){
						this[ col.name ] = variables[ col.name ] = tmpFunc();
						logIt('is done loading onetomany for #getComponentMetadata( col.cfc ).table#');

					//If lazy == true, we will just overload the "getter" method with an anonymous method that will instantiate the child entity when called.
					}else{
						//
						// CF10+/Railo4+ way
						this[ col.name ] = variables[ col.name ] = tmpFunc;
						// CF9 Way
						// setterFunc( evaluate("tmp.lazyLoadAllBy#col.fkcolumn#( this.get#col.inverseJoinColumn#(), childWhere )") );
					}
				}else if( structKeyExists( col, 'fieldType' )
					&& col.fieldType == 'many-to-one'
					&& ( structKeyExists( col, 'cfc' ) && col.cfc != 'Norm' ) ){
					// load child records here....
					col.fkcolumn = structKeyExists( col, 'fkcolumn' ) ? col.fkcolumn : col.name & this.getIDField();
					col.inverseJoinColumn = structKeyExists( col, 'inverseJoinColumn' ) ? col.inverseJoinColumn : this.getIDField();
					var colName = col.name;

					logIt('is loading many to one for #getComponentMetadata( col.cfc ).table#');
					this[ col.name ] = variables[ col.name ] = tmp.load( id = this[ col.fkcolumn ], lazy = lazy );
					// writeDump([col,this[ col.fkcolumn ], tmp ]);abort;

				}else if( structKeyExists( col, 'fieldType' ) && col.fieldType eq 'one-to-one' && structKeyExists( col, 'cfc' ) ){
					col.fkcolumn = structKeyExists( col, 'fkcolumn' ) ? col.fkcolumn : col.name & this.getIDField();
					if( !lazy ){
						logIt('aggressively loading one-to-one object: #col.cfc# [#col.name#]');
						setterFunc( tmp.load( id = structKeyExists( variables, col.fkcolumn ) ? variables[ col.fkcolumn ] : 0, lazy = lazy ) );
					}else{
						setterFunc( function(){
							return tmp.load( structKeyExists( col, 'fkcolumn' ) && structKeyExists( variables, col.fkcolumn )
												? variables[ col.fkcolumn ]
												: 0
											);
						});
					}
				}
			}
		}

		if( isSimpleValue( ID ) && !this.isNew() && get__cacheEntities() ){
			// Now cache this thing.  The next time we need to call it (within the cachedwithin timespan) we can just pull it from memory.
			lock type="exclusive" name="#this.getDao().getDsn()#-#this.getTable()#-#this.getID()#" timeout="3"{
				if( get__cacheEntities() ) cachePut( '#this.getDao().getDsn()#-#this.getTable()#-#this.getID()#', this, getcachedWithin() );
			}
		}
		// Save the pristine state of this entity instance
		// KNOWN ISSUE:
		// duplicate() is very, very expensive and in this case can easily
		// cause out of mem errors (seems to have a mem leak on at least lucee 4.5).
		// Though the below doesn't really create a deep pristine copy, which is what we want, it will serve
		// the purposes of comparing for changes at the top level as structCopy will copy by val the top
		// level keys/values, then by ref on everything beyond that.
		try{
			// From time-to-time this errors with a NullPointerException.  Not sure why...
			variables._pristine = structCopy( this );
		}catch(any e){}
		// variables._pristine = duplicate( this );
		// Fire the afterLoad the event handler
		logIt( 'Executing afterLoad event for #getTable()#' );
		if( isNull( this.afterLoad ) ){
			afterLoad( this );
		}else{
			this.afterLoad( this );
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
	* Inspects the given column and attempts to determine if it is a foriegn
	* key to a child entity (based on dynamicMappingFKConvention.  If so,
	* it adds that entity definition to the child mappings.
	**/
	private function resolveChildEntity( required string column ){
		return;
		var children = getChildEntities();
		// only need to do this once per entity
		for( var child in children ){
			if( child.name == column ){
				return;
			}
		}

		var regex = reReplaceNoCase( getDynamicMappingFKConvention(), '(.*?){table}(.*)', '^\1(\w*?)\2$', 'all' );
		// If we found a field name with tihs signature, let's add the mapping
		if( arrayLen( reMatch( regex, column ) ) ){
			logIt('Found Dynamic Mapping FK naming convention match "#field#" for entity #table#.');
			var childTable = reReplaceNoCase( column, regex, '\1', 'all' );
			if( len( trim( childTable ) ) ){
				var childTableDef = _loadTableDef( childTable );
				// only add the mapping if it is to a real table
				logIt('...is #childTable# a table? #childTableDef.getIsTable()#');
				if( childTableDef.getIsTable() ){
					childTable = childTableDef.getTableName();
					var mapping = _getMapping( childTable );
					logIt('#childTable# with a pk col: #childTableDef.getPrimaryKeyColumn()#');
					registerChildEntity( { name = mapping.property, table = mapping.table, type = "one-to-many", childIDField = column, parentIDField = childTableDef.getPrimaryKeyColumn() } );
				}
			}
		}

	}
	/**
	* Returns an array of any child entities related to (and loaded into) the current entity.
	**/
	public array function getChildEntities(){
		return variables._children;
	}

	public function registerChildEntity( struct definition ){
		logIt('***Registering Child Entity: #definition.name# for parent #this.getTable()#');
		arrayAppend( variables._children, definition );
	}

	public function getPotentialFKColumnName( required string table ){
		return reReplaceNoCase( getDynamicMappingFKConvention(), '{table}', table, 'all' );
	}
	/**
	* Loads One-To-Many relationships into the current entity
	* Example: On an Order entity you have multiple OrderItems
	**/
	private any function _getOneToMany(
								 required string table
								,any pkValue = getID()
								,string property = arguments.table
								,string fkColumn = ""
								,string returnType = "object"
								,string where = ""
								,boolean returnFirst = false
								,string cfc = ""
							){
		if( arrayFindNoCase( getExcludedEntities(), table ) ){
			return pkValue;
		}
		var mapping = _getMapping( table );
		var propertyName = property == table ? mapping.property : property;
		fkColumn = mapping?.idField?:getPotentialFKColumnName( getTable() );
		var childCFC = cfc;
		// try{
			// try to load the table into a new object.  If the table doesn't
			// exist we'll just return void;
			logIt( 'newObj being initalized for #mapping.table#... ' );
			if( !len( trim( childCFC ) ) ){
				for( var prop in variables.meta.properties ){
					if( prop.name == mapping.table || ( structKeyExists( prop, 'singularName' ) && prop.singularName == mapping.table ) ){
						childCFC = structKeyExists( prop, 'cfc' ) ? prop.cfc : '';
						singularName = structKeyExists( prop, 'singularName' ) ? prop.singularName : prop.name;
						logIt( 'newObj for #childCFC#... ' );
						break;
					}
				}
			}
		logIt( 'newObj for table: #mapping.table#, cfc #childCFC#... ' );
		var newObj = $new( table = mapping.table, dao = this.getDao(), cfc = childCFC );
		logIt( 'newObj created for table: #newObj.getTable()#, cfc #childCFC#... ' );
		// }catch( any e ){
		// 	throw( message = "Table #propertyName# does not exist", type="NORM", detail="Table #propertyName# does not exist in #getDao().getDSN()#");
		// 	writeDump([arguments,mapping]);abort;
		// 	// writeDump([arguments,e,this]);abort;
		// 	// return variables[ propertyName ];
		// }
		if( !isObject( newObj ) ){
			throw( message = "Table #propertyName# does not exist", type="NORM", detail="Table #propertyName# does not exist in #getDao().getDSN()#");
			// writeDump([mapping, variables[ propertyName ], arguments,newObj,this]);abort;
			// return variables[ propertyName ];
			// return false;
		}

		newObj.setTable( isNull( mapping.name ) ? mapping.table : mapping.name );
		newObj.setParentTable( mapping.table );

		// Append the relationship propertyName to the meta properties
		var newProp = {
						"column": propertyName,
						"name": propertyName,
						"dynamic": true,
						"cfc": len( trim( childCFC ) ) ? childCFC : "Norm",
						"table":  newObj.getTable(),
						"fkcolumn": fkColumn,
						"fieldType": "one-to-many"
					};
		if( !isNull( singularName ) ){
			newProp["singularName"] = singularName;
		}
		// arrayAppend(variables.meta.properties, newProp );
		_injectProperty( name = propertyName, val = newObj, prop = newProp );
		logIt('adding adders/getters/setters for #propertyName#');
		if( !structKeyExists( this, "add" & propertyName ) ){
			this[ "add" & propertyName ] = variables[ "add" & propertyName ] = _adder;
		}
		if( !structKeyExists( this, "set" & propertyName ) ){
			this[ "set" & propertyName ] = variables[ "set" & propertyName ] = _setter;
		}
		if( !structKeyExists( this, "remove" & propertyName ) ){
			this[ "remove" & propertyName ] = variables[ "remove" & propertyName ] = _remover;
		}
		if( !structKeyExists( this, "get" & propertyName ) ){
			this[ "get" & propertyName ] = variables[ "get" & propertyName ] = _getter;
		}
		if( !structKeyExists( this, "has" & propertyName ) ){
			this[ "has" & propertyName ] = _has;
		}

		this.registerChildEntity( { name = propertyName, table = mapping.table, type = "one-to-many", childIDField = fkColumn, parentIDField = getIDField() } );
		// Update Cache
		if( get__cacheEntities() ){
			lock type="exclusive" name="#this.getDao().getDsn()#-#this.getTable()#-#this.getID()#" timeout="3"{
				if( get__cacheEntities() ) cachePut( '#this.getDao().getDsn()#-#this.getTable()#-#this.getID()#', this, getcachedWithin() );
			}
		}
		logIt("newobject table: #newObj.getTable()#");
		logIt('Loading dynamic one-to-many relationship entity #table# with #fkcolumn# of #pkValue# - parent #this.getTable()# [#newObj.getParentTable()#]');
		if( table == getTable() || returnType == "array" || returnType == "struct" || returnType == "json" ){
			this[ propertyName ] = variables[ propertyName ] = newObj.onMissingMethod( 'lazyLoadAllBy#fkColumn#As#returnType#', {1:pkValue, 2:where} );
			return isArray( this[ propertyName ] ) ? this[ propertyName ] : [this[ propertyName ]];

		}else{
			// Return an array of child objects.
			if( !val( pkValue ) ){
				// No pkValue, which probably means this is a new record not yet persisted.  Return an empty array
				this[ propertyName ] = variables[ propertyName ] = [];
				return [];
			}
			logIt('newObj.lazyLoadAllBy#fkColumn#(#pkValue#,''#where#'')');
			this[ propertyName ] = variables[ propertyName ] = newObj.onMissingMethod( 'lazyLoadAllBy#fkColumn#',  {1:pkValue, 2:where}  );
			logIt('done with newObj.lazyLoadAllBy#fkColumn#(#pkValue#,''#where#'')');
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

	private function _closure_getOneToMany( table, property = table, fkColumn, pkColumn, pkValue, where, cfc ){
		return function(){
			logIt( "_save Calling _getOneToMany from inside closure- #table# #property# #fkColumn# #pkColumn# #pkValue#");
			return _getOneToMany( table = lcase( table ), property = property, fkColumn = fkColumn, pkColumn = pkColumn, pkValue = pkValue, where = where, cfc = cfc );
		};
	}
	private function _closure_getManyToOne( table, property = table, fkColumn, pkColumn, fkValue ){
		return function(){
			logIt( "Calling _getManyToOne from inside closure- #table# #property# #fkColumn# #pkColumn# #fkValue#" );
			return _getManyToOne( table = lcase( table ), property = property, fkColumn = fkColumn, pkColumn = pkColumn, fkValue = fkValue );
		};
	}

	/**
	* Tells NORM about one-to-many relationships.  This is needed if the column names don't follow convention (and are not mapped via dynamicMappings)
	* Example: order = new Norm( table = "orders", dao = dao );
	* 		   order.load(123);
	* 		   order.hasMany( table = "order_items", fkColumn = "orders_ID", property = "OrderItem" );
	* 		^^ Assumes table order_items has a column named orders_ID, which points to the PK column in orders.
	**/
	public any function hasMany(
			 required string table
			,string fkColumn = getIDField()
			,string property = arguments.table
			,string returnType = "object"
			,string where = ""
		){
		var tableDef = _loadTableDef( table );
		logIt('is #table# a table? #tableDef.getIsTable()#');
		if( !tableDef.getIsTable() ){
			return false;
		}
		// passed in table was actually a table, now map it.
		var mapping = {
			'table': table,
			'property':property,
			'key': fkColumn,
			'IDField': fkColumn,
			'tableDef': tableDef,
			'addedBy': 'hasMany'
		};
		logIt('added generic mapping for table #table#: #structKeyList( mapping )# [ key:#fkColumn#, IDField:#getIdField()#]');
		addDynamicMappings( table, mapping );
		
		if( get__cacheEntities() ){
			lock type="readonly" name="#this.getDao().getDsn()#-#this.getTable()#-#this.getID()#" timeout="3"{
				var cachedObject = cacheGet( '#this.getDao().getDsn()#-#this.getTable()#-#this.getID()#' );
			}
			if( !isNull( cachedObject ) ){
				return cachedObject;
			}
		}
		variables[ property ] = this[ property ] = _getOneToMany(
														 table = lcase( table )
														,property = property
														,pkValue = getID()
														,fkColumn = fkColumn
														,returnType = returnType
														,where = where
													);

		// Update Cache
		if( get__cacheEntities() ){
			lock type="exclusive" name="#this.getDao().getDsn()#-#this.getTable()#-#this.getID()#" timeout="3"{
				cachePut( '#this.getDao().getDsn()#-#this.getTable()#-#this.getID()#', this, getcachedWithin() );
			}
		}
		return this;
	}

	/**
	* Loads Many-To-One relationships into the current entity
	* Example: Many OrderItems entities belong to the same Order
	**/
	private any function _getManyToOne(
			 required string table
			,required string fkColumn
			,string pkColumn = getIDField()
			,string property = arguments.table
			,string returnType = "object"
			,string where = ""
			,any fkValue
		){
		if( arrayFindNoCase( getExcludedEntities(), table ) ){
			return fkValue;
		}
		if( !structKeyExists( variables, fkColumn) ){
			throw( message = "Unknown Foreign Key Property", type="NORM", detail="The Foreign Key: #fkColumn# did not exist in #table#.");
		}

		var tableDef = _loadTableDef( table );
		logIt('is #table# a table? #tableDef.getIsTable()#');
		if( !tableDef.getIsTable() ){
			return false;
		}
		var mapping = _getMapping( arguments.table );
		var propertyName = structKeyExists( getDynamicMappings(), arguments.property )
												? getDynamicMappings()[ arguments.property ]
												: arguments.property;
		if( !isSimpleValue( propertyName ) ){
			propertyName = structKeyExists( propertyName, 'property' )
											? propertyname[ 'property' ]
											: arguments.property;
		}
		fkValue = isNull( fkvalue ) ? get( fkColumn ) : fkValue;
		// Set the fkValue to the fkColumn value if fkValue wasn't supplied or is empty
		if( isNull( fkValue ) || !len( trim( fkValue ) ) ){
			fkValue = this[fkColumn];
		}
		// Reverse lookup for an alias name in the dynamicMappings.  This is used in case the load() method
		// is auto-wiring relationships and doesn't know that a column has a mapping.
		if( propertyName == arguments.table && arrayLen( structFindValue( getDynamicMappings(), mapping.table ) ) ){
			var findKey = structFindValue( getDynamicMappings(), mapping.table )[1].key;
			if( findKey != "table" ){
				propertyName = structKeyExists( getDynamicMappings(), findKey ) ? getDynamicMappings()[ findKey ] : arguments.table;
				if( isStruct( propertyName ) ){
					propertyName = propertyName[ "name" ];
				}
			}
		}

		this[ "set" & propertyName ] = variables[ "set" & propertyName ] = _setter;
		this[ "get" & propertyName ] = variables[ "get" & propertyName ] = _getter;

		this.registerChildEntity( { 'name': propertyName, 'table': lcase( mapping.table ), 'type': "many-to-one", 'parentIDField': arguments.fkColumn, 'childIDField': pkColumn } );

		if( !isSimpleValue(fkValue) ){
			logIt('Value for #table# : #mapping.table# [#property#] was alread an object');
			var newObj = fkValue;
			fkValue = newObj.getID();
		}else{
			var newObj = $new( table = mapping.table, dao = this.getDao(), idField = mapping.idField, parentTable = this.getTable() );
		}

		if( !isObject( newObj ) ){
			return newObj;
		}
		newObj.setTable( mapping.table );

		// Load data into new object
		logIt('Loading dynamic many-to-one relationship entity #table#[#mapping.table#] [from #getFunctionCalledName()#] with id (#fkColumn#) of #isSimpleValue( this[fkColumn] ) ? this[fkColumn] : 'complex object'# || #fkValue#. Lazy? #yesNoFormat(getParentTable() eq mapping.table)#');
		if( len( trim( fkValue ) ) ){
			newObj.load( ID = fkValue, lazy = true, where = where, parentTable = this.getTable() );
		}

		logIt('Well, was there anything to load?: #yesNoFormat( !newObj.isNew() )#');
		// Now set the relationhsip property value to the newly created and instantiated object.
		variables[ propertyName ] = this[ propertyName ] = variables.properties[ propertyName ] = this.properties[ propertyName ] = newObj;

		// Append the relationship propertyName to the meta properties (if not already there.)
		// arrayAppend( variables.meta.properties, {
		// 					"column": propertyName,
		// 					"name": propertyName,
		// 					"dynamic": true,
		// 					"cfc": "Norm",
		// 					"table": newObj.getTable(),
		// 					"inverseJoinColumn": newObj.getIDField(),
		// 					"fkcolumn": fkColumn,
		// 					"fieldType": "many-to-one",
		// 					"addedBy": "_getManyToOne:#getFunctionCalledName()#"
		// 				} );
		_injectProperty( name = propertyName, val = newObj, prop = {
							"column": propertyName,
							"name": propertyName,
							"dynamic": true,
							"cfc": "Norm",
							"table": newObj.getTable(),
							"inverseJoinColumn": newObj.getIDField(),
							"fkcolumn": fkColumn,
							"fieldType": "many-to-one",
							"addedBy": "_getManyToOne:#getFunctionCalledName()#"
						} );

		// Update Cache
		if( get__cacheEntities()  ){
		lock type="exclusive" name="#this.getDao().getDsn()#-#this.getTable()#-#this.getID()#" timeout="3"{
			cachePut( '#this.getDao().getDsn()#-#newObj.getTable()#-#newObj.getID()#', newObj, getcachedWithin() );
			cachePut( '#this.getDao().getDsn()#-#this.getTable()#-#this.getID()#', this, getcachedWithin() );
		}
		}
		if( returnType is "struct" || returnType is "array" ){
			return newObj.toStruct();
		}else if( returnType is "json" ){
			return newObj.toJSON();
		}

		return newObj;
	}

	public any function belongsTo(
			 required string table
			,string fkColumn = getPotentialFKColumnName( arguments.table )
			,string property = arguments.table
			,string pkColumn = getIDField()
			,string returnType = "object"
			,string where = ""
	){
		// passed in table was actually a table, now map it.
		var mapping = {
			'table': table,
			'property':property,
			'key': fkColumn,
			'IDField': pkColumn,
			'tableDef': tableDef,
			'addedBy': 'hasMany'
		};
		logIt('added generic mapping for table #table#: #structKeyList( mapping )#');
		addDynamicMappings( table, mapping );

		if( !this.isNew() ){
			variables[ property ] = this[ property ] = _getManyToOne(
																table = lcase( arguments.table ),
																fkColumn = arguments.fkColumn,
																fkValue = get(arguments.fkColumn),
																property = arguments.property,
																pkColumn = arguments.pkColumn,
																returnType = arguments.returnType,
																where = arguments.where
														);
		}else{
			variables[table] = this[table] =
			variables[property] = this[property] =
			variables[ "get" & table ] = this[ "get" & table ] =
			variables[ "get" & property ] = this[ "get" & property ] = _closure_getManyToOne(
																			table = lcase( arguments.table ),
																			fkColumn = arguments.fkColumn,
																			fkValue = get(arguments.fkColumn),
																			property = arguments.property,
																			pkColumn = arguments.pkColumn,
																			returnType = arguments.returnType,
																			where = arguments.where
																		);
		}
		this[ "set" & property ] = variables[ "set" & property ] = _setter;
		// Update Cache
		// if( get__cacheEntities() ){
		// 	lock type="exclusive" name="#this.getDao().getDsn()#-#this.getTable()#-#this.getID()#" timeout="3"{
		// 		cachePut( '#this.getDao().getDsn()#-#this.getTable()#-#this.getID()#', this, getcachedWithin() );
		// 	}
		// }
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

		var tableDef = _loadTableDef( table );
			var mapping = { 'table' = table, 'property' = table, 'key' = table, 'addedBy': "tabledef" };

		if( arrayFindNoCase( getExcludedEntities(), table ) ){
			return mapping;
		}
		logIt('looking for mapping for #table#');
		if( structKeyExists( this.getDynamicMappings(), table ) ){
			mapping = this.getDynamicMappings()[ table ];
			if( !isStruct( mapping ) ){
				logIt('mapping for #table# exists but is not a struct, creating new one now');
				// mapping was not found or was not initialized
				mapping = {
					'table': tabledef.getTableName(),
					'property': mapping,
					'key': mapping,
					'IDField': tableDef.getPrimaryKeyColumn(),
					'tableDef': tableDef,
					'addedBy': 'getMapping:no mapping'
				};
			}else{
				logIt('mapping for #table# exists with keys #structKeyList( mapping )#.');
				logIt('#serializeJSOn( mapping )#');
				if( structKeyExists( mapping, 'table' ) ){
					tableDef = _loadTableDef( mapping.table );
				}
				// mapping was found, but no key found. Update with table data
				if( !structKeyExists( mapping, "key" ) ){
					logIt('mapping for #table# exists and is a struct, but didn''t have a key');
					mapping[ "table" ] = tabledef.getTableName();
					mapping[ "key" ] = mapping.property;
					mapping[ "IDField" ] = tableDef.getPrimaryKeyColumn();
				}
			}
		}else{
			logIt('mapping for #table# did not exist');
			// table was not found in the current mappings.
		  	// Let's see if the passed in table is a real table and if so create a generic mapping and return it.

			logIt('[2034] is #table# a table? #tableDef.getIsTable()#');
			if( tableDef.getIsTable() && !arrayFindNoCase( getExcludedEntities(), tableDef.getTableName() ) ){
				var propertyName = _alias( table );
				var _table = tableDef.getTableName();
				// passed in table was actually a table, now map it.
				mapping = {
					'table': _table,
					'property': propertyName,
					'key': tableDef.getPrimaryKeyColumn(),
					'IDField': tableDef.getPrimaryKeyColumn(),
					'tableDef': tableDef,
					'addedBy': 'getMapping:mapping found'
				};
				logIt('added generic mapping for table #table#: #structKeyList( mapping )#');
				addDynamicMappings( _table, mapping );

				// we can be smart and look for more dynamic mappings based on naming convention
				if( len( trim( getDynamicMappingFKConvention() ) ) ){
					logIt('Dynamic Mapping FK naming convention defined for #_table#.  Looking for matches.');
					var regex = reReplaceNoCase( getDynamicMappingFKConvention(), '(.*?){table}(.*)', '^\1(\w*?)\2$', 'all' );
					var fields = listToArray( tableDef.getColumns() );
					for( var field in fields ){
						// If we found a field name with tihs signature, let's add the mapping
						if( arrayLen( reMatch( regex, field ) ) ){
							logIt('Found Dynamic Mapping FK naming convention match "#field#" for entity #_table#.');
							var parentTable = reReplaceNoCase( field, regex, '\1', 'all' );
							if( len( trim( parentTable ) ) ){
								// _getMapping( parentTable );
								var parentTableDef = _loadTableDef( parentTable );
								parentTable = parentTableDef.getTableName();
								// only add the mapping if it is to a real table
								logIt('...is #parentTable# a table? #parentTableDef.getIsTable()#');
								if( parentTableDef.getIsTable() ){
									logIt('#parentTable# with a pk col: #parentTableDef.getPrimaryKeyColumn()#');
									var parentMapping = {
										'table': parentTable,
										'property': _alias( parentTable ),
										'key': field,
										'IDField': parentTableDef.getPrimaryKeyColumn(),
										'tableDef': parentTableDef,
										'addedBy': 'getMapping:dynamic naming convention mapping'
									};
									addDynamicMappings( field, parentMapping );
									addDynamicMappings( parentTable, parentMapping );
								}
							}
						}

					}
				}

			}else{
				// Not a table, so we'll see if the "table" argument matches any keys in the dynamic mappings.
				// This is used to find a mapping for a foriegn key to a given table.
				logIt('iterating each in "#structKeyList( getDynamicMappings())#"');
				// iterate mappings and look-up properties to find the key
				for( var map in getDynamicMappings() ){
					logIt("find mappings for #map#");

					if( isStruct( getDynamicMappings()[ map ] )
						&& structKeyExists( getDynamicMappings()[ map ], 'property' )
						&& getDynamicMappings()[ map ].property == table ){
						logIt('table that was passed in (#table#) was found as a property in a dynamic mapping.  Using that to create new mapping');
						return {
							'table': getDynamicMappings()[ map ].table,
							'property': _alias( getDynamicMappings()[ map ].property ),
							'key': map,
							'IDField': tableDef.getPrimaryKeyColumn(),
							'tableDef': tableDef,
							'addedBy': 'getMapping:not a table'
						};

					}else{
						logIt("_save could not find mappings for #table#::: #getDynamicMappingFKConvention()#");
						// we can be smart an look for more dynamic mappings based on naming convention
						if( len( trim( getDynamicMappingFKConvention() ) ) ){
							// var tableDef = _loadTableDef( table );
							logIt('----Dynamic Mapping FK naming convention defined for #table#.  Looking for matches.');
							var regex = reReplaceNoCase( getDynamicMappingFKConvention(), '(.*?){table}(.*)', '^\1(\w*?)\2$', 'all' );
							// If we found a field name with tihs signature, let's add the mapping
							if( arrayLen( reMatch( regex, table ) ) ){
								logIt('Found Dynamic Mapping FK naming convention match for entity #table#.');
								var parentTable = reReplaceNoCase( table, regex, '\1', 'all' );
								if( len( trim( parentTable ) ) ){
									// _getMapping( parentTable );
									var parentTableDef = _loadTableDef( parentTable );
									parentTable = parentTableDef.getTableName();
									// only add the mapping if it is to a real table
									logIt('...is #parentTable# a table? #parentTableDef.getIsTable()#');
									if( parentTableDef.getIsTable() ){
										logIt('#parentTable# with a pk col: #parentTableDef.getPrimaryKeyColumn()#');
										var parentMapping = {
											'table': parentTable,
											'property': _alias( parentTable ),
											'key': table,
											'IDField': parentTableDef.getPrimaryKeyColumn(),
											'tableDef': parentTableDef,
											'addedBy': 'getMapping:not a table, but naming convention'
										};
										// addDynamicMappings( field, parentMapping );
										addDynamicMappings( parentTable, parentMapping );
										mapping = parentMapping;
									}
								}
							// }else{
								logIt('---- no juice for #table#');
							}

						}
					}
				}
				logIt('mappings for #table#: #structKeyList( mapping )#: #mapping.table#, #mapping.property#');


			}
		}

		return mapping;
		// return isStruct( mapping ) ? mapping.table : mapping;
	}
	public function _alias( string property ){
		// Reverse lookup for an alias name in the dynamicMappings.
		logIt( "looking for alias #property#" );
		if( structKeyExists( variables._aliases, property ) ){
			logIt( "found #property#" );
			return variables._aliases[ property ];
		}
		var alias = structFindValue( getDynamicMappings(), property, "all" );
		logIt( "did not find #property#. digging for aliases." );
		if( arrayLen( alias ) ){
			var findKey = alias[ 1 ].key;
			property = variables._aliases[ property ] = ( !listFindNoCase( "table,key,property", findKey ) || !structKeyExists( alias[ 1 ], 'property') )
																											? listToArray( alias[ 1 ].path, '.')[1]
																											: alias[ 1 ].owner[ "property" ];
		}
		return property;
	}
	public function addDynamicMappings( required string name, required struct mapping ){
		var existingMapping = this.getDynamicMappings();
		if( !structKeyExists( existingMapping, name ) && name != getTable() ){
			mapping.addedBy = "addDynamicMappings";
			existingMapping[ name ] = mapping;
			setDynamicMappings( existingMapping );
		}
	}

	// public void function setDynamicMappings( required struct mapping ){
	// 	if( !structKeyExists( variables, '__dynamicMappings' ) ){
	// 		variables[ "__dynamicMappings" ] = {};
	// 	}
	// 	for( var map in mapping ){
	// 		var table = isSimpleValue( mapping[ map ] ) ? mapping[ map ] : mapping[ map ].table;
	// 		var property = isSimpleValue( mapping[ map ] ) ? map : mapping[ map ].property;
	// 		var tableDef = _loadTableDef( table );
	// 		var mappingArgs = { "#map#" : {
	// 				 "table" = table
	// 				,"property" = property
	// 				,"key" = tableDef.getPrimaryKeyColumn()
	// 				,"IDField" = tableDef.getPrimaryKeyColumn()
	// 				,"tableDef" = tableDef
	// 			}
	// 		};
	// 		addMapping( mappingArgs );
	// 	}
	// 	return;
	// }
	// public struct function getDynamicMappings(){
	// 	return variables.__dynamicMappings;
	// }
	// public void function addMapping( required struct mapping ){
	// 	structAppend( variables[ "__dynamicMappings" ], mapping, true );
	// 	return;
	// }
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
    // public query function get( any ID ){
    //     return getRecord( ID );
    // }

    /**
    * The 'where' argument should be the entire SQL where clause, i.e.: "where a=queryParam(b) and b = queryParam(c)"
    **/
	public any function list(
		string columns = "",
		string where,
		string limit,
		string orderby,
		string offset,
		array excludeKeys = [],
		any cachedWithin,
		string returnType = "query",
		any map,
		boolean forceLowercaseKeys = false
	){

		if( columns == "" ){
			columns = this.getDAO().getSafeColumnNames( this.getTableDef().getColumns() );
		}
		var cols = replaceList( lcase( arguments.columns ), lcase( arrayToList( arguments.excludeKeys ) ) , "" );
		cols = reReplace( cols, "\#this.getDao().getSafeIdentifierStartChar()#\#this.getDao().getSafeIdentifierEndChar()#", "", "all" );
		cols = arrayToList( listToArray( cols, ',', false ) );
		arguments.table = this.getTable();
		arguments.name = hash( createUUID() );
		arguments.columns = cols;
		var record = variables.dao.read( argumentCollection:arguments );

		return record;
	}

	/**
	* I return a JSON array of structs representing the records matching the specified criteria; one record per array indicie.
	**/
  public string function listAsJSON(
		string where = "",
		string columns = "",
		string limit = "",
		string orderby = "",
		numeric row = 0,
		string offset = "",
		array excludeKeys = [],
		any map = "",
		boolean forceLowercaseKeys = false
	){
		return serializeJSON(
							listAsArray(
								where = where,
								columns = columns,
								limit = limit,
								orderby = orderby,
								row = row,
								offset = offset,
								excludeKeys = excludeKeys,
								map = map,
								forceLowercaseKeys = forceLowercaseKeys
							)
			);
  }
  /**
  * Returns a CF array of structs representing the records matching the specified criteria; one record per array indicie.
  **/
  public array function listAsArray(
		string where = "",
		string columns = "",
		string limit = "",
		string orderby = "",
		numeric row = 0,
		string offset = "",
		array excludeKeys = [],
		any cachedWithin = "",
		any map = "",
		boolean forceLowercaseKeys = false
	){
		var ret = list(
				where = where,
				columns = columns,
				limit = limit,
				orderby = orderby,
				row = row,
				offset = offset,
				excludeKeys = excludeKeys,
				cachedWithin = cachedWithin,
				returnType = "array",
				map = map,
				forceLowercaseKeys = forceLowercaseKeys
			);

		return !!row ? ret[ 1 ] : ret;

  }

  /**
  * I return a struct representation of the object in its current state.
  **/
	public struct function toStruct( array excludeKeys = [], numeric top = 0, boolean preserveCase = true, numeric nestLevel = 1, boolean threaded = get__threaded() ){

			var arg = "";
			var LOCAL = {};
			var returnStruct = {};
			var keysToExclude = "createTableIfNotExist,__threaded,excludedKeys,__debugMode,dynamicMappings,dynamicMappingFKConvention,__fromCache,__cacheEntities,parenttable,autowire,cachedwithin,_norm_version,_norm_updated,meta,prop,arg,arguments,tmpfunc,this,dao,idfield,idfieldtype,idfieldgenerator,table,tabledef,deleteStatusCode,dropcreate,dynamicMappings,oDataBaseUri,oDataVersion,excludedEntities#ArrayToList(excludeKeys)#";
			var props = duplicate( variables.meta.properties );

			// Iterate through each property and generate a struct representation
			var tmpProps = listRemoveDuplicates( props.reduce( function( prev, cur ){
				prev = prev?:'';
				if( !listFindNoCase( keysToExclude, cur.name ) ){
					return listAppend(prev, cur.name);
				}else{
					return prev;
				}
			}));
			props = props.filter( function(prop){
				return listFindNoCase( tmpProps, prop.name );
			});
			// writeDump(props);abort;
			// writeLog("props: " & tmp);
			// writeDump(variables.meta.properties);abort;
			for ( var prop in props ){
			// for ( var propName in tmpProps ){
				// var prop = props[ propName ];
				// First thing we need to do is load any "lazy" loaded properties.  This will populate
				// the property with the correct object/data so that we can traverse it's structure and
				// produce the serialized struct
				// writeLog('prop name: #prop.name#');
				if( structKeyExists(variables, prop.name) && isClosure( variables[ prop.name ] ) ){
					var tmpRun = variables[ prop.name ];
					variables[ prop.name ] = tmpRun();
					this[ prop.name ] = variables[ prop.name ];
				}
				// Somehow empty props make their way in with MSSQL connectors... this will weed'm out.
				if( structIsEmpty( prop ) ){
					continue;
				}

				arg = preserveCase ? prop.name : lcase( prop.name );
				// If the property name is different than the table name ( i.e. relationship created using get<object>() method or
				// relationship identified in the dynamicMappings ), chances are we have the meta property
				// twice - once with the table name and once with the alias.  This will remove the table name
				// property so that the alias name will be used instead
				if( structKeyExists( prop, 'table' ) && structKeyExists( returnStruct, prop.table ) ){
					structDelete( returnStruct, prop.table );
				}

				// We will bypass internal properties, as well as any "excludeKeys" we find.
				if( !findNoCase( '$$_', arg )
					&& ( !structKeyExists( this, arg ) || ( !isCustomFunction( this[ arg ] ) && !isClosure( this[ arg ] ) ) )
					&& !listFindNoCase( keysToExclude, arg ) ){
					// arg = _alias( arg );
					// Now, append the property to the struct we will be returning
					if( structKeyExists( variables, arg ) ){
						returnStruct[ arg ] = variables[ arg ];
					}else{
						var alias = _alias( arg );
						var mapping = _getMapping( alias );
						returnStruct[ mapping.key ] = structKeyExists( variables, mapping.key ) ? variables[ mapping.key ] : "";
						returnStruct[ mapping.property ] = structKeyExists( variables, mapping.property ) ? variables[ mapping.property ] : "";
						returnStruct[ arg ] = structKeyExists( variables, mapping.key ) ? $new( table = mapping.table ).load( variables[ mapping.key ] ) : "";
					}

					// returnStruct['__level'] = nestLevel;
					// Checking to see if the property was appended to the struct. This prevents errors that sometimes occur if the variables[ arg ] is null (i.e. returned null from Java call )
					if( structKeyExists( returnStruct, arg ) ){

						logIt('#repeatString("+", nestLevel)#tostruct #prop.name# :: #arg# :: is simple value: #isSimpleValue(returnStruct[arg])#' );
						// If it's not a simple value, we'll need to recursively call toStruct() to resolve all the nested structs.
						if( !isSimpleValue( returnStruct[ arg ] ) ){
							if(  top == 0 || nestLevel <= top ){
								if( isArray( returnStruct[ arg ] ) ){
									logIt('#repeatString(" ", nestLevel+1)#tostruct #prop.name# :: #arg# :: was an array' );
									// var newArr = returnStruct[ arg ].map( function(e){
									// 	if( isObject( e ) ){
									// 		var d = e.toStruct(
									// 						 excludeKeys = excludeKeys
									// 						,preserveCase = preserveCase
									// 						,nestLevel = nestLevel+1
									// 						,top = top
									// 					);
									// 		// d['__level'] = nestLevel+1;
									// 		return d;
									// 	}
									// 	return e;
									// });
									// returnStruct[ arg ] = newArr;
									var loopLen = arrayLen( returnStruct[ arg ] );
									if( threaded && loopLen > 0 ){
										var threads = "";
										for( var i = 1; i <= loopLen; i++ ){
											var threadName = "toStruct#createUUID()#";
											threads = listAppend( threads, threadName );
											thread name="#threadName#" action="run"
												returnStruct="#returnStruct[arg][ i ]#"
												nestLevel="#nestLevel#"
												top="#top#"
												preserveCase="#preserveCase#"
												excludeKeys="#excludeKeys#"{
												// thread.returnStruct = returnStruct;
												param name="thread.returnStruct" default="#[]#";
												if( isObject( returnStruct ) ){
													// writeLog('#repeatString(" ", nestLevel+1)#tostruct #prop.name# :: #arg# :: array item was an object' );
													returnStruct['__level'] = nestLevel+1;
													// writeLog('tostruct for #arg#: nested #nestLevel# deep');
													returnStruct = returnStruct.toStruct(
																					excludeKeys = excludeKeys,
																					preserveCase = preserveCase,
																					nestLevel = nestLevel+1,
																					top = top,
																					threaded = threaded
																				);
												}
												arrayAppend( thread.returnStruct, returnStruct );
											}
										}
										thread action="join" name="#threads#";
										if( !isNull( thread ) ){
											returnStruct[ arg ] = thread[listLast(threads)].returnStruct;
										}

									}else{
										for( var i = 1; i <= loopLen; i++ ){
											if( isObject( returnStruct[arg][ i ] ) ){
												// writeLog('#repeatString(" ", nestLevel+1)#tostruct #prop.name# :: #arg# :: array item was an object' );
												returnStruct[arg][ i ]['__level'] = nestLevel+1;
												// writeLog('tostruct for #arg#: nested #nestLevel# deep');
												if( len( trim( returnStruct[ arg ].getID() ) ) ){
													returnStruct[arg][ i ] = returnStruct[ arg ][ i ].toStruct(
																									excludeKeys = excludeKeys,
																									preserveCase = preserveCase,
																									nestLevel = nestLevel+1,
																									top = top,
																									threaded = threaded,
																									parentArg = arg,
																									parentArgId = returnStruct[ arg ][ i ].getID()
																								);
												}else{
													returnStruct[ arg ] = {};
												}
											}
										}
									}

								}else if( isObject( returnStruct[ arg ] ) ){
									logIt('#repeatString(" ", nestLevel+1)#tostruct #prop.name# :: #arg# :: was an object' );
									// returnStruct['__level'] = nestLevel;
									var col = structFindValue( variables.meta, arg );
									col = arrayLen( col ) ? col[ 1 ] : {};
									// Pull the actual column name from the metadata
									var columnName = structKeyExists( col.owner, 'column' ) ? col.owner.column : '';
									if(columnName == '' || columnName == arg ){
										columnName = structKeyExists( col.owner, 'fkcolumn' ) ? col.owner.fkcolumn : '';
									}
									// At this point it is possible that the name of the property containing the child entity
									// was used to set the FK value.  In this case, we'll use the child's table name to store that
									// data.
									param name="col.owner.table" default="#arg#";
									// Set the FK field value to the actual value (instead of the instance of the child table object )
									if( len( trim( columnName ) ) && columnName != arg){
										// If relationship was resolved via entity CFC definition (i.e. another .cfc )
										// the child property may be an array.
										returnStruct[ columnName ] = isArray( returnStruct[ arg ] ) ?
																		arrayLen( returnStruct[ arg ] ) ?
																			returnStruct[ arg ][1].getID()
																			: ''
																		: returnStruct[ arg ].getID();
									}
									// If the fk column name was the property's name we'll stuff the child data into the return struct
									// under the key named after the table.  If that is also the name of the FK column, we'll suffix it with _data.
									var tmpStruct = {};
									if( columnName == arg ){
										logIt('#repeatString(" ", nestLevel+1)#tostruct from object');
										if( len( trim( returnStruct[ arg ].getID() ) ) ){
											tmpStruct[ col.owner.table == arg ? arg & "_data" : col.owner.table ] = returnStruct[ arg ].toStruct(
																																			 excludeKeys = excludeKeys
																																			,preserveCase = preserveCase
																																			,nestLevel = nestLevel+1
																																			,top = top
																																			,threaded = threaded
																																			,parentArg = arg
																																			,parentArgId = returnStruct[ arg ].getId()
																																		);
										}else{
											tmpStruct[ col.owner.table == arg ? arg & "_data" : col.owner.table ] = {};
										}
										// prevent accidentally overwriting an existing key.
										structAppend( returnStruct, tmpStruct, false );
									}else{
										tmpTop = top;
										if( structKeyExists( arguments, 'parentArg') && parentArg eq arg ){
											if( parentArgId == returnStruct[ arg ].getID() ){
												tmpTop = 1;
											}
											// writeDump([parentArg, parentArgId, arg, returnStruct[ arg ][getIdField()], top]);abort;
										}
										if( len( trim( returnStruct[ arg ].getID() ) ) ){
											logIt('#repeatString(" ", nestLevel+1)#tostruct from object for #arg#');
											// Column name and property were not the same.  We'll still want to stuff the child data into the struct
											returnStruct[ arg ] = returnStruct[ arg ].toStruct(
																					 excludeKeys = excludeKeys
																					,preserveCase = preserveCase
																					,nestLevel = nestLevel+1
																					,top = tmpTop
																					,threaded = threaded
																					,parentArg = arg
																					,parentArgId = returnStruct[ arg ].getId()
																				);
										}else{
											returnStruct[ arg ] = {};
										}
									}
								}
							}else{
								// The argument "top" was passed in and we've hit the threshold.  This reduces the levels deep we dive into our relationships.
								// We'll translate Child entities into FK fields and then use a placeholder in place of the actual child entity.
								var col = structFindValue( variables.meta, arg );
								// Pull the actual column name from the metadata
								var columnName = arrayLen( col ) && structKeyExists( col[ 1 ].owner, 'column' ) ? col[ 1 ].owner.column : '';
								if( columnName == '' ){
									columnName = arrayLen( col ) && structKeyExists( col[ 1 ].owner, 'fkcolumn' ) ? col[ 1 ].owner.fkcolumn : '';
								}
								var tmpStruct = {};
								if( len( trim( columnName ) ) ){

									// If relationship was resolved via entity CFC definition (i.e. another .cfc ) the child property may be an array.
									returnStruct[ columnName ] = isArray( returnStruct[ arg ] ) ? arrayLen( returnStruct[ arg ] ) ? returnStruct[ arg ][1].getID() : '' : returnStruct[ arg ].getID();

								}
								param name="col[ 1 ].owner.table" default="#arg#";
								if( columnName == arg ){
									var tmpProp = col[ 1 ].owner.table == arg ? arg & "_data" : col[ 1 ].owner.table;
									tmpStruct[ tmpProp ] = tmpStruct[ _alias( col[ 1 ].owner.table ) ] = isArray( returnStruct[ arg ] )
												? '[ additional array of entities excluded due to "top=#arguments.top#" nesting limit ]'
												: '[ additional entity properties excluded due to "top=#arguments.top#" nesting limit ]';
									// prevent accidentally overwriting an existing key.
									structAppend( returnStruct, tmpStruct, true );
								}else{
									// Column name and property were not the same.  We'll still want to stuff the child data into the struct
									tmpStruct[ arg ] = tmpStruct[ _alias( arg) ] = isArray( returnStruct[ arg ] )
											? '[ additional array of entities excluded due to "top=#arguments.top#" nesting limit ]'
											: '[ additional entity properties excluded due to "top=#arguments.top#" nesting limit ]';
									// prevent accidentally overwriting an existing key.
									structAppend( returnStruct, tmpStruct, true );
								}

							}
						}else if( isNumeric( returnStruct[ arg ] )
								&& listLast( returnStruct[ arg ], '.' ) GT 0 ){
							// Since CF likes to convert our numbers to strings, let's javacast it as an int
							if( findNoCase( '.', returnStruct[ arg ] ) ){
								returnStruct[ arg ] = javaCast( 'double', returnStruct[ arg ] );
							}else if( left( returnStruct[ arg ], 1 ) != 0 ) { // protect zero-padded numbers.
								try{
									returnStruct[ arg ] = javaCast( 'int', returnStruct[ arg ] );
								}catch(any e){}
							}

						}
					}
				}
			}
		return returnStruct;
	}

	/**
    * I return a JSON representation of the object in its current state.
    **/
	public string function toJSON( array excludeKeys = [], numeric top = 0, boolean preserveCase = true ){
		try {
			return serializeJSON( this.toStruct( excludeKeys = excludeKeys, top = top, preserveCase = preserveCase ) );
		}catch( any e ){
			writeDump( [e,arguments]);abort;
		}
	}

	/**
    * I save the current state to the database. I either insert or update based on the isNew flag
    **/
	public any function save( struct overrides = {}, boolean force = false, any callback, string parentTable = "", boolean dryRun = false ){
		var tempID = this.getID();
		var callbackArgs = { ID = this.getID(), method = 'save' };

		// remove object from cache (if it exists)
		// Removing #this.getTable()#-#this.getID()# from cache
		if( get__cacheEntities() ){
			lock type="exclusive" name="#this.getTable()#-#this.getID()#" timeout="3"{
				cacheRemove( '#this.getTable()#-#this.getID()#' );
			}
		}
		logIt('::#this.getTable()# dirty? #isDirty()#');
		// Either insert or update the record
		if ( isNew() ){

			// Run beforeInsert function.  If it returns anything we'll
			// abort the insert.
			logIt( 'Executing beforeInsert event for #getTable()#' );
			if( isNull( this.beforeInsert ) ){
				if( !isNull( beforeInsert() ) ){
					logIt( 'Aborting insert due to beforeInsert' );
					return;
				}
			}else{
				if( !isNull( this.beforeInsert( this ) ) ){
					logIt( 'Aborting insert due to beforeInsert' );
					return;
				}
			}


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
					this._setIsDirty( true );
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
			logIt('Saving the children');
			_saveTheChildren( dryRun = dryRun );

			// Grab the data from the current entity.  We only need the top level keys so we'll limit to boost performance
			var DATA = duplicate( this.toStruct( top = 1 ) );
			for ( var col in DATA ){
				// the entity cfc could have a different column name than the given property name.  If the meta property "column" exists, we'll use that instead.
				var columnName = structFindValue( variables.meta, col );
				columnName = arrayLen( columnName ) && structKeyExists( columnName[ 1 ].owner, 'column' ) ? columnName[ 1 ].owner.column : col;
				if(columnName == ''){
					columnName = arrayLen( columnName ) && structKeyExists( columnName[ 1 ].owner, 'fkcolumn' ) ? columnName[ 1 ].owner.fkcolumn : '';
				}
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
					data = DATA,
					dryRun = dryRun
				);
				if( dryRun ) writeDump( newID );
			}

			callbackArgs.newID = variables['ID'] = this['ID'] = newID;
            tempID = newID;

            // This is the second pass of the child save routine.
            // This pass will pick up those one-to-many relationships and
            // persist the data with the new parent ID (this parent)
            logIt('Saving the children with the parent id of #tempID#');
			_saveTheChildren( tempID = tempID, dryRun = dryRun );

			// Run afterInsert function.
			logIt( 'Executing afterInsert event for #getTable()#' );
			if( isNull( this.afterInsert ) ){
				afterInsert( this );
			}else{
				this.afterInsert( this );
			}

		}else if( isDirty() || arguments.force ){

			callbackArgs.isNew = false;

			// Run beforeUpdate function.  If it returns anything we'll
			// abort the update.
			logIt( 'Executing beforeUpdate event for #getTable()#' );
			if( isNull( this.beforeUpdate ) ){
				if( !isNull( beforeUpdate(  variables._pristine ) ) ){
					logIt( 'Aborting update due to beforeInsert' );
					return;
				}
			}else{
				if( !isNull( this.beforeUpdate( variables._pristine, this  ) ) ){
					logIt( 'Aborting update due to beforeInsert' );
					return;
				}
			}

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
			logIt('All the Children of #parentTable#...');
			_saveTheChildren( parentTable = parentTable, dryRun = dryRun );

			logIt('All the Children saved...');
			// Grab the data from the current entity.
			var DATA = {};
			for ( var col in this ){
				// If not a simple value, it's not a data property of the entity so we can skip it
				if( !isSimpleValue( col ) ){
					continue;
				}
				// the entity cfc could have a different column name than the given property name.  If the meta property "column" exists, we'll use that instead.
				var columnName = variables.meta.findValue( col );
				columnName = columnName.len() && columnName[ 1 ].owner.keyExists( 'column' ) ? columnName[ 1 ].owner.column : col;
				if( columnName == '' ){
					columnName = columnName.len() && columnName[ 1 ].owner.keyExists( 'fkcolumn' ) ? columnName[ 1 ].owner.fkcolumn : '';
				}
				// the data could be a child struct for which we just wan the ID field.
				// DATA[ LOCAL.columnName ] = !isStruct( DATA[col] ) ? DATA[col] : DATA[col][ getIDField() ];
				if( !DATA.keyExists( LOCAL.columnName ) ){
					DATA[ LOCAL.columnName ] = get( col );
				}
			}

			callbackArgs.ID = DATA[getIDField()] = this.getID();

			if( arguments.overrides.size() > 0 ){
				for ( var override in overrides ){
					DATA[override] = overrides[override];
				}
			}

			/*** update the thing ****/
			transaction{
				var __tmpResults = variables.dao.update(
					table = this.getTable(),
					data = DATA,
					dryRun = dryRun
				);
				if( dryRun ) writeDump( __tmpResults );
			}

		}else{
			_saveTheChildren( dryRun = dryRun );
		}

		variables._isNew = false;
		// Run afterUpdate function.
		logIt( 'Executing afterUpdate event for #getTable()#' );
		if( isNull( this.afterUpdate ) ){
			afterUpdate( this );
		}else{
			this.afterUpdate( this );
		}

		this.load(ID = tempID);
		logIt('loaded new #getTable()# with ID of #tempId#');

		// Fire callback function (if provided). Could be used for AOP
		if( structKeyExists( arguments, 'callback' ) && isCustomFunction( arguments.callback ) ){
			callback( this, callbackArgs );
		}

		// Cache saved object
		if( get__cacheEntities() ){
			lock type="exclusive" name="#this.getDao().getDsn()#-#this.getTable()#-#this.getID()#" timeout="3"{
				cachePut( '#this.getDao().getDsn()#-#this.getTable()#-#this.getID()#', this, getcachedWithin() );
			}
		}

		return;
	}

	private void function _saveTheChildren( any tempID = this.getID(), string parentTable = this.getTable(), boolean dryRun = false ){
	 /* Now save any child records */
	//  logIt('_savethechildren: saving the children for #this.getTable()#:#arguments.tempID#');
		for ( var col in variables.meta.properties ){
			// Prevent circular recursion
			if( col.name == this.getTable() || col.name == parentTable ) continue;

			if( structKeyExists( col, 'fieldType' )
				&& col.fieldType eq 'one-to-many'
				&& ( structKeyExists( arguments, 'tempID' ) && len( trim( arguments.tempID ) ) )
				&& ( !structKeyExists( col, 'cascade') || col.cascade != "none" ) ){
				//**************************************************************************************************
				// ONE TO MANY.   This will iterate all child records and persist them to the back end storage (DB)
				//**************************************************************************************************
				logIt('_savethechildren: yes, a one-to-many');
				logIt('_savethechildren: Saving #arrayLen( variables[ col.name ] )# child records for #this.getTable()#:#tempID#');
				if ( !structKeyExists( variables , col.name ) || !isArray( variables[ col.name ] ) ){
					logIt('_savethechildren: nothing to do for #col.name# - #this.getTable()#:#tempID#');
					continue;
				}
				var threads = "";
				for ( var child in variables[ col.name ] ){
					logIt('_savethechildren: saving child [#child.getTable()#] record for #this.getTable()#:#tempID#');
					try{
						// Call the "set" method for the foreign key on the child object
						if( isClosure( child ) ) child = child();
						child.onMissingMethod( 'set#col.fkcolumn#', {1:tempID} );
					}catch (any e){
						writeDump(['Error in _setter',e,child, arguments, variables[ col.name ] ]);
						rethrow;
					}
					child._setIsNew( !child.getId().len() );
					// call the child's save routine;
					var threadName = "childSave#createUUID()#";
					threads = listAppend( threads, threadName );
					if( get__Threaded() ){
						thread action="run" name="#threadName#" child="#child#" dryRun="#dryRun#"{
							child.save( force = true, parentTable = this.getTable(), dryRun = dryRun );
						}
					}else{
						logIt('_savethechildren: Saving child - serial');
						child.save( force = true, parentTable = this.getTable() );
					}
					logIt('_savethechildren: DONE Saving child [#child.getTable()#] record for #this.getTable()#:#tempID#');

				}
				if( threads.listLen() && get__Threaded() ){
					thread action="join" name="#threads#";
				}

			}else if( structKeyExists( col, 'fieldType' )
				&& col.fieldType eq 'many-to-one'
				&& ( structKeyExists( arguments, 'tempID' ) && len( trim( arguments.tempID ) ) )
				&& ( !structKeyExists( col, 'cascade') || col.cascade != "none" ) ){
				logIt('_savethechildren: yes, a many-to-one');
				//**************************************************************************************************
				// MANY TO ONE.   This will and persist the child record to the back end storage (DB)
				//**************************************************************************************************
				var child = variables[ col.name ];

				logIt('child:#col.name#');
				// Only save the child object if there were changes.
				if( isObject( child ) && child.isDirty() ) {
					logIt('saving child:#col.name#');
					logIt(child.toJSON());
					child.save( parentTable = this.getTable(), force = true );
					logIt('done:saving child:#col.name#');
				}


			}else if( structKeyExists( col, 'fieldType' ) && col.fieldType eq 'one-to-one' ){
				logIt('_savethechildren: yes, a one-to-one');
				//**************************************************************************************************
				// ONE TO ONE.   This will update the parent with the child's ID and defer to the parent's save to
				// persist to the back end (DB)
				//**************************************************************************************************
				try{
					/* Set the object's FK to the value of the new parent record  */
					if( structKeyExists( variables, col.name ) ){
						var tmp = variables[col.name];
						if( isClosure( tmp ) ) tmp = tmp();
						this.onMissingMethod( 'set#col.fkcolumn#', { 1:tmp.onMissingMethod( 'get#col.inverseJoinColumn#', {} ) } );
					}

				}catch (any e){
					writeDump(['Error in _saveTheChildren',e,col,variables]);
					rethrow;
				}
			}
		}
	}

	/**
    * I delete the current record
    **/
	public void function delete( boolean soft = false, any callback ){
		var callbackArgs = { ID = getID(), method = 'delete', deletedChildren = []};
		// Run beforeDelete function.  If it returns anything we'll
		// abort the delete.
		logIt( 'Executing beforeDelete event for #getTable()#' );
		if( isNull( this.beforeDelete ) ){
			if( !isNull( beforeDelete( this ) ) ){
				logIt( 'Aborting delete due to beforeDelete' );
				return;
			}
		}else{
			if( !isNull( this.beforeDelete( this ) ) ){
				logIt( 'Aborting delete due to beforeDelete' );
				return;
			}
		}
		// Remove deleted object from cache
		if( get__cacheEntities() ){
			lock type="exclusive" name="#this.getTable()#-#this.getID()#" timeout="3"{
				cacheRemove( '#this.getTable()#-#this.getID()#' );
			}
		}

		if( len( trim( getID() ) ) gt 0 && !isNew() ){

			/* First delete any child records */
			for ( var col in variables.meta.properties ){
				if( structKeyExists( col, 'fieldType' )
					&& ( col.fieldType eq 'one-to-many' || col.fieldType eq 'one-to-one' )
					&& ( !structKeyExists( col, 'cascade') || col.cascade != 'save-update')
					){
					if(!structKeyExists(variables, col.name ) && structKeyExists( col, 'column' )){
						col.name = col.column;
						if(!structKeyExists( variables, col.name ) ){
							continue;
						}
					}else{
						continue;
					}
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

		// Run afterUpdate function.
		logIt( 'Executing afterDelete event for #getTable()#' );

		if( isNull( this.afterDelete ) ){
			afterDelete( this );
		}else{
			this.afterDelete( this );
		}
		$reset();
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
	public struct function validateProperty( required string property, any value ){
		var val = structKeyExists( arguments, value ) ? arguments.value : ( structKeyExists( variables, property ) ) ? variables[ property ] : '';
		var error = { valid = false, message = "Property '#property#' was not found" };
		var exists = ArrayFind(variables.meta.properties, function(struct){
		   return struct.name == property ;
		});
		if( exists ){
			var prop = variables.meta.properties[ exists ];
			error = _validate( prop, value );
			error = { valid = len( error ), message = error };
		}
		return error;
	}
	/**
	* Private helper to validate that the given value is legal for the the given property.
	**/
	private string function _validate( required struct property, required any value ){
		var error = "";
		if( isCustomFunction( value ) || isClosure( value ) ){
			value = value();
		}
		if( isObject( value ) ){
			return error;
		}
		//writeLog( "#getTable()# prop '#property.name#' has type? #structKeyExists( property, 'type' )#: #structKeyExists( property, 'type' ) ? property.type : 'no type'# == #serializeJSON(value)#")
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
				&& ( !len( trim( value || isNull( value ) ) ) ) ){
				// Whatever the type, if we don't allow nulls, we don't allow nulls....
				error = "#property.name# does not allow nulls, yet the currenty value empty.";

			}else{
				// If we don't have a value, there's nothing to check.  Null checks were done earlier.
				if( isNull( value ) || isSimpleValue( value ) && !len( trim( value ) ) ){
					return "";
				}
				try{
					if( !isValid( type, value ) ){
						error = "The value provided for #property.name# ('#value#') is not a valid #type#";
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

		switch( arguments.typeName ) {
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
	private void function dropTable(){
		variables.dao.dropTable( this.getTable() );
	}

	/**
    * I create a table based on the current object's properties.
    **/
	private function makeTable(){
		// Throw a helpful error message if the Norm was instantiated directly.
		if( listLast( variables.meta.name , '.' ) == "Norm"){
			if( variables.meta.fullName == "Norm"){
				throw( message = "Table #this.getTable()# does not exist", type = 'NORM' );
			}else{
				throw("If invoking Norm directly the table must exist.  Please create the table: '#this.getTable()#' and try again.");
			}
		}

		var tableDef = _loadTableDef( this.getTable() );
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
			col.norm_persistent = !structKeyExists( col, 'norm_persistent' ) ? true : col.norm_persistent;
			col.isPrimaryKey = col.isIndex = structKeyExists( col, 'fieldType' ) && col.fieldType == 'id';
			col.isNullable = !( structKeyExists( col, 'fieldType' ) && col.fieldType == 'id' );
			col.defaultValue = structKeyExists( col, 'default' ) ? col.default : '';
			col.generator = structKeyExists( col, 'generator' ) ? col.generator : '';
			col.length = structKeyExists( col, 'length' ) ? col.length : '';

			if( col.norm_persistent && !structKeyExists( col, 'CFC' ) ){

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
		variables.table = this.getTable();

	}

	// Event functions meant to be overwridden
	private function beforeLoad(){}
	private function afterLoad(){}
	private function beforeInsert(){}
	private function beforeUpdate(){}
	private function beforeDelete(){}
	private function afterInsert(){}
	private function afterUpdate( struct oldData ){}
	private function afterDelete(){}

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
		if( isNull( httpDate ) ){
			throw(message="HTTP Date required but not provided");
		}
		return parseDateTime( listFirst( httpDate, 'T' ) & ' ' & listFirst( listLast( httpDate, 'T' ), 'Z' ) );
	}
	/**
	* Will write the value of str to the server's application.log if norm_debugMode == true.
	**/
	private void function logIt( required string str, boolean force = false ){
		if( get__DebugMode() || arguments.force ){
			writeLog( str );
		}
	}

}
