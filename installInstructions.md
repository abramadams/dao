# Resources

**Documentation:** http://abramadams.github.io/dao/

**Chat:** The [CFML team Slack](http://cfml-slack.herokuapp.com) - Ask questions in the [#cfml-general channel](https://cfml.slack.com/messages/cfml-general/) and mention @abram.

# Running the Tests

To run tests, you'll need [CommandBox](https://www.ortussolutions.com/products/commandbox) installed.

Then run `box install` once to install the dependencies (TestBox is the only one currently).

Then start a server on port 8500 with your choice of CFML engine, e.g.,

    box server start cfengine=lucee@5 port=8500

Now you'll need a database, and to setup a DSN named `dao` in the cfml engine's admin (http://localhost:8500/CFIDE/administrator for Adobe CF or http://localhost:8500/lucee/admin/server.cfm for Lucee).

You can then run the tests:

    box testbox run verbose=false

If you get any failures, you can run this with more verbose, but still compact output:

    box testbox run reporter=mintext

# Railo/Lucee Notes
In order to use the DAO caching options with Railo/Lucee you'll need to enable a default cache in the Railo/Lucee Administrator. If this is not done, the caching mechanism will be forced off (otherwise would result in errors). Simply create a _"RamCache"_ (for some reason EHCache throws NPE) type Cache service under `Services > Cache` and set it to be the default for Object caches.  The default can also be set per app using Application.cfc by adding:
```ActionScript
this.cache.object = "your_cache_name_here";
```
> NOTE: DAO Caching is experimental and does not currently work well with nested dynamic relationships.

Also, the "Preserve single quotes" setting must be checked in the Railo/Lucee admin.  DAO specifically passes the SQL strings through ```preserveSingleQuotes()```, but this doesn't seem to work unless you have that setting checked under `Services > Datasources`.
