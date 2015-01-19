dao - A ColdFusion library for easy Data Access and Object Mapping.
===
#Elevator Pitch
DAO/BaseModelObject is a library that provides a simple yet full featured interface to perform script based queries as well as adds extended functionality such as ORM (with easy and dynamic relationships), oData (Consume/Produce), LINQ style queries and more.  Basically it is the data interaction ColdFusion/Railo should have come with out of the box.

In short, the goal of this library is to allow one to interact with the database in a DB platform agnostic way, while making it super easy.

# Disclaimer
Though I have been using this library for many years on many, many projects, it has never been used or tested outside
of my control, so there are absolutely-positively things that are missing, and things that are just plain old broke.  There's also
a bit of ugly code in there, If you stumble on something, raise an issue (or submit a pull request :) )

# Requirements
Currently this library has been actively used and tested on Railo 4x, CF10 and CF11 (though the dao.cfc stuff should work with CF8 - for now).  To make the entire library work on CF9 you would need to change any code that calls _closure_*() methods as these use function expressions and closures, which break CF9.  So far I've included commented code that will make it cf9 compatible.  Simply find and uncomment the code preceded with "// CF9 Way" and comment out the code preceded with "// CF10+/Railo4+ way"

# Database Platform Agnostic
Currently there are two databases that are supported: MySQL and MS SQL.  Others can be added by
creating a new CFC that implements the necessary methods.  The CFC  name would then be the "dbtype"
argument passed to the init method when instantiating dao.cfc.  So if you have otherrdbs.cfc, you'd
instantiate as: dao = new dao( dbType = 'otherrdbs' );

# What's in this library?
There are two parts to this library, the first is for a more traditional DAO
type interaction where one uses a handful of CRUD functions:
* `dao.insert()`
* `dao.read()`
* `dao.update()`
* `dao.delete()`

as well as a general `dao.execute()` to run arbitrary SQL against the database.

Using the built-in methods for CRUD provides some benefits such as being database agnostic,
providing optional "onFinish" callbacks functions, transaction logging (for custom replication).

The second part (BaseModelObject.cfc) adds a layer of ORM type functionality, plus more.

# Installation
Copy the "database" folder `(/src/com/database)` into your project (or into the folder you place your components)

# DAO Examples:
```javascript
// create instance of DAO - must feed it a datasource name
dao = new com.database.dao( dsn = "myDatasource" ); // note: dbtype is optional and defaults to MySQL
// Also note that if a default datasource was specified in Application.cfc you do not need to pass it in.
// If a default datasource was defined:
dao = new com.database.dao();

// Insert data (could have easily been a form scope or "rc" struct)
DATA = {
		"_id" = lcase(createUUID()),
		"first_name" = "Joe" ,
		"last_name" = "Shmo",
		"email" = "jshmo@blahblah.com",
		"created_datetime" = now()
	};

newID = dao.insert( table = "users", data = DATA );
// newID would contain the record's auto-incremented PK value

// DAO has a method queryParam() that wraps your values in
// appropriate cfqueryparam tags.  The method takes 4 args:
// value - required
// cfsqltype - optional, will be guessed based on value.  Uses
// common data type names, no need for the cf_sql_type... crap.
// list - true/false; will pass to cfqueryparam list attribute
// null - true/false; will pass to the cfqueryparam null attribute

// Insert data (using mysql specific replace into syntax )
newID2 = dao.execute("
	REPLACE INTO users (id, `_id`, first_name, last_name, email, created_datetime)
	VALUES ( 1
			,#dao.queryParam(lcase(createUUID()),'varchar')#
			,#dao.queryParam('john')#
			,#dao.queryParam('deere')#
			,#dao.queryParam('jdeere@tractor.com')#
			,#dao.queryParam(now(), 'timestamp')#
		   )
");
// newID2 would also contain the record's new PK value
// This is true for insert and replace statements only.

// You can also use $queryParam()$, which will be evaluated at runtime (as aposed to compile time)
// This is helpful if your SQL is persisted in storage and later read and executed.

// Another param option is to pass in named params.  Named params take the signature of:
//   :paramName{type="datatype",null=true/false,list=true/false} 
// And you pass in a struct containing the named parameters and values.  You do not need
// to provide any of the optional properties, dao can guess these for you.  This means you could
// simply do: :paramName and not supply the {...} parts.
// Below is how the previous
// example would look using named params (using various forms of the named param syntax):
newID2 = dao.execute("
	REPLACE INTO users (id, `_id`, first_name, last_name, email, created_datetime)
	VALUES ( 1
			,:uuid
			,:firstName{type='varchar'}
			,:lastName{}
			,:email{null=false}
			,:createDate{type='timestamp'}
	)",
	{ 
		uuid = lcase( createUUID() ), 
		firstName = 'john', 
		lastName = 'deere', 
		email = 'jdeere@tractor.com', 
		createDate = now() }
);
// Notice that :lastName{} could have been written as :lastName or :lastName{type='varchar'}, etc...
// Not shown above, but you can also use the list parameter to indicate a list for IN() type statements.

// Return all records in a table
users = dao.read( "users" );

// Return all records using SQL - and cache it
users = dao.read(
	sql = "SELECT first_name, last_name FROM users",
	cachedWithin = createTimeSpan(0,0,2,0)
);

// Using named parameters
users = dao.read("
	SELECT first_name, last_name 
	FROM users
	WHERE last_name IN( :lastNameList )
	AND first_name like :firstName
",
{ lastNameList : 'deere,doe', firstName : 'jo%' } );
// This will return all users with the last name of either 'deere' or 'doe' and 
// where their first name starts with JO.
// NOTE: for list parameters you can also pass in an array:
// ... lastNameList : [ 'deere', 'doe' ]....
````

# DAO Query Return Types
With the DAO `read()` function you can return data as a __Query__ object, a __Array of Structs__ or a __JSON__ string.
See example below:
```javascript
users = dao.read( sql = "
		SELECT first_name, last_name 
		FROM users
		WHERE last_name IN( :lastNameList )
		AND first_name like :firstName
	",
	params = { lastNameList : 'deere,doe', firstName : 'jo%' }, 
	returnType = "JSON" 
);
// This would return a string similar to:
// [{"first_name" : "john", "last_name" : "deere" }, {"first_name" : "joe", "last_name" : "deere" }]
//
// Other options are "Array" or "Query".  If not specified "Query" will be used.
```
# Query Params
As described above, there are several ways to parameterize your values (for performance and security reasons you should always parameterize values passed into SQL).  Each method ultimately results in the same thing, but has a slightly different path.  Which method you choose will largely depend on vanity more than practicality.  The methods are:
* Inline call to queryParam()
```javascript
user = dao.read("
	SELECT * FROM users
	WHERE userID = #dao.queryParam( value = myUserIdVariable, type = 'int', list = false, null = false )#
");
```
This method evaluates the parameters at compile time, so in the above example `myUserIdVariable` must already exist.
* Inline placeholders - $queryParam()$
```javascript
user = dao.read("
	SELECT * FROM users
	WHERE userID = $queryParam( value = myUserIdVariable, type = 'int', list = false, null = false )$
");
```
This method will evaluate the parameters at runtime.  This means that in the above, `myUserIdVariable` doesn't get evaluated until the query is run.  This allows parameterized SQL to be stored in a file, or database and executed later.  It also allows building parameterized SQL strings that refer to variables that don't exist in the current context, but is then passed into a method that will have those variables.  Contrived example:
```javascript
sql = "SELECT * FROM users 
WHERE userID = $queryParam( value = myUserIdVariable, type = 'int', list = false, null = false )$";
someFunction( sql );

function someFunction( sql ){
	myUserIdVariable = 1;
	dao.read( sql );
}
```
* Named parameters - :paramName{ options }
```javascript
user = dao.read("
	SELECT * FROM users
	WHERE userID = :userId{ type = 'int' }
",
{ userId: myUserIdVariable }
);

```
This method is sort of a hybrid of both the other methods.  It allows you to have stored SQL (read from file/db, pieced together during request, etc...) with named parameters.  The difference is that you will pass in the actual parameter values as an argument to `dao.read()` or `dao.execute()` so the parameters are evaluated at compile time then injected at runtime.  The named parameter as described before, can either be `:nameOfParam` by itself and the datatype will be guessed, or can be `:nameOfParam{ options }` to include the options.

Each method takes the following options:
* `value` - the value of the parameter
* `type` - the data type of the parameter (can be adobe's cf_sql_{type} or equivilent shorthand ):
 - cf_sql_double __or__ double
 - cf_sql_bit __or__ bit
 - cf_sql_bigint
 - cf_sql_bit
 - cf_sql_char
 - cf_sql_blob
 - cf_sql_clob
 - cf_sql_date __or__ datetime,date
 - cf_sql_decimal __or__ decimal
 - cf_sql_double
 - cf_sql_float
 - cf_sql_idstamp
 - cf_sql_integer __or__ int,integer,numeric,number,
 - cf_sql_longvarchar
 - cf_sql_money __or__ money
 - cf_sql_money4
 - cf_sql_numeric
 - cf_sql_real
 - cf_sql_refcurs__or__
 - cf_sql_smallint
 - cf_sql_time
 - cf_sql_timestamp __or__ timestamp
 - cf_sql_tinyint
 - cf_sql_varchar __or__ varchar,char,text,memo,nchar,nvarchar,ntext
* `list` - True/False.  If the value is a list to be included in an IN() clause.  If true, the __value__ argument can either be a string list or an array.
* `null` - True/False.  If true, the __value__ is considered null.

# Query of Queries
With DAO you can also query an existing query result.  Simply pass the query in as the QoQ argument ( struct consisting of `name_to_use` = `query_name` ), then write your SQL as if you would normally write a query of queries.
```javascript
users = dao.read("users");
johns = dao.read( sql = "
		SELECT first_name, last_name 
		FROM userQuery
		WHERE lower(first_name) = :firstName
	",
	params = { firstName : 'john' }, 
	returnType = "Array",
	QoQ = { userQuery : users}
);
```

# Entity Queries
New as of version 0.0.57 ( June 6, 2014 ) you can now perform LINQ'ish queries via dao.cfc.  This allows you
to build criteria in an OO and platform agnostic way.  This will also be the only query language available
when communicating with a non-RDBMS data store (i.e. couchbase, mongoDB, etc...)
Here's an example of how to use this new feature:
```javascript
// build the query criteria
var query = request.dao.from( "eventLog" )
					.where( "eventDate", "<", now() )
					.andWhere( "eventDate", ">=", dateAdd( 'd', -1, now() ) )
					.beginGroup("and")
						.andWhere( "ID", ">=", 1)
						.beginGroup("or")
							.andWhere( "event", "=", "delete")
							.orWhere( "event", "=", "insert")
						.endGroup()
					.endGroup()
					.orderBy("eventDate desc")
					.run(); // the run() method executes the query and returns a query object.  If you don't
							// run() then it returns the dao object, which you can later use to add to the
							// criteria, or run at your leasure.

for( var rec in query ){
	//do something with the record
}
```
The MySQL generated from the above example would look something like:
```sql
SELECT `description`, `event`, `eventdate`, `ID`
FROM eventLog
WHERE `eventDate` < ?
AND `eventDate` >= ?
AND ( `ID` >= ? OR ( `event` = ? OR `event` = ? ) )
ORDER BY eventDate desc
```

You can also specify the desired return type (supports the same return types as `read()`: __Query__, __Array__, __JSON__).  
To do so, simply call the .returnAs() method in the chain, like so:
```javascript
var query = dao.from( "eventLog" )
				.where( "eventDate", "<", now() )
				.returnAs('array')
				.run();
```

This new syntax will provide greater separation of your application layer and the persistence layer as it deligates
to the underlying "connector" (i.e. mysql.cfc) to parse and perform the actual query.

# The ORM'sh side of DAO
The second part of this library is an ORM'sh implementation of entity management.  It internally uses the
dao.cfc (and dbtype specific CFCs), but provides an object oriented way of playing with your model.  Consider
the following examples:

```javascript
// create instance of dao ( could be injected via your favorite DI library )
dao = new dao( dsn = "myDatasource" );

// Suppose we have a model/User.cfc model cfc that extends "BaseModelObject.cfc"
user = new model.User( dao );

// Create a new user named john.
user.setFirstName( 'john' );
user.setLastName( 'deere' );
user.setEmail('jdeere@tractor.com');

// Save will insert the new record because it doesn't exist.
// If we had loaded the entity with a user record, it would perform an update.
user.save();

// So the entity has been persisted to the database.  If we wanted
// to at this point, we could use the user.getID() method to get the
// value of the newly created PK.  Or we could do another update
user.setFirstName('Johnny');
user.save(); // Now the entity has been "updated" and persisted to the databse.

// Now, to load data into an entity it's as simple as:
user = new model.User( dao );
user.load(1);  // assuming our record's ID == 1

// We can also do crazy stuff like:
user.loadByFirstNameAndLastName('Johnny', 'deere');
// Every property/field in the entity can be included in this dynamic load function
// just prefix the function name as "loadBy" and delimit the field name criteria by "And"
user.loadByFirstNameAndLastNameAndEmailAndIDAndCreatedDate(....);

// A model entity can also be used to load collections, not just a single member
user = new model.User( dao );
users = user.loadAll(); // <--- returns array of intitialized entity objects - one for each record

// you can also filter using the dynamic load function
users = user.loadAllByFirstName('Johnny');

// there is also a list function that will return a query object
users = user.list( where = "FirstName = 'Johnny' ");

// Even more coolness. We can return the entity (or collection) as an array, or JSON, or struct!
user.toStruct();
user.toJSON(); // <--- know that this is not the ACF to JSON crap, it's real serialized JSON.

// Collection return types
users = user.listAsArray( where = "FirstName = 'Johnny' ");
users = user.listAsJSON( where = "FirstName = 'Johnny' ");

```
That's the very basics of Entity management in DAO.  It get's real interesting when you start playing with
relationships.  By-in-large I have adopted the property syntax used by CF ORM to define
entity properties and describe relationships.  Example:

```javascript
/* Pet.cfc */
component persistent="true" table="pets" extends="com.database.BaseModelObject" accessors="true" {

	property name="ID" type="numeric" fieldtype="id" generator="increment";
	property name="_id" fieldtype="id" generator="uuid" type="string" length="45";
	property name="userID" type="numeric" sqltype="int";
	property name="firstName" type="string" column="first_name";
	property name="lastName" type="string" column="last_name";
	property name="createdDate" type="date" column="created_datetime";
	property name="modifiedDate" type="date" column="modified_datetime" formula="now()";

	/* Relationships */
	property name="user" inverseJoinColumn="ID" cascade="save-update" fieldType="one-to-one" fkcolumn="userID" cfc="model.User";
	property name="offspring" type="array" fieldType="one-to-many" singularname="kid" fkcolumn="offspringID" cfc="model.Offspring";

	public string function getFullName(){
		return variables.firstName & " " & variables.lastName;
	}
}
```
When in development you can have dao create your tables for you by passing the dropcreate = true to the initializer.  Exmaple:
```javascript
	user = new User( dao = dao, dropCreate = true );
```
This will inspect your CFC properties and create a table based on those details.  This supports having different property names vs column names, table names, data types, etc...

The "Pet.cfc" above would create a table named `pets` with an auto incrementing PK name `ID`, a "varchar(45)" `_id` field, a `userID` field with the type "Int"
varchar fields named `first_name` and `last_name` a datetime field named `created_datetime` and a datetime field named `modified_datetime`.

* The _id field, will automatically generate a UUID value when a record is first created because we specified a generator UUID.
* The getters/setters for first_name, last_name, craeted_datetime, modified_datetime would be:
  * get/setFirstName();
  * get/setLastName();
  * get/setCreatedDate();
  * get/setModifiedDate();
* The modifiedDate will update with the evaluated value of "now()" each time the data is updated.
* The dynamic load statements respect the name/column differences, so the loadByFirstName("?") will essentially translate to "first_name = ?"

## Entity Events
BaseModelObject supports the same ORM entity events as Adobe ColdFusion does:

* preLoad(): This method is called before the load operation or before the data is loaded from the database.
* postLoad(): This method is called after the load operation is complete.
* preInsert(): This method is called just before the object is inserted.  __If anything is returned it will abort the insert__.
* postInsert(): This method is called after the insert operation is complete.
* preUpdate(BaseModelObject oldData): This method is called just before the object is updated. A struct of old data is passed to this method to know the original state of the entity being updated.  __If anything is returned it will abort the update__.
* postUpdate(): This method is called after the update operation is complete.
* preDelete(): This method is called before the object is deleted.  __If anything is returned it will abort the delete__.
* postDelete(): This method is called after the delete operation is complete.

> Each event also receives the current entity as an argument.  This is important for injected event handlers as it allows you to get/set properties on the current entity within the handler.

These can be defined within a CFC, or injected after the fact.  Examples:
```javascript
	// Entity CFC
	component extends="com.database.BaseModelObject"{
		...
		function preInsert( entity ){
			//do something.
			if(  entity.getSomeKey() == false ){
				return false;
			}
		}
	}
	// Alternative: Inject Event Handler
	user = new com.database.BaseModelObject( "user" );
	user.preInsert = function( entity ){
		if( entity.getSomeKey() == false ){
			return false;
		}
	}
```

## Dynamic Entities
Sometimes it's a pain in the arse to create entity CFCs for every single table in your database.  You must create properties for each field in the table, then keep it updated as your model changes.  This feature will allow you to define an entity class with minimal effort.  Here's an example of a dynamic entity CFC:
```javascript
/* EventLog.cfc */
component persistent="true" table="eventLog" extends="com.database.BaseModelObject"{
}
```
That's all we *need*.  Now say I created a table named eventLog in my databse with the following:
```sql
CREATE TABLE `eventLog` (
  `ID` int(11) NOT NULL AUTO_INCREMENT,
  `event` varchar(100) DEFAULT NULL,
  `description` text,
  `eventDate` datetime DEFAULT NULL,
  PRIMARY KEY (`ID`)
);
```
When I instantiate the EventLog.cfc with:
```javascript
eventLog = new model.EventLog( dao = dao );
```
I'll get an instance of EventLog as if the CFC had included the following properties:
```javascript
property name="ID" fieldtype="id" generator="increment";
property name="event" type="string";
property name="description" type="string";
property name="eventDate" type="date";
```
To make this work, just make sure you set the table attribute to point to the actual table in the database, extend BaseModelObject and set the persistent=true.  When you then create an instance of that CFC, the table (eventLog in the above example) will be examined and all the fields in that table will be injected into your instance - along with all the getters/setters.  This even works with identity fields (i.e. Primary Keys) and auto generated (i.e. increment) fields.

You can also mix and match.  You can statically define properties:
```javascript
component persistent="true" table="eventLog" extends="com.database.BaseModelObject" accessors="true"{
	property name="description" type="string";
}
```
And DAO will just inject the rest of the columns.  This is handy in cases where your table definition has been altered (i.e. new fields) as they will automatically be included.  For anything more than straight table entities (i.e. you need many-to-many relationships, formulas, custom validation, etc...) you still need to declare those properties in the CFC.  You also must statically define properties where you want the property name to be different than the table's column name. (NOTE: the DAO is smart enough to check for both when injecting properties)

### Dynamic Entity - A step further
In some cases it may best to create entity CFCs that extend BaseModelObject, but... for dynamic entities you don't necessarily have to.  Here's what we could have done above without having to create EventLog.cfc:
```javascript
eventLog = new com.database.BaseModelObject( dao = dao, table = 'eventLog' );
```
That would have returned an entity instance with all the properties from the eventLog table.  It will also attempt to auto-wire related entities ( which is not an exclusive feature of dynamic entities itself, but a feature of any object that extends BaseModelObject : See more below about dynamic relationships ).

Now, if you are on CF10+ or Railo 4.x and you have a default datasource setup in Application.cfc (this.datasource) you can omit the dao argument:
```javascript
eventLog = new com.database.BaseModelObject( 'eventLog' );
```
However, doing so will create a new instance of DAO for each instance of BaseModelObject.  It is often more peformant to create a singleton instance and store it in a global scope, then pass that in.

## Relationships
In the example above, Pet.cfc defines a one-to-one relationship with the user.  This will automatically load the correct "User" object into the Pet object
when the Pet object is instantiated.  If none exists it will load an un-initialized instance of User.  When a save is performed on Pet, the User
is also evaluated and saved (if any changes were detected ).

One can also identify one-to-many relationships. This will also auto-load and "cascade" save unless told otherwise via the "cascade" attribute. This type of
relationship creates an Array of whatever object it is related to, and adds the `add<Entity Name>()` method to the instance so you can add instances to the array.  Notice in
our Pets.cfc example we define a one-to-many relationship of "offspring" which maps to "model.Offspring".

## Dynamic Relationships
Now, I'm lazy, so wiring up relationships is kind of a bother.  Many times we're just working with simple one-to-many or many-to-one relationships.  Using a convention over configuration approach, this lib will look for and inject related entities when the object is loaded.  So, if you have an "orders" table, that has a "customers_ID" field which is a foriegn key to the "customers" table, we can automatically join the two when you load the "orders" entity.  This can also be configured to use a custom naming convention by passing in the `dynamicMappingFKConvention` property during init, or setting it afterwards.  See:
### MANY-TO-ONE Relationship
```javascript
var order = new com.database.BaseModelObject( dao = dao, table = 'orders');
order.load(123); // load order with ID of 123
writeDump( order.getCustomers().getName() );
// ^ If the customers table has a field named "name" this writeDump will
// output the customer name associated with order 123

// If the naming convention is tableId instead of table_ID you can specify this as:
order.setDynamicMappingFKConvention('{table}Id');
// The keyword {table} will be replaced at runtime to reflect the actual table name.
// This could also be set during init as"
var order = new com.database.BaseModelObject( dao = dao, table = 'orders', dynamicMappingFKConvention = '{table}Id');
```
### ONE-TO-MANY Relationship
Now say you you have an order_items table that contains all the items on an order ( realted via order_items.orders_ID ( adheres to the `dynamicMappingFKConvention` property described above ) ).  Using the same ```order``` object created above, we could do this:
```javascript
writeDump( order.getOrder_Items() );
```
That would dump an array of "order_item" entity objects, one for each order_items record associated with order 123.  Note that we didn't need to create a single CFC file, or define any relationships, or create any methods.  Sometimes, however, you don't want the objects.  You just need the data in a struct format.
```javascript
writeDump( order.getOrder_ItemsAsArray() );
```
That will dump an array of struct representation of the order_items associated with order 123.  Awesome, I know.  However, when writing an API, you sometimes need just JSON:
```javascript
writeDump( order.getOrder_ItemsAsJSON() );
```
There you have it.  A JSON representation of your data.  Ok, now say you just want to retrieve order 123 and return it, and all of it's related data as a struct.  This is a little trickier since the dynamic relationships need to know something about your related data.  We achieved that above by using the table name and return types in the method call ( get `Order_Items` as `JSON` ).  If you just want to load the data and return it with all child data, you need to define what you want back:
```javascript
order.hasMany( 'order_items' );
order.toStruct();// or order.toJSON();
```
The `hasMany` method can also specify the primary key ( if other than `<table>_ID` ), and an alias for the property that is injected into the parent.  So if you wanted to reference the `order_items` as say, `orderItem` you could do this:
```javascript
order.hasMany( table = 'order_items', property = 'orderItems' );
order.getOrderItems().toStruct();
```
In addition, the `hasMany` method can take a `where` argument that is used to filter the child entities.  For instance, if you have a column in your order_items table called `status`, in which the value 1 means it's active and 99 means it's deleted you could define your hasMany relationship like:
```javascript
order.hasMany( table = 'order_items', property = 'orderItems', where = 'status != 99' );
order.getOrderItems().toStruct();
```
This would only return "active" order_items.

The `hasMany` method is great for defining one-to-many relationships that can't be/aren't defined by naming conventions, but there's also a way to define many-to-one relationships in this manner; the `belongsTo` method.
```javascript
order.belongsTo( table = 'customers', property = 'company', fkField = 'customerID' );
writeDump( order.getCompany() );
```
This may not be as useful as the `hasMany` method, as these many-to-one relationships can easily be defined using dynamicMappings (discussed below), but it can bind these relationships after the entity has been loaded, where dynamicMappings occur during load.

##Dynamic Mappings/Aliases
Now, there are also ways to create user friendly aliases for your related entity properties.  You do this by supplying the optional `dynamicMappings` argument to the BaseModelObject's init method.  The dynamicMappings argument expects a struct containing `key` and `value` pairs of mappings wher the `key` is the desired property name for one-to-many or column name for many-to-one relationships and the `value` is the actual table name (or a struct, explained later).

So for instance if you would rather use orderItems instead of order_items you could pass in the "dynamicMappings" argument to the init method.
```javascript
dynamicMappings = { "orderItems" = "order_items" };
order = new com.database.BaseModelObject( dao = dao, table = 'orders', dynamicMappings = dynamicMappings );
order.load( 123 );
writeDump( order.getOrderItems() );
```
That would dump an array of entities representing the `order_items` records that are related to the order #123

The above is a simple mapping of property name to a table - a one-to-many relationship mapping.  We can also specify mappings to auto-generate relationships using a non-standard naming convention.  As mentioned previously, the auto-wiring of many-to-one relationships happens if we encounter a field/property named `<table>_ID`.  However, sometimes you may have a field tha doesn't follow this pattern.  If you do, you can specify it in mappings and we'll auto-wire it with the rest.  For example, say you have a `customers` table which has a `default_payment_terms` field that is a FK to a table called `payment_terms`, here's how we could handle that with simple dynamicMappings:
```javascript
dynamicMappings = { "default_payment_terms" = "payment_terms" };
order = new com.database.BaseModelObject( dao = dao, table = 'orders', dynamicMappings = dynamicMappings );
order.load( 123 );
writeDump( order.getDefault_Payment_Terms() );
```
There you have it.  This would dump the payment_terms entity that was related to the default_payment_terms value.  But, what if you don't want the property to be called default_payment_terms?  Simple, we can supply a struct as the `value` part of the mapping.  The struct consists of two keys: `table` and `property`.  So, if we wanted the `defualt_payment_terms` to be `defaultPaymentTerms` all we'd have to do is:
```javascript
dynamicMappings = { "default_payment_terms" = { table = "payment_terms", property = "defaultPaymentTerms" } };
order = new com.database.BaseModelObject( dao = dao, table = 'orders', dynamicMappings = dynamicMappings );
order.load( 123 );
writeDump( order.getDefaultPaymentTerms() );
```
This will dump the exact same as the previous example.  This is only necessary on many-to-one relationships.

__NOTE:__ It is also important to note that the dynamicMappings are passed into any object instantiated during the load() method.  So if you have a dynamicMapping on the order entity, when you load it and it crawls through auto-wiring the order_items, customers, etc... it will apply the same mappings throughout.  So as the example above, the property `defaultPaymentTerms` would be used anytime a property/column named `default_payment_terms` was encoutnerd.
Here's an example of a more real-world dynamicMapping:
```javascript
dynamicMappings = {
	"company" = "customers",
	"users_ID" = { "table" = "users", property = "User" },
	"orderItems" = "order_items",
	"default_payment_terms" = "payment_terms",
	"default_locations_ID" = { "table" = "locations", "property" = "defaultLocation" },
	"primary_contact" =  { "table" = "contacts", "property" = "primaryContact" }
};
order = new com.database.BaseModelObject( dao = dao, table = 'orders', dynamicMappings = dynamicMappings );
order.load( 123 );
writeDump( order.getCompany().getUser() );
```
###Dynamic Relationship Best Practices
Although you can definitely define your relationships on the fly using naming conventions, the dynamicMappings property, and hasMany/belongsTo methods it may not always be the best practice.  Take for example the code snippet above where we are setting all of those dynamic mappings.  It's likely that everywhere you need the `order` entity you'll probably want those mappings to exist (and be consistent).  To accomplish this you'll want a hybrid aproach using a facade CFC.  Here's a sample of how that could look:

__Order Entity Facade: model/Order.cfc__
```javascript
/**
* I define relationships and preset defaults for the orders entity
**/
component accessors="true" output="false" table="orders" extends="com.database.BaseModelObject" {

	public any function load(){
		// For convenience, we'll just pump in the dao here (pretend it lives in the application scope)
		setDAO( application.dao );

		// Define alias mappings.  This needs to happen before the entity is loaded, because the
		// load method needs this mapping to build the entity relationships.
		setDynamicMappings({
			"company" = "customers",
			"users_ID" = { "table" = "users", property = "User" },
			"orderItems" = "order_items",
			"default_payment_terms" = "payment_terms",
			"default_locations_ID" = { "table" = "locations", "property" = "defaultLocation" },
			"primary_contact" =  { "table" = "contacts", "property" = "primaryContact"
		});

		// Now load the entity, passing any args that we were given
		super.load( argumentCollection = arguments );

		// Now that the entity is loaded, we can identify any many-to-one relationships with the hasMany function
		this.hasMany( table = "order_items", fkcolumn = "orders_ID", property = "orderItems", where = "status != 99" );

		return this;
	}
}
```
With the above, I can simply instantiate the Order entity like so:
```javascript
order = new model.Order();
writeDump( order.getCompany().getUser() );
writeDump( order.getOrderItems() );
```

## lazy loading
If you are fortunate enough to be on Railo 4x or ACF10+ you can take advantage of lazy loading.  This dramatically improves performance when loading entities with a lot of related
entities, or are loading a collection of entities that have related entities.  What it will do is load the parent entity and "overload" the getters methods of the child entities
with a customized getter that will first instantiate/load the child object, then return it's value.  This way, only child entities that are actually used/referenced will be loaded.

To lazy load, you simply use the dynamic load method, prefixed with "lazy"
```javascript
pet = new Pet( dao ).lazyLoadAll();
// then, if I only need the first name of the "user" for the second pet I'd just:
ownerName = pet[2].getFirstName();  // That would trigger the "load" on only the that pet's user object.
```
# oData
Any of your BaseModelObject entities can produce and/or consume [oData](http://www.odata.org/).  OData (`Open Data Protocol`) is (according to the official site) _" an OASIS standard that defines the best practice for building and consuming RESTful APIs."_.  Basically it is a protocol to communicate model interactions between the front-end and back-end.  This allows you to use front-end libraries/oData Clients such as [BreezeJS](http://www.getbreezenow.com/) to build RESTFul APIs without having to duplicate your model on the client.  See [examples/breezejs/README.md](examples/breezejs) for a sample BreezeJS app that uses Taffy/BaseModelObject to create a simple TODO app (specifically `/examples/breezejs/api/resources/`).

Currently we support the following oData methods:

* __getODataMetaData__ - Returns oData metadata that describes the current entity ( for oData $metadata endpoint )
* __listAsOData__ - Returns a list of the requested collection (filtered/ordered based on query args) in an oData format.
```javascript
// FROM BREEZEJS SAMPLE: Taffy Resource for "get" verb to return an array of items matching the oData formated filter criteria
remote function get(string $filter = "" ,string $orderby = "", string $skip = "", string $top = ""){
	var todo = new com.database.BaseModelObject( table = "TodoItem" );

	return representationOf(
    	//returns an oData object containing all of the matching entities in our DB
		todo.listAsoData(
				filter = arguments.$filter,
				orderby = arguments.$orderby,
				skip = arguments.$skip,
				top = arguments.$top,
	            excludeKeys = [ "_id", "other_field_you_want_to_hide" ]
			)
		).withStatus(200);

}
```
* __toODataJSON__ - Convenience function to return JSON representation of the current entity with additional oData keys.
* __oDataSave__ - Accepts an array of oData entities and perform the appropriate DB interactions based on the metadata and returns the Entity struct with the following:
 * 	__Entities__: An array of entities that were sent to the server, with their values updated by the server. For example, temporary ID values get replaced by server-generated IDs.
 * 	__KeyMappings__: An array of objects that tell oData which temporary IDs were replaced with which server-generated IDs. Each object has an EntityTypeName, TempValue, and RealValue.
 * 	__Errors__ (optional): An array of EntityError objects, indicating validation errors that were found on the server. This will be null if there were no errors. Each object has an ErrorName, EntityTypeName, KeyValues array, PropertyName, and ErrorMessage.
 ```javascript
 // FROM BREEZEJS SAMPLE: Taffy Resource for "post" verb to save one or more "TodoItem" records.
	remote function post(){
		var todo = new com.database.BaseModelObject( table = "TodoItem" );
		var ret = todo.oDataSave( arguments.entities );
		return representationOf( ret ).withStatus(200);
	}
 ```


# More examples
Check out the daotest.cfm and entitytest.cfm files for a basic examples of the various features.

# Railo Notes
In order to use the DAO caching options with Railo you'll need to enable a default cache in the Railo Administrator.  Otherwise you'll end up with an error like: `there is no default object cache defined, you need to define this default cache in the Railo Administrator`
Simply create a _"RamCache"_ (for some reason EHCache throws NPE) type Cache service under `Services > Cache` and set it to be the default for Object caches.  The default can also be set per app using Application.cfc by adding:
```javascript
this.cache.object = "your_cache_name_here";
```
> NOTE: DAO Caching is experimental and does not currently work well with dynamic relationships.

Also, the "Preserve single quotes" setting must be checked in the Railo admin.  DAO specifically passes the SQL strings through ```preserveSingleQuotes()```, but this doesn't seem to work unless you have that setting checked under `Services > Datasources`.
