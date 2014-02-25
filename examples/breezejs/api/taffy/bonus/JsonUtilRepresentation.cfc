<cfcomponent extends="taffy.core.baseRepresentation">
		
	<cfset variables.jsonUtil = application._taffy.factory.beans.jsonUtil />
	

	<cffunction
		name="getAsJson"
		output="false"
		taffy:mime="application/json"
		taffy:default="true">
			<cfreturn variables.jsonUtil.serialize(variables.data) />
	</cffunction>

</cfcomponent>