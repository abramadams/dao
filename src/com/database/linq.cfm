<cfscript>
	/* ************************************************************
	*
	*	Copyright (c) 2017, Abram Adams
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

		Component	: linq.cfm
		Author		: Abram Adams
		Date		: 9/7/2017
		@version 0.0.01
		@updated 9/7/2017
		Description	: Provides LINQ style query building for dao.cfc.  This
		file is cfincluded into dao.cfc as a mixin.
	 */

		// resets any criteria
		_resetCriteria();
		/**
		* Entity Query API - Provides LINQ'ish style queries
		* Returns a duplicate copy of DAO with an empty Entity Query criteria
		* (except the args passed in).  This allows multiple entity queries to co-exist
		**/
		public function from( required string table, any joins = [], string columns = getColumns( arguments.table ) ){
			var newDao = new();
			newDao._criteria.from = table;
			newDao._criteria.columns = columns;
			newDao._criteria.callStack = [ { from = table, joins = joins } ];
			if( arrayLen( joins ) ){
				for( var _table in joins ){
					newDao.join( type = _table.type, table = _table.table, on = _table.on );
					if( !isNull( _table.columns ) ){
						newDao._criteria.columns = listAppend( newDao._criteria.columns, _table.columns );
					}
				}
			}

			return newDao;
		}

		public function where( required string column, required string operator, required string value ){
			// There can be only one where.
			if ( arrayLen( this._criteria.clause ) && left( this._criteria.clause[ 1 ] , 5 ) != "WHERE" ){
				this._criteria.clause.prepend( "WHERE #_getSafeColumnName( column )# #operator# #queryParam(value)#" );
			}else{
				this._criteria.clause[ 1 ] = "WHERE #_getSafeColumnName( column )# #operator# #queryParam(value)#";
			}
			this._criteria.callStack.append( { where = { column = column, operator = operator, value = value } } );
			return this;
		}
		public function andWhere( required string column, required string operator, required string value ){
			return _appendToWhere( andOr = "AND", column = column, operator = operator, value = value );
		}

		public function orWhere( required string column, required string operator, required string value ){
			return _appendToWhere( andOr = "OR", column = column, operator = operator, value = value );
		}

		/**
		* Opens a parenthesis clause.  Operator should be AND or OR
		* If "AND" is passed, it will return AND (
		* Must be closed by endGroup()
		**/
		public function beginGroup( string operator = "AND"){

			this._criteria.clause.append( "#operator# ( " );
			this._criteria.callStack.append( { beginGroup = { operator = operator } } );
			return this;
		}
		/**
		* Ends the group.  All this really does is append a closing
		* parenthesis
		**/
		public function endGroup(){

			this._criteria.clause.append( " )" );
			this._criteria.callStack.append( { endGroup = "" });
			return this;
		}

		public function join( string type = "LEFT", required string table, required string on, string alias = arguments.table, string columns ){
			this._criteria.joins.append( "#type# JOIN #_getSafeColumnName( table )# #alias# on #on#" );
			this._criteria.callStack.append( { join = { type = type, table = table, on = on, alias = alias } } );
			if( !isNull( columns ) ){
				this._criteria.columns = listAppend( this._criteria.columns, columns );
			}
			return this;
		}

		public function orderBy( required string orderBy ){

			this._criteria.orderBy = orderBy;
			this._criteria.callStack.append( { orderBy = { orderBy = orderBy } } );
			return this;
		}

		public function limit( required any limit ){

			this._criteria.limit = arguments.limit;
			this._criteria.callStack.append( { limit = { limit = limit } } );
			return this;
		}

		public function returnAs( string returnType = "Query" ){

			this._criteria.returnType = arguments.returnType;
			this._criteria.callStack.append( { returnType = { returnType = returnType } } );

			return this;
		}

		public function run(){
			return read( table = this._criteria.from,
						 columns = this._criteria.columns,
						 where = arrayToList( this._criteria.joins, " " ) & " " & arrayToList( this._criteria.clause, " " ),
						 limit = this._criteria.limit,
						 orderBy = this._criteria.orderBy,
						 returnType = this._criteria.returnType );
		}

		public function getCriteria(){
			return this._criteria;
		}

		public function setCriteria( required criteria ){
			this._criteria = criteria;
		}

		public function getCriteriaAsJSON(){
			var ret = this._criteria;
			structDelete( this._criteria, 'callStack' );

			return serializeJSON( ret );
		}

		// EntityQuery "helper" functions
		public function _appendToWhere( required string andOr, required string column, required string operator, required string value ){
			if ( arrayLen( this._criteria.clause )
				&& ( left( this._criteria.clause[ arrayLen( this._criteria.clause ) ] , 5 ) != "AND ("
				&& left( this._criteria.clause[ arrayLen( this._criteria.clause ) ] , 4 ) != "OR (" ) ){
				if( operator == "in" ){
					this._criteria.clause.append( "#andOr# #_getSafeColumnName( column )# #operator# ( #queryParam(value=value,list=true)# )" );
				}else{
					this._criteria.clause.append( "#andOr# #_getSafeColumnName( column )# #operator# #queryParam(value=value,null=(value eq getNullValue()))#" );
				}
			}else{
				if( operator == "in" ){
					this._criteria.clause.append( "#_getSafeColumnName( column )# #operator# ( #queryParam(value=value,list=true)# )" );
				}else{
					this._criteria.clause.append( "#_getSafeColumnName( column )# #operator# #queryParam(value=value,null=(value eq getNullValue()))#" );
				}
			}
			this._criteria.callStack.append( { _appendToWhere = { andOr = andOr, column = column, operator = operator, value = value } } );
			return this;
		}
		public function _resetCriteria(){
			this._criteria = { from = "", clause = [], limit = "*", orderBy = "", joins = [], returnType = "Query" };
		}
</cfscript>