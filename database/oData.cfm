<cfscript>
	/* ************************************************************
	*
	*	Copyright (c) 2018, Abram Adams
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

		Component	: oData.cfm
		Author		: Abram Adams
		Date		: 9/7/2018
		@version 0.0.01
		@updated 9/7/2018
		Description	: Provides oData functionality Norm.cfc.  This
		file is cfincluded into Norm.cfc as a mixin.
	 */
/* *************************************************************************** */
/* oData interface ( i.e. for BreezeJS or Kendo UI datasources )			   */
/* *************************************************************************** */

/**
* Public method to purge the currently cached oData Metadata.  This should
* be called any time there is a schema change (or to ensure the metadata)
* is generated fresh to pick up dynamically added properties/relationships.
* If the tables parameter is passed in we'll purge only the version of the
* cached object that contains those exact tables, in the exact same order.
**/
public function purgeODataMetaData( array tables = [] ){
	var cacheName = "#this.getDAO().getDsn()#-oData-Metadata";
	if( arrayLen( tables ) ){
		cacheName &= tables.hashCode();
	}
	cacheRemove( cacheName );
}
/**
* Returns oData metadata ( for oData $metadata endpoint )
**/
public function getODataMetaData( array excludeKeys = variables.meta.privateKeys, ignoreCache = false, array tables = [], array dynamicProperties = [] ){

	var cacheName = "#this.getDAO().getDsn()#-oData-Metadata";
	if( arrayLen( tables ) ){
		cacheName &= tables.hashCode();
	}
	if( !ignoreCache ){
		var cached = cacheGet( cacheName );
		if( !isNull( cached ) ){
			return cached;
		}
	}
	var cSpaceOSpaceMapping = [];
	// if tables are passed in, only include those.
	tables = arrayLen( tables ) ? tables : this.getDao().getTables();

	var entityTypes = [];
	var entitySet = [];
	var associationSet = [];
	var associations = [];
	for( table in tables ){
		var tabledef = _loadTableDef( table );
		var NORM[ table ] = $new( table = table, autoWire = true );

		arrayAppend( cSpaceOSpaceMapping, [
					"#getoDataNameSpace()#.#NORM[ table ].getoDataEntityName()#",
					"#getoDataNameSpace()#.#NORM[ table ].getoDataEntityName()#"
				]);
		var children = NORM[ table ].getChildEntities();
		var navigationProperties = [];

		if( arrayLen( children ) ){
			for( var child in children ){
				arrayAppend( navigationProperties, {
					"name": child.name,
					"relationship": "Self.#child.table#_#table#",
					"fromRole": "#child.table#_#table#_Target",
					"toRole": "#child.table#_#table#_Source"
				});
				arrayAppend( associations, {
					"name": "#child.table#_#table#",
					"end": [
					  {
						"role": "#child.table#_#table#_Source",
						"type": "Edm.Self.#table#",
						"multiplicity": "*"
					  },
					  {
						"role": "#child.table#_#table#_Target",
						"type": "Edm.Self.#child.table#",
						"multiplicity": "1",
						"onDelete": {
						  "action": "Cascade"
						}
					  }
					],
					"referentialConstraint": {
					  "principal": {
						"role": "#child.table#_#table#_Target",
						"propertyRef": {
						  "name": lcase( child.parentIdField )
						}
					  },
					  "dependent": {
						"role": "#child.table#_#table#_Source",
						"propertyRef": {
						  "name": lcase( child.childIdField )
						}
					  }
					}
				});

				arrayAppend( associationSet, {
					"name": "#child.table#_#table#",
					"association": "Self.#child.table#_#table#",
					"end": [
						{
							"role": "#child.table#_#table#_Source",
							"entitySet": "#table#"
						},
						{
							"role": "#child.table#_#table#_Target",
							"entitySet": "#child.table#"
						}
					]
				});
			}
		}
		var entityType = {
			"name" = NORM[ table ].getoDataEntityName(),
			"key" = {
				"propertyRef" = {
					"name" = lcase( NORM[ table ].getIDField() )
				}
			},
			"property" = NORM[ table ].generateODataProperties( excludeKeys =  excludeKeys, dynamicProperties = dynamicProperties )
		};
		if( arrayLen( navigationProperties ) ){
			entityType[ "navigationProperty" ] = navigationProperties;
		}
		arrayAppend( entityTypes, entityType);

		arrayAppend( entitySet, {
			"name" = table,
			"entityType" = "Self.#NORM[ table ].getoDataEntityName()#"
		});
	}

	// Now put all the metadata together in the oData package
	var oDataMetaData = {
		"schema" : {
			"namespace" : "#getoDataNameSpace()#",
			"alias": "Self",
			"annotation:UseStrongSpatialTypes": "false",
			"xmlns:annotation": "http://schemas.microsoft.com/ado/2009/02/edm/annotation",
			"xmlns": "http://schemas.microsoft.com/ado/2009/11/edm",
			"cSpaceOSpaceMapping" : serializeJSON( cSpaceOSpaceMapping ),
			"entityType" : entityTypes,
			"entityContainer" : {
				"name" : "#getDao().getDSN()#Context",
				"entitySet" : entitySet
			}
		}
	};
	// Now tack on any associations (relationships)
	if( arrayLen( associations ) ){
		oDataMetaData.schema[ "association" ] = associations;
	}
	if( arrayLen( associationSet ) ){
		oDataMetaData.schema.entityContainer[ "associationSet" ] = associationSet;
	}

	lock type="exclusive" name="#this.getDAO().getDsn()#-oData-Metadata" timeout="1"{
		cachePut( cacheName, oDataMetaData );
	}

	return oDataMetaData;
}


/**
* Returns results of arbitrary SQL query
**/
public function queryProcessor(
							string table = getTable(),
							string where = "",
							string filter = "",
							string columns = "*",
							string orderby = "",
							string skip = "",
							string top = "",
							numeric version = getODataVersion(),
							any map = "" ){

	// Apply oData filter to query
	var $filter = parseODataFilter( filter );
	if( len( trim( where ) ) ){
		where = "#reReplaceNoCase(where, 'where ', 'WHERE ( ' )#)";
	}else{
		where = "(1=1)";
	}

	var sqlWhere = (len( trim( $filter ) )) ? ' AND #$filter#' : '';
	sqlWhere = where & sqlWhere;

	// Grab base Query
	var results = getDao().read(
						sql = table,
						where = sqlWhere,
						columns = columns,
						orderBy = orderby,
						limit = top,
						offset = skip );

	return results;
}


/**
* Returns results of arbitrary SQL query in oData format.  This
* essentially does what listAsOData does, except it allows the
* "table" and "where" arguments to build the source query that will
* then be filtered by the oData filter criteria; as apposed to using
* Norm's defined table as the source.
* Params
* @qry: query object containing data to be serialized as oData
* @table: name of the table to use as the "base" in the oData struct
* @where: oData style filter criteria
* @filter: oData style filter criteria
* @select: list of columns to return - named "select" to be consistent with oData naming convention
* @columns: same as select
* @orderby: column name(s) to order by
* @skip: the offset or starting row to return of the data set (for paging)
* @top: number of records to return (for limiting return query size and/or paging)
* @version: the version of the oData protocol to serialize as (3 or 4)
* @cachedwithin: same as cfquery cachedwithin argument.  Caches query for the given timespan
* @map: a function to perform transformations on the returned recordset.  The provided function will fire for each
* 	index in the array and will be passed 3 arguments (note: arguments are positional, and named whatever you want):
* 		row - current row as a struct which will contain the current row as a struct.
* 		index - the numeric position of the row (1 == first record)
* 		cols - an array of column names included in the row
*   example: map = function( row, index, cols ){
* 				row.append( {"bla":"value"});
* 				return row;
* 			 };
* @forceLowercaseKeys: If true will return all keys as lowercase
**/
public function queryAsOData(
							required any qry,
							string table,
							string where = "",
							string filter = "",
							string columns = "*",
							string orderby = "",
							string skip = "",
							string top = "",
							numeric version = getODataVersion(),
							any map = "",
							boolean forceLowercaseKeys = false ){

	var $filter = parseODataFilter( filter );
	// If instructed to, re-order the query
	if( len( trim( orderBy ) ) ){
		qry = getDao().read( sql = "SELECT * FROM qry order by #orderby#", QoQ = {qry:qry} );
	}
	// serialize and return filtered query as oData object.
	var data = serializeODataRows( isQuery( qry ) ? getDao().queryToArray( qry = qry, map = map, forceLowercaseKeys = forceLowercaseKeys ) : qry );
	var meta = { "base": table, "page": val( skip ) && val( top ) ? ( skip / top ) + 1 : 1, "filter": $filter };
	if( len(trim( where ) ) ){
		meta[ "base" ] &= ":" & where;
	}
	return serializeODataResponse( version, data, meta );

}

/**
* Returns results of array of structs in oData format.  This
* essentially does what listAsOData does, except it allows the
* "table" and "where" arguments to build the source query that will
* then be filtered by the oData filter criteria; as apposed to using
* Norm's defined table as the source.
* Params
* @data: array of structs containing data to be serialized as oData
* @table: name of the table to use as the "base" in the oData struct
* @filter: oData style filter criteria
* @select: list of columns to return - named "select" to be consistent with oData naming convention
* @columns: same as select
* @orderby: column name(s) to order by
* @skip: the offset or starting row to return of the data set (for paging)
* @top: number of records to return (for limiting return query size and/or paging)
* @version: the version of the oData protocol to serialize as (3 or 4)
* @cachedwithin: same as cfquery cachedwithin argument.  Caches query for the given timespan
* @map: a function to perform transformations on the returned recordset.  The provided function will fire for each
* 	index in the array and will be passed 3 arguments (note: arguments are positional, and named whatever you want):
* 		row - current row as a struct which will contain the current row as a struct.
* 		index - the numeric position of the row (1 == first record)
* 		cols - an array of column names included in the row
*   example: map = function( row, index, cols ){
* 				row.append( {"bla":"value"});
* 				return row;
* 			 };
**/
public function arrayAsOData(
							array data,
							string table,
							string where = "",
							string filter = "",
							string columns = "*",
							string orderby = "",
							string skip = "",
							string top = "",
							numeric version = getODataVersion(),
							any map = "" ){

	var $filter = parseODataFilter( filter );
	// serialize and return filtered query as oData object.
	var rows = serializeODataRows( data );
	var meta = { "base": table, "page": val( skip ) && val( top ) ? ( skip / top ) + 1 : 1, "filter": $filter };
	if( len(trim( where ) ) ){
		meta[ "base" ] &= ":" & where;
	}
	return serializeODataResponse( version, rows, meta );

}

/**
* Returns a list of the current entity collection (filtered/ordered based on query args) in an oData format.
* Params
* @filter: oData style filter criteria
* @select: list of columns to return - named "select" to be consistent with oData naming convention
* @columns: same as select
* @orderby: column name(s) to order by
* @skip: the offset or starting row to return of the data set (for paging)
* @top: number of records to return (for limiting return query size and/or paging)
* @excludeKeys = columns to exclude from results
* @version: the version of the oData protocol to serialize as (3 or 4)
* @cachedwithin: same as cfquery cachedwithin argument.  Caches query for the given timespan
* @map: a function to perform transformations on the returned recordset.  The provided function will fire for each
* 	index in the array and will be passed 3 arguments (note: arguments are positional, and named whatever you want):
* 		row - current row as a struct which will contain the current row as a struct.
* 		index - the numeric position of the row (1 == first record)
* 		cols - an array of column names included in the row
*   example: map = function( row, index, cols ){
* 				row.append( {"bla":"value"});
* 				return row;
* 			 };
* @forceLowercaseKeys: If true will return all keys as lowercase
**/
public function listAsOData(
							string table = getTable(),
							string filter = "",
							string select = "",  // columns. using "select" to be consistent with oData naming
							string columns = select,
							string orderby,
							string skip,
							string offset = skip,
							string top,
							string limit = top,
							array excludeKeys = variables.meta.privateKeys,
							numeric version = getODataVersion(),
							any cachedWithin,
							any map,
							boolean forceLowercaseKeys = false ){

	var $filter = parseODataFilter( filter );
	arguments.where = len( trim( $filter ) ) ? "WHERE (1=1) AND " & preserveSingleQuotes( $filter ) : "";
	var list = listAsArray( argumentCollection:arguments );
	var data = serializeODataRows( list );
	var meta = { "base": table, "page": val( skip ) && val( top ) ? ( skip / top ) + 1 : 1 };
	return serializeODataResponse( version, data, meta );

}
/**
* Convenience function to return JSON representation of the current entity with additional oData keys
**/
public any function toODataJSON( array excludeKey = variables.meta.privateKeys, numeric version = getODataVersion() ){
	var data  = this.toStruct( excludeKeys = arguments.excludeKeys );
	data["$type"] = "#getoDataNameSpace()#.#getoDataEntityName()#, DAOoDataService";
	row["$id"] = structKeyExists( row, getIDField() ) ? row[ getIDField() ] : row[ listFirst( structKeyList( row ) ) ];

	return serializeODataResponse( version, data );
}

/**
*	Parses oData filters into SQl statements
**/
public function parseODataFilter( filter ){
	// var first = filter;
	if( len(trim( filter ) ) ){
		/* Parse oData fuzzy filters */

		filter = this.parseSubstringOf( filter );

		// AA 12/2/2016 - Removed below regex replaces and changed to parseSubstringOf() call above to better handle various uses uf substringof() oData calls.
		/*
		// step 1 replace substringof with 3+ terms (SQL "IN" statements)
		filter = rereplacenocase( filter, "\(substringof\(([^\),]+(?:,[^\),]+)+),(\w+)\)\s+((eq|\=)\s+true|(neq|\!\=)\s+false)\)", '(\2 IN ($queryParam(value="\1",list=true)$)', 'all' );
		filter = rereplacenocase( filter, "\(substringof\(([^\),]+(?:,[^\),]+)+),(\w+)\)\s+((eq|\=)\s+false|(neq|\!\=)\s+true)\)", '(\2 NOT IN ($queryParam(value="\1",list=true)$)', 'all' );
		// step 2 replace substringof with 2 terms (SQL "LIKE" statements)
		filter = rereplacenocase ( filter, "\(substringof\((\w+),(\w+)\)\s+((eq|\=)\s+true|(neq|\!\=)\s+false)\)", '(\2 LIKE $queryParam(value="%\1%")$)', 'all');
		filter = rereplacenocase ( filter, "\(substringof\((\w+),(\w+)\)\s+((eq|\=)\s+false|(neq|\!\=)\s+true)\)", '(\2 NOT LIKE $queryParam(value="%\1%")$)', 'all');
		*/
		filter = reReplaceNoCase( filter, '\bcontains\b\(\s*?(.*?)\s*,\s*''(.*?)''\s*?\)\seq\s-1', '\1 NOT like $queryParam(value="%\2%")$', 'all' );
		filter = reReplaceNoCase( filter, '\bcontains\b\(\s*(.*?),''(.*?)''(\)|$)', '\1 like $queryParam(value="%\2%")$', 'all' );
		filter = reReplaceNoCase( filter, '\indexof\b\(\s*?(.*?)\s*,\s*''(.*?)''\s*?\)\seq\s-1', '\1 NOT like $queryParam(value="%\2%")$', 'all' );
		filter = reReplaceNoCase( filter, '\bindexof\b\(\s*(.*?),''(.*?)''(\)|$)', '\1 like $queryParam(value="%\2%")$', 'all' );


		filter = reReplaceNoCase( filter, '\bstartswith\b\(\s*?(.*?)\s*,\s*[\'']*(.*?)[\'']*\s*?\)\seq\s(-1|false)', '\1 NOT like $queryParam(value="\2%")$', 'all' );
		filter = reReplaceNoCase( filter, '\bstartswith\b\(\s*?(.*?)\s*,\s*[\'']*(.*?)[\'']*\s*?\)\seq\s(1|true)', '\1 like $queryParam(value="\2%")$', 'all' );
		filter = reReplaceNoCase( filter, '\bstartswith\b\(\s*(.*?),[\'']*(.*?)[\'']*(\)|$)', '\1 like $queryParam(value="\2%")$', 'all' );
		filter = reReplaceNoCase( filter, '\bendswith\b\(\s*?(.*?)\s*,\s*[\'']*(.*?)[\'']*\s*?\)\seq\s-1', ' NOT like $queryParam(value="%\2")$\3', 'all' );
		filter = reReplaceNoCase( filter, '\bendswith\b\(\s*(.*?)(\)|$)', ' like $queryParam(value="%\2")$\3', 'all' );
		/* TODO: figure out what "any|some" and "all|every" filters are for and factor them in here */
		/* Parse oDatajs filter operators */
		filter = reReplaceNoCase( filter, '\s(eq|==|Equals*)\s[''|"]*(.*?)[''|"]*(\)|$|\sand\s|\sor\s)', ' = $queryParam(value="\2")$\3', 'all' );
		filter = reReplaceNoCase( filter, '\s(ne|\!=|NotEquals)\s[''|"]*(.*?)[''|"]*(\)|$|\sand\s|\sor\s)', ' != $queryParam(value="\2")$\3', 'all' );
		filter = reReplaceNoCase( filter, '\s(lte|le|<=|LessThanOrEqual)\s[''|"]*(.*?)[''|"]*(\)|$|\sand\s|\sor\s)', ' <= $queryParam(value=\2)$\3', 'all' );
		filter = reReplaceNoCase( filter, '\s(gte|ge|>=|GreaterThanOrEqual)\s[''|"]*(.*?)[''|"]*(\)|$|\sand\s|\sor\s)', ' >= $queryParam(value=\2)$\3', 'all' );
		filter = reReplaceNoCase( filter, '\s(lt|<|LessThan)\s[''|"]*(.*?)[''|"]*(\)|$|\sand\s|\sor\s)', ' < $queryParam(value=\2)$\3', 'all' );
		filter = reReplaceNoCase( filter, '\s(gt|>|GreaterThan)\s[''|"]*(.*?)[''|"]*(\)|$|\sand\s|\sor\s)', ' > $queryParam(value=\2)$\3', 'all' );

		// Only way to allow "is null" filters.
		filter = reReplaceNoCase( filter, '\s\=\s\$queryParam\(value\=\"#getDao().getNullValue()#\"\)\$', ' is null', 'all' );
		filter = reReplaceNoCase( filter, '\s\!\=\s\$queryParam\(value\=\"#getDao().getNullValue()#\"\)\$', ' is not null', 'all' );
		filter = reReplaceNoCase( filter, '([a-zA-Z0-9]+?)\sis null', ' NULLIF( \1, "" ) IS NULL  ', 'all' );
		filter = reReplaceNoCase( filter, '([a-zA-Z0-9]+?)\sis not null', ' NULLIF( \1, "" ) IS NOT NULL  ', 'all' );
	}
	// writeDump([first,filter]);abort;
	return filter;
}

/**
*	Parse out the all of the "substringof()" oData filters in a given string into SQL IN or LIKE statements
**/
public function parseSubstringOf( filter ){
	var tmp = filter;
	filter = reReplaceNoCase( filter, '(substringof\(.*?\)\s.*?[neq|eq]+\s(true|false|0|1))', '#chr( 755 )#parseSubstringOf(\1)#chr( 755 )#', 'all' );
	var ret = filter.listToArray( chr( 755 ) );
	ret = ret.reduce( function( prev, cur ){
		if( isNull( prev ) ){
    		prev = "";
		}
		if( left( trim( cur ), 16 ) == 'parseSubstringOf' ){
        	var substrToken = cur.listRest( '(' );
            substrToken = mid( substrToken, 1, substrToken.len()-1);
            substrToken = reReplaceNoCase( substrToken, 'substringof\((.*?)\)(.*)', '\1|\2' );
            var token = substrToken.listRest( '|' ).listToArray( ' ' );
            token.prepend( listFirst( substrToken, '|' ) );
            return prev & " " & substringof( token );
        }else{
            return prev & " " & cur;
        }
	});

	return ret.replace( chr( 755 ), '', 'all' );
}

/**
* Parses a single "substringof()" filter into either an SQL IN or LIKE statement
* params should be an array with three items: ["comma separated list of values", "operator (eq|neq)", "boolean"]
**/
public function substringof( params ){
	var args = params[ 1 ].listToArray();
	if( args.len() ){
    	var field = args[ args.len() ];
    	var opr = params[ 2 ];
    	var bool = params[ 3 ];
    	bool = ( opr == 'eq' || opr == '=' ) ? bool : !bool;

    	var value = args.reduce( function( prev, cur, idx ){
            if( isNull( prev ) ){
                return [ cur ];
            }else{
                // last item in list is always field name
                return idx >= args.len() ? prev : prev.append( cur );
            }
        });
	}

    var inLike = value.len() <= 1 ? 'LIKE' : 'IN';
    var val = value.toList();
    if( inLike == 'LIKE' ){
    	// strip any quotes if they exist, then wrap in %
    	val = "%#trim( val.reReplace( "['|""](.*?)['|""]", '\1' ) )#%";
    }
    var paramedValue = '$queryParam( value = "#val#", list = "#value.len() gt 1#" )$';

    return "( #field# #!bool ? 'NOT' : ''# #inLike##inLike eq 'IN' ? '(' : ''# #paramedValue# #inLike eq 'IN' ? ')' : ''# )";
}

/**
* Takes an array of structs and converts it to an oData formatted array of structs
**/
public array function serializeODataRows( required array data, numeric version = getODataVersion() ){
	var row = "";
	var oData = [];
	var tempType = "#getoDataNameSpace()#.#getoDataEntityName()#, DAOoDataService";

	for( var i = 1; i LTE arrayLen( data ); i++ ){
		row = data[ i ];
		row["$type"] = tempType;
		row["$id"] = structKeyExists( row, getIDField() ) ? row[ getIDField() ] : row[ listFirst( structKeyList( row ) ) ];
		arrayAppend( oData, row );
		row = "";
	}

	return oData;
}

/**
* Serializes the OData response formatted per the given OData version
**/
public struct function serializeODataResponse( numeric version = getODataVersion(), required array data, struct additionalResponseData ){
	var ret = {};
	if( !isNull( additionalResponseData ) && isStruct( additionalResponseData ) ){
		ret[ "__metadata" ] = additionalResponseData;
	}
	switch(version) {
	    case "3":
	        structAppend( ret, {
					"__metadata": "#getODataBaseUri()#Metadata$metadata###getoDataEntityName()#",
					"__count": arrayLen( data ) ? structKeyExists( data[1], '__count' ) ? data[1].__count : arrayLen( data ) : 0,
					"results": data
				},false);
			return ret;
	    case "4":
	    	structAppend( ret, {
					"odata.metadata": "#getODataBaseUri()#Metadata$metadata###getoDataEntityName()#",
					"odata.count": arrayLen( data ) ? structKeyExists( data[1], '__count' ) ? data[1].__count : arrayLen( data ) : 0,
					"value": data
				}, false);
	        return ret;
	    default:
	         throw('OData version #version# not supported.');
	}




}
/**
*   Accepts an array of oData entities and perform the appropriate DB interactions based on the metadata and returns the Entity struct with the following:
* 	Entities: An array of entities that were sent to the server, with their values updated by the server. For example, temporary ID values get replaced by server-generated IDs.
* 	KeyMappings: An array of objects that tell oData which temporary IDs were replaced with which server-generated IDs. Each object has an EntityTypeName, TempValue, and RealValue.
* 	Errors (optional): An array of EntityError objects, indicating validation errors that were found on the server. This will be null if there were no errors. Each object has an ErrorName, EntityTypeName, KeyValues array, PropertyName, and ErrorMessage.
*
**/
public struct function oDataSave( required any entities ){
	var errors = [];
	var keyMappings = [];

	for (var entity in arguments.entities ){
		this.load( entity );
		if( entity.entityAspect.EntityState == "Deleted" ){ // other states: Added, Modified
			this.delete();
		}else{
			try{
				// for adds this will represent the temporary ID value given by oDataJS (i.e. -1, -2, etc..)
				var tempValue = entity[ this.getIDField() ];
				transaction{
					this.save();
				}
				// Now setup some return data for oData client
				entity[ '$type' ] = "#getoDataNameSpace()#.#getoDataEntityName()#";
				entity[ this.getIDField() ] = this.getID();
				if ( structKeyExists( entity.entityAspect.originalValuesMap, entity.entityAspect.autoGeneratedKey.propertyName ) ){
					arrayAppend( keyMappings, { "EntityTypeName" = entity['$type'], "TempValue" = entity.entityAspect.originalValuesMap[ entity.entityAspect.autoGeneratedKey.propertyName ], "RealValue" = this.getID() } );
				}else if ( entity.entityAspect.entityState == 'Added' ){
					arrayAppend( keyMappings, { "EntityTypeName" = entity['$type'], "TempValue" = tempValue, "RealValue" = this.getID() } );
				}
			} catch( any e ){
				// append any errors found to return data for oData client;
				arrayAppend( errors, {"ErrorName" = e.error, "EntityTypeName" = entity.entityAspect.entityTypeName, "KeyValues" = [], "PropertyName" = "", "ErrorMessage" = e.detail } );
			}
		}

		// remove the entityAspect key from the struct.  We don't need it in the returned data; in fact oData will error if it exists..
		structDelete( entity, 'entityAspect' );
	}

	var ret = { "Entities" = arguments.entities, "KeyMappings" = keyMappings };
	if ( arrayLen( errors ) ){
		ret["Errors"] = errors;
	}

	return ret;
}

/**
*  I return the namespace to be used by oData to contain this entity.
*  To ensure uniqueness I use a reverse dir path plus the DSN (in dot notation).
*  Example: Com.Model.Dao
**/
private function getoDataNameSpace(){
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
private function getoDataEntityName(){
	var mapping = _getMapping( this.getTable() );
	var entityName = structKeyExists( variables.meta, 'singularName' ) ? variables.meta.singularName : mapping.property;
	return entityName;
}

/**
* I return an array of structs containing all of the oData friendly properties of the entity (table).
**/
private function generateODataProperties( array excludeKeys = variables.meta.privateKeys, array dynamicProperties = [] ){
	var props = [];
	var properties = duplicate( variables.meta.properties );
	properties.append( dynamicProperties, true );

	//var prop = { "validators" = [] };
	var prop = { };

	for ( var col in properties ){
		/* TODO: flesh out relationships here */
		if( !structKeyExists( col, 'type') || ( structKeyExists( col, 'norm_persistent' ) && !col.norm_persistent ) || arrayFindNoCase( excludeKeys, col.name ) ){
			continue;
		}
		prop["name"] = lcase(col.column);

		prop["type"] = getoDataType( col.type );
		//prop["defaultValue"] = structKeyExists( col, 'default' ) ? col.default : "";
		prop["nullable"] = structKeyExists( col, 'notnull' ) ? !col.notnull : true;

		/* is part of a key? */
		if( structKeyExists( col, 'fieldType' ) && col.fieldType == 'id'
			|| structKeyExists( col, 'uniquekey' ) || col.name == getIDField() ){
			prop["name"] = lcase( col.column );
			prop["isPartOfKey"] = true;
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
* Given a CF or DB data type, I return the equivalent oData data type.
**/
private function getoDataType( required string type ){
	var CfTooDataTypes = {
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

	return "Edm." & ( structKeyExists( CfTooDataTypes, type ) ? CfTooDataTypes[ type ] : type );

}
</cfscript>