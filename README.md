## Dao & Norm
* Dao - A ColdFusion library for easy and db agnostic CRUD interaction and Linq style query building.
* Norm (Not ORM) - A dynamic Object Mapping layer built on top of DAO that provides oData support and ORM style object interactions (load, save, relate entities, etc...).

## Elevator Pitch
Dao/Norm is a duo of libraries that provide a simple yet full featured interface to perform script based queries as well as adds extended functionality such as ORM (with easy and dynamic relationships), oData (Consume/Produce), LINQ style queries and more.  Basically it is the data interaction ColdFusion/Railo/Lucee should have come with out of the box.

In short, the goal of this library is to allow one to interact with the database in a DB platform agnostic way, while making it super easy.

## Supported databases
Dao supports **MySQL**, **MSSQL**, and **SQLite** via connector components (`database/mysql.cfc`, `database/mssql.cfc`, `database/sqlite.cfc`) that implement `IDAOConnector`. Use the `dbtype` argument when creating the DAO (e.g. `new database.dao( dsn = "mydsn", dbtype = "sqlite" )`) or rely on auto-detection when the datasource is configured. Tests and connector logic must remain compatible with all three; avoid changes that assume a single database.

## Requirements
- **Runtime:** Lucee 4.x, 5.x, 6.x, or Adobe CF 11+
- **Lucee 6:** Requires **Java 11 or later**. CommandBox uses your system `java`; if you see `org.lucee.commonmark` / `osgi.ee; (version=11)` when running `box start`, install a newer JVM and point the project at it (see below).

### Using Java 11+ with this project (Lucee 6)

1. **Install OpenJDK 17** (Ubuntu/Debian):
   ```bash
   sudo apt-get update && sudo apt-get install -y openjdk-17-jdk
   ```

2. **Make it the system default** so CommandBox (and everything else) uses Java 17 globally:
   ```bash
   sudo update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java
   ```
   Confirm with `java -version` (should show 17.x). No per-project or per-shell setup needed.

## Installation
### Manual
Clone this repo and copy the "database" folder `(/database)` into your project (or into the folder you place your components)
### CommandBox
`box install dao`

### Examples
#### DAO
```ActionScript
dao = new database.dao();
dao.update("sometable",form);
```
```ActionScript
function getUsers(){
	// normally injected or in applicaiton scope
	dao = new database.dao();
	return dao.read(
		sql = "
			SELECT fname as firstName, lname as lastName
			FROM Users
		",
		returnType = "array"
	);
}
writeOutput( getUsers() );
```
Output:
```JavaScript
[
	{"firstName":"Jill","lastName":"Smith"},
	{"firstName":"Joe","lastName":"Blow"},
	{"firstName":"John","lastName":"Cash"}
]
```
#### LINQ
```ActionScript
dao.from( "eventLog" )
		.where( "eventDate", "<", now() )
		.andWhere( "eventDate", ">=", dateAdd( 'd', -1, now() ) )
	.run();
```
#### Norm
```ActionScript
User = new database.Norm("user");
User.loadByFirstName("joe");
User.setStatus("online");
User.save();
```
## Resources

**Documentation and Examples:** [https://github.com/abramadams/dao/wiki](https://github.com/abramadams/dao/wiki)

**Chat:** The [CFML team Slack](http://cfml-slack.herokuapp.com) - Ask questions in the [#cfml-general channel](https://cfml.slack.com/messages/cfml-general/) and mention @abram.

## Testing

**Which database are tests using?** The first line of test output is `Database: sqlite` (or `mysql` / `mssql`). To change it, set **`this.datasource`** in `tests/Application.cfc` to **`dao_sqlite`**, **`dao_mysql`**, or **`dao_mssql`** (all three are defined in the same `this.datasources` block). See [docs/test-database.md](docs/test-database.md).

## Testing with MySQL or MSSQL (Docker)

A Docker Compose file is included to run MySQL and/or MSSQL for tests. Start with `docker compose up -d` (or `docker compose up -d mysql` / `docker compose up -d mssql`). See [docs/docker-mysql.md](docs/docker-mysql.md) and [docs/docker-mssql.md](docs/docker-mssql.md) for connection details and how to point the test app at each database.

## Contributing
Pull requests welcome! See [installation instructions](https://github.com/abramadams/dao/wiki/02-Extending%5CTesting) for setup and testing.

## Copyright and License

Copyright (c) 2007-2026 Abram Adams. All rights reserved.

The use and distribution terms for this software are covered by the Apache Software License 2.0 (http://www.apache.org/licenses/LICENSE-2.0) which can also be found in the file LICENSE at the root of this distribution and in individual licensed files.
By using this software in any fashion, you are agreeing to be bound by the terms of this license. You must not remove this notice, or any other, from this software.