dao - A ColdFusion library for easy Data Access and Object Mapping.
===

# Disclaimer
Though I have been using this library for many years on many, many projects, it has never been used or tested outside
of my control, so there are absolutely-positively things that are missing, and things that are just plain old broke.  There's also
a lot of ugly code in there, If you stumble on something, raise an issue (or submit a pull request :) )

Also, the bulk of the dao.cfc stuff was developed in CF7-8 erra, and has been patched CF9/10 features started creeping in.  I
am in the process of re-writing the library using the query.cfc and some other things that will break the pre-CF9 compatibility.
For instance, this will be re-written using all script based code.


# Introduction
The goal of this library is to allow one to interact with the database in a DB platform agnostic way,
while making it super easy.

There are two parts to this library, the first is for a more traditional DAO
type interaction where one uses a handful of CRUD functions:
* `dao.insert()`
* `dao.read()`
* `dao.update()`
* `dao.delete()`

as well as a general `dao.execute()` to run arbitrary SQL against the database.

Using the built-in methods for CRUD provides some benefits such as being database agnostic,
providing optional "onFinish" callbacks functions, transaction logging (for custom replication).

# Installation
Copy the "database" folder `(/src/com/database)` into your project (or into the folder you place your components)

# DAO Examples:
```javascript
	// create instance of DAO - must feed it a datasource name
	dao = new com.database.dao( dsn = "dao" ); // note: dbtype is optional and defaults to MySQL

	// Insert data (could have easily been a form struct)
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

	// Return all records in a table
	users = dao.read( "users" );

	// Return all records using SQL - and cache it
	users = dao.read(
		sql = "SELECT first_name, last_name FROM users",
		cachedWithin = createTimeSpan(0,0,2,0)
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

## Relationships
In the example above, Pet.cfc defines a one-to-one relationship with the user.  This will automatically load the correct "User" object into the Pet object
when the Pet object is instantiated.  If none exists it will load an un-initialized instance of User.  When a save is performed on Pet, the User
is also evaluated and saved (if any changes were detected ).

One can also identify one-to-many relationships. This will also auto-load and "cascade" save unless told otherwise via the "cascade" attribute. This type of
relationship creates an Array of whatever object it is related to, and adds the `add<Entity Name>()` method to the instance so you can add instances to the array.  Notice in
our Pets.cfc example we define a one-to-many relationship of "offspring" which maps to "model.Offspring".

## Dyanmic Relationships
Now, I'm lazy, so wiring up relationships is kind of a bother.  Many times we're just working with simple one-to-many or many-to-one relationships.  Using a convention over configuration approach, this lib will look for and inject related entities when the object is loaded.  So, if you have an "orders" table, that has a "customers_ID" field which is a foriegn key to the "customers" table, we can automatically join the two when you load the "orders" entity.  See:
### MANY-TO-ONE Relationship
```javascript
	var order = new com.database.BaseModelObject( dao = dao, table = 'orders');
	order.load(123); // load order with ID of 123
	writeDump( order.getCustomers().getName() );
	// ^ If the customers table has a field named "name" this writeDump will
	// output the customer name associated with order 123
```
### ONE-TO-MANY Relationship
Now say you you have an order_items table that contains all the items on an order ( realted via order_items.orders_ID ).  Using the same ```order``` object created above, we could do this:
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
The "hasMany" function can also specify the primary key ( if other than `<table>_ID` ), and an alias for the property that is injected into the parent.  So if you wanted to reference the `order_items` as say, `orderItem` you could do this:
```javascript
	order.hasMany( table = 'order_items', property = 'orderItems' );
	order.getOrderItems().toStruct();
```
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

# Requirements
Currently this library has been actively used and tested on Railo 4x, CF9 and CF10 (though the dao.cfc stuff should work with CF8 - for now).
There are some features that are disabled by default ( such as lazy loading child entities ), but can be "turned on" by un-commenting
a few lines if you are running on CF10+ or Railo 4+ (uses anonymous functions)

# Database Platform Agnostic
Currently there are two databases that are supported: MySQL and MS SQL.  Others can be added by
creating a new CFC that implements the necessary methods.  The CFC  name would then be the "dbtype"
argument passed to the init method when instantiating dao.cfc.  So if you have otherrdbs.cfc, you'd
instantiate as: dao = new dao( dbType = 'otherrdbs' );

# More examples
Check out the daotest.cfm and entitytest.cfm files for a basic examples of the various features.

