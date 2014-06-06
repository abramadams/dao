<cfsetting showdebugoutput="false" >
<cfparam name="url.reporter" default="simple">
<!--- Directory Runner --->
<cfset r = new testbox.system.testing.TestBox( directory={ mapping = "testbox.samples.specs", recurse = true } ) >
<cfoutput>#r.run(reporter=url.reporter)#</cfoutput>