component norm_persistent="true" accessors="true" table="companies" extends="com.database.Norm" {

	public function init( ){
		super.init();
	}

	public any function load( id ){

		// Now load the entity, passing any args that we were given
		super.load( argumentCollection = arguments );

		// Now that the entity is loaded, we can identify any many-to-one relationships with the hasMany function
		this.hasMany( table = "call_notes", fkColumn = "companies_ID", property = "CallNotes" );


		return this;
	}
}