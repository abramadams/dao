<cfset r = new testbox.system.testing.compat.runner.DirectoryTestSuite()
				.run( directory="#expandPath( '/testbox/samples/specs' )#", 
					  componentPath="testbox.samples.specs" )>
<cfoutput>#r.getResultsOutput( 'simple' )#</cfoutput>
