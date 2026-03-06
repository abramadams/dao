<cfsetting showDebugOutput="false">
<!--- Executes all tests in the 'specs' folder with simple reporter by default --->
<cfparam name="url.reporter" 		default="simple">
<cfparam name="url.directory" 		default="tests">
<cfparam name="url.recurse" 		default="true" type="boolean">
<cfparam name="url.bundles" 		default="">
<cfparam name="url.labels" 			default="">
<cfparam name="url.reportpath" 		default="#expandPath( "/tests/results" )#">
<cfparam name="url.propertiesFilename" 	default="TEST.properties">
<cfparam name="url.propertiesSummary" 	default="false" type="boolean">

<!--- Ensure dao is available (onRequestStart also sets it) --->
<cfif not structKeyExists( request, "dao" )>
	<cfset request.dao = new com.database.dao( dsn = ( structKeyExists( application, "datasource" ) ? application.datasource : "dao_sqlite" ) )>
</cfif>
<!--- Show which database tests use (only for text reporters so we don't break JSON) --->
<cfif listFindNoCase( "simple,text,mintext", url.reporter )>
	<cfoutput>Database: #request.dao.getDBtype()#</cfoutput><cfset writeOutput( chr(10) )>
</cfif>

<!--- Include the TestBox HTML Runner --->
<cfinclude template="/testbox/system/runners/HTMLRunner.cfm" >