component extends="taffy.core.api" {	
	//this.name = "breeze-Test-api";	
	this.name = hash(getCurrentTemplatePath());
	this.mappings['/'] = expandPath( '.' );
	this.mappings['/com'] = expandPath( '/src/com/' );
	this.mappings['/model'] = expandPath( '../model' );
	this.mappings['/taffy'] = expandPath('./taffy');
	this.mappings['/resources'] = expandPath('./resources');
/* 
	variables.framework = {};
	variables.framework.debugKey = "debug";
	variables.framework.reloadKey = "reload";
	variables.framework.reloadPassword = "true";
	variables.framework.representationClass = "taffy.core.genericRepresentation";
	variables.framework.returnExceptionsAsJson = true;
	 */
	variables.framework = {
		reloadKey = "reboot",
		reloadPassword = "makeithappen",
		disableDashboard = false,
		disabledDashboardRedirect = "/",
		debugKey = "debugonly",
		representationClass = "taffy.core.genericRepresentation"

	};

	// this function is called after the request has been parsed and all request details are known
	function onTaffyRequest(verb, cfc, requestArguments, mimeExt){
		// this would be a good place for you to check API key validity and other non-resource-specific validation
		return true;
	}

}