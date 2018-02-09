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

		Component	: linq.cfm
		Author		: Abram Adams
		Date		: 9/7/2018
		@version 0.0.01
		@updated 9/7/2018
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

		public function where( any column = "", string operator, string value, any predicate ){
			if( !isSimpleValue( column ) ){
				predicate = column;
			}else if(
				isSimpleValue( column )
				&& !arguments.keyExists( 'predicate' )
				&& ( !arguments.keyExists( 'operator' ) || !arguments.keyExists( 'value' ) )
			){
				throw('Arguments Operator and Value must be passed in unless passing in a predicate');
			}else if( isSimpleValue( column ) && !len( trim( column ) ) && predicate.size() != 0 ){
				column = predicate;
			}
			if( isStruct( column ) ){
				arguments.operator = column.operator;
				arguments.value = column.value;
				arguments.column = column.column;
			}
			// There can be only one where.
			if ( arrayLen( this._criteria.clause ) && left( this._criteria.clause[ 1 ] , 5 ) != "WHERE" ){
				this._criteria.clause.prepend( "WHERE #_getSafeColumnName( column )# #operator# #queryParam(value)#" );
			}else{
				this._criteria.clause[ 1 ] = "WHERE #_getSafeColumnName( column )# #operator# #queryParam(value)#";
			}
			this._criteria.callStack.append( { where = { column = column, operator = operator, value = value } } );
			return this;
		}
		public function andWhere( any column, string operator, string value, struct predicate = {} ){
			// Must be at least a where clause
			if( !this._criteria.clause.len() ) where(1,"=",1);

			arguments.andOr = "AND";
			_andOrWhere( argumentCollection:arguments );
			return this;
		}

		public function orWhere( any column, string operator, string value, struct predicate = {} ){
			// Must be at least a where clause
			if( !this._criteria.clause.len() ) where(1,"=",1);

			arguments.andOr = "OR";
			_andOrWhere( argumentCollection:arguments );
			return this;
		}

		private function _andOrWhere(  any column = "", string operator, string value, any predicate, required string andOr ){
			if( !isSimpleValue( column ) ){
				predicate = column;
			}else if(
				isSimpleValue( column )
				&& !arguments.keyExists( 'predicate' )
				&& ( !arguments.keyExists( 'operator' ) || !arguments.keyExists( 'value' ) )
			){
				throw('Arguments Operator and Value must be passed in unless passing in a predicate');
			}else if( isSimpleValue( column ) && !len( trim( column ) ) && predicate.size() != 0 ){
				column = predicate;
			}
			if( isStruct( column ) ){
				_appendToWhere( andOr = andOr, column = column.column, operator = column.operator, value = column.value );
			}else if( isArray( column ) ){
				column.each(function(col){
					_appendToWhere( andOr = andOr, column = col.column, operator = col.operator, value = col.value );
				});
			}else{
				_appendToWhere( andOr = andOr, column = column, operator = operator, value = value );
			}
			return this;
		}

		/**
		* PREDICATES - These are simply where clauses that you can build independently from the linq query chain.
		* For instance you may build a series of predicates over time that you then feed into the linq (Entity Query).
		* i.e.
		* var predicate = dao.predicate("columnName", "=", "123" );
		* var predicate2 = dao.predicate("SecondcolumnName", "=", "abc" );
		* var results = dao.from("myTable").where(predicate).andWhere(predicate).run();
		*
		* You could also group and pass in multiple as arrays
		* i.e.
		* var predicates = [
		*			dao.predicate("columnName", "=", "123" ),
		*			dao.predicate("SecondcolumnName", "=", "abc" )
		* ];
		* var results = dao.from("myTable").where(1,"=",1).andWhere(predicates).run();
		*
		* These are also usefull for nested groups such as the following SQL:
		*	WHERE 1 = 1
		* 	AND ( column1 = 1 OR column2 = "a" OR ( column3 = "c" AND column4 = "d") )
		* This would be represented in entity query/linq as:
		* var orPredicates = [
		*			dao.predicate("column1", "=", "1" ),
		*			dao.predicate("column2", "=", "a" )
		* ];
		* var andPredicates = [
		*			dao.predicate("column3",=,"c"),
		*			dao.predicate("column4",=,"d")
		* ];
		* var results = dao.from("myTable").where(1,"=",1)
		*						.andWhere(predicates)
		*						.beginGroup("AND")
		*							.orPredicate( orPredicates )
		*							.beginGroup("OR")
		*								.andPredicate( andPredicates )
		*							.endGroup()
		*						.endGroup()
		*						.run();
		*
		**/
		public function predicate( required any column, string operator = "", string value = "" ){
			if( isArray( column ) && column.size() == 3 ){
				return { column: column[1], operator:column[2], value: column[3] };
			}
			return arguments;
		}
		public array function predicates( required array predicates ){
			return arguments.predicates;
		}
		public function andPredicate( required predicate ){
			_andOrPredicate( predicate = predicate, andOr = "AND" );
			return this;
		}
		public function orPredicate( required predicate ){
			_andOrPredicate( predicate = predicate, andOr = "OR" );
			return this;
		}
		private function _andOrPredicate( required predicate, required andOr ){
			var group = false;
			if( this._criteria.keyExists('callStack') && this._criteria.callStack.size() ){
				this._criteria.clause.append( "(" );
				group = true;
			}else{
				this._criteria.callStack = [];
			}
			_andOrWhere( argumentCollection:arguments );
			if( group ){
				endGroup();
			}
		}

		/**
		* Opens a parenthesis clause.  Operator should be AND or OR
		* If "AND" is passed, it will return AND (
		* Must be closed by endGroup()
		**/
		public function beginGroup( string operator = ""){

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

		public function offset( required any offset ) {
			this._criteria.offset = arguments.offset;
			this._criteria.callStack.append( { offset = { offset = offset } } );
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
						 offset = this._criteria.offset,
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
			if( trim( right( trim( this._criteria.clause[ arrayLen( this._criteria.clause ) ] ), 1 ) ) == "(" ){
				this._criteria.clause[ arrayLen( this._criteria.clause ) ] = '#andOr# (';
			}
			if( operator == "contains" ){
				operator = "like";
				value = "%#value#%";
			}

			if ( arrayLen( this._criteria.clause )
				&& (
					   left( this._criteria.clause[ arrayLen( this._criteria.clause ) ] , 5 ) != "AND ("
					&& left( this._criteria.clause[ arrayLen( this._criteria.clause ) ] , 4 ) != "OR ("
				)
			){
				if( operator == "in" ){
					this._criteria.clause.append( "#andOr# #_getSafeColumnName( column )# #operator# ( #queryParam(value=value,list=true)# )" );
				}else{
					this._criteria.clause.append( "#andOr# #_getSafeColumnName( column )# #operator# #queryParam(value=value,null=(value eq getNullValue()))#" );
				}
			}else{
				if( right( trim( this._criteria.clause[ arrayLen( this._criteria.clause )-1 ] ), 1 ) == "(" ){
					this._criteria.clause[ arrayLen( this._criteria.clause ) ] = ' ( ';
				}else{
					this._criteria.clause[ arrayLen( this._criteria.clause ) ] = ' #andOr# (';
				}
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
			this._criteria = { from = "", clause = [], limit = "*", offset = "*", orderBy = "", joins = [], returnType = "Query" };
		}
</cfscript>