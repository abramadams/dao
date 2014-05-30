<cfsetting showdebugoutput="false" >
<cfset r = new testbox.system.testing.TestBox( "testbox.samples.specs.MXUnitCompatTest" ) >
<cfoutput>#r.run()#</cfoutput>