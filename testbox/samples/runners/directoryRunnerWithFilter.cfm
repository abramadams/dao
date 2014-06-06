<cfsetting showdebugoutput="false" >
<cfscript>
r = new testbox.system.testing.TestBox( directory={ 
		mapping = "testbox.samples.specs", 
		recurse = true,
		filter = function( path ){ return true; }
});

</cfscript>
<cfoutput>#r.run(reporter="simple")#</cfoutput>