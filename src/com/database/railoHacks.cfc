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
			var q = new Query();
			q.setSQL("SELECT * FROM tables WHERE table_name = :table");
			q.addParam( name = "table", value = pattern );
			q.setDBType( 'query' );
			q.setAttributes( tables = tables );
			tables = q.execute().getResult();
		}
		return tables;
	}
	public any function getIndex( required string table, string datasource = this.getDsn() ){
		var index = "";
		dbinfo datasource=datasource name="index" type="index" table="#table#";
		return index;
	}
}