<cfsetting showdebugoutput="false" >
<!--- Directory Runner --->
<cfset r = new testbox.system.testing.TestBox( directory="testbox.samples.specs" ) >
<cfoutput>#r.run(reporter="simple")#</cfoutput>