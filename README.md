## Dao & Norm
* Dao - A ColdFusion library for easy and db agnostic CRUD interaction and Linq style query building.
* Norm (Not ORM) - A dynamic Object Mapping layer built on top of DAO that provides oData support on top of ORM style object interactions (load, save, relate entities, etc...).

## Elevator Pitch
Dao/Norm is a duo of libraries that provide a simple yet full featured interface to perform script based queries as well as adds extended functionality such as ORM (with easy and dynamic relationships), oData (Consume/Produce), LINQ style queries and more.  Basically it is the data interaction ColdFusion/Railo/Lucee should have come with out of the box.

In short, the goal of this library is to allow one to interact with the database in a DB platform agnostic way, while making it super easy.

## Requirements
Currently this library has been actively used and tested on Lucee 4x, CF11+

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

## Contributing
Pull requests welcome! See [installation instructions](https://github.com/abramadams/dao/wiki/02-Extending%5CTesting) for setup and testing.

## Copyright and License

Copyright (c) 2009-2017 Abram Adams. All rights reserved.
The use and distribution terms for this software are covered by the Apache Software License 2.0 (http://www.apache.org/licenses/LICENSE-2.0) which can also be found in the file LICENSE at the root of this distribution and in individual licensed files.
By using this software in any fashion, you are agreeing to be bound by the terms of this license. You must not remove this notice, or any other, from this software.