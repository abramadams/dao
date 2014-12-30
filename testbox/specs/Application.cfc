component {
	this.name = "A TestBox Runner Suite " & hash( getCurrentTemplatePath() );
	// any other application.cfc stuff goes below:
	this.sessionManagement = true;

	// any mappings go here, we create one that points to the root called test.
	this.mappings[ "/com" ] = expandPath('/src/com');
	this.mappings[ "/testbox" ] = expandPath( '/testbox' );
	// any orm definitions go here.

	// request start
	public boolean function onRequestStart( String targetPage ){

		return true;
	}
}