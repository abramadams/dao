<cfsetting showdebugoutput="false" >
<cfset suite = new testbox.system.testing.compat.framework.TestSuite().TestSuite()>
<cfset suite.addAll( "testbox.samples.specs.MXUnitCompatTest" )>
<cfset r = suite.run()>
<cfoutput>#r.getResultsOutput( reporter="simple" )#</cfoutput>

<cfset suite = new testbox.system.testing.compat.framework.TestSuite().TestSuite()>
<cfset suite.add( "testbox.samples.specs.MXUnitCompatTest", "testAssertTrue" )>
<cfset suite.add( "testbox.samples.specs.MXUnitCompatTest", "testAssert" )>
<cfset r = suite.run()>
<cfoutput>#r.getResultsOutput( reporter="simple" )#</cfoutput>
