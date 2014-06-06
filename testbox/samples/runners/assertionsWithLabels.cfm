<cfsetting showdebugoutput="false" >
<cfparam name="url.reporter" default="simple"> 
<!--- One runner --->
<cfset r = new testbox.system.testing.TestBox( bundles="testbox.samples.specs.AssertionsTest", labels="railo" ) >
<cfoutput>#r.run(reporter="#url.reporter#")#</cfoutput>