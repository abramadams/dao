<cfsetting showdebugoutput="false" >
<!--- One runner --->
<cfset r = new testbox.system.testing.TestBox( bundles="testbox.samples.specs.Assertionscf9Test" ) >
<cfoutput>#r.run(reporter="simple")#</cfoutput>