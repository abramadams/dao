component accessors="true" {
	property dsn;
	public function init( required string dsn ){
		setDsn( dsn );
	}

	public any function getDBVersion( string datasource = this.getDsn() ){
		var d = "";
		dbinfo datasource="#arguments.datasource#" name="d" type="version";

		return d;
	}
	public any function getColumns( required string table, string datasource = this.getDsn() ){
		var columns = "";
		dbinfo datasource="#arguments.datasource#" name="columns" type="columns" table="#arguments.table#";
		return columns;
	}
	public any function getIndex( required string table, string datasource = this.getDsn() ){
		var index = "";
		dbinfo datasource="#arguments.datasource#" name="index" type="index" table="#arguments.table#";
		return index;
	}
}