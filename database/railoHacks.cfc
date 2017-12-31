/************************************************************
*
*	Copyright (c) 2007-2015, Abram Adams
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
************************************************************
*
*		Component	: railoHacks.cfc
*		Author		: Abram Adams
*		Date		: 9/10/2015
*		@version 0.0.02
*		@updated 9/10/2015
*		Description	: Helper methods to overcome compatibility
*		issues between Railo/Lucee and Adobe ColdFusion
***********************************************************/
component accessors="true" {
	property dsn;
	public function init( required string dsn ){
		setDsn( dsn );
	}

	public any function getDBVersion( string datasource = this.getDsn() ){
		var d = "";
		dbinfo datasource=datasource name="d" type="version";

		return d;
	}
	public any function getDBName( string datasource = this.getDsn() ){
		var tables = "";
		dbinfo datasource=datasource name="tables" type="tables";
		return tables.table_cat[1];
	}
	public any function getColumns( required string table, string datasource = this.getDsn() ){
		var columns = "";
		dbinfo datasource=datasource name="columns" type="columns" table="#table#";
		return columns;
	}
	public any function getTables( string datasource = this.getDsn(), string pattern = "" ){
		var tables = "";
		dbinfo datasource=datasource name="tables" type="tables" table=pattern pattern=pattern;
		// filtering tables by pattern is case sensitive, though the source of pattern could have
		// come from extracting metadata from an object, wich does not retain case.
		if( !tables.recordCount ){
			dbinfo datasource=datasource name="tables" type="tables";
			tables = queryExecute(
		    "SELECT * FROM tables WHERE table_name = :table",
		    { table: pattern },
				{ dbtype: 'query' }
			);
		}

		return tables;
	}
	public any function getIndex( required string table, string datasource = this.getDsn() ){
		var index = "";
		dbinfo datasource=datasource name="index" type="index" table="#table#";
		return index;
	}
}
