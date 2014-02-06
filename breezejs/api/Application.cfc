component extends="taffy.core.api" {	
	//this.name = "breeze-Test-api";	
	this.name = hash(getCurrentTemplatePath());
	this.mappings['/com'] = expandPath( '/src/com/' );
	this.mappings['/model'] = expandPath( '../model' );
	this.mappings['/taffy'] = expandPath( './taffy' );
	this.mappings['/resources'] = expandPath( './resources' );

	variables.framework = {
		reloadKey = "reload",
		reloadPassword = "true",
		disableDashboard = false,
		disabledDashboardRedirect = "/",
		debugKey = "debugonly"	
	};

	// this function is called after the request has been parsed and all request details are known
	function onTaffyRequest(verb, cfc, requestArguments, mimeExt){
		// this would be a good place for you to check API key validity and other non-resource-specific validation
		return true;
	}

}