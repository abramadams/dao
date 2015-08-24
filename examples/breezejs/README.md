DAO/Norm Integration with Breeze.js 
===

This example application demonstrates the basic CRUD features provided by Breeze.js backed by the CFML library [DAO](https://github.com/abramadams/dao/tree/breezeJS). The server-side code to make this interaction work is surprisingly minimal.  For instance, to add, update or delete one or more records in the TodoItem table, one simply has to do this:

```javascript
  remote function someMethod() httpmethod="POST" restpath="/SaveChanges" produces="application/json"{
    var dao = new com.database.dao( dsn = "dao" );
    var todo = new com.database.Norm( dao = dao, table = "TodoItem");
    
    return todo.breezeSave( arguments.entities );   
  }
```

That's it.  No class (Value Object/Entity) CFCs, no crazy SQL.  To be fair, the table TodoItem has to exist, but that can be done with thesame library like this:

```javascript
    var dao = new com.database.dao( dsn = "dao" );
    var todo = new model.TodoItem( dao = dao );
```

Simple, right? This does require that you have a CFC named model/TodoItem.cfc and that it has the entity properties (see /model/TodoItem.cfc in this sample for an example)
   
It should be noted that the example `someMethod()` method above is not really how this sample is designed.  I opted to use the [Taffy](http://github.com/adamtuttle/Taffy) framework for my REST api instead of the built-in ColdFusion REST functionalty.  I believe the Taffy framework is much easier to work with than the native one, but it is not required to use the DAO library.  You just need to be able to respond to REST calls.  All the actual server-side code (i.e. non-library code) lives in the /api/resources folder (yup, three little files).  The rest are canned libraries or setup code (/api/Application.cfc sets up the Taffy framework, and /Application.cfc sets up the initial data but that's pretty much it).

Check out this sample on [runnable.com](http://runnable.com/UvQMOhwB3flbAAAw/breezejs-angularjs-todo-sample-with-coldfusion-backend-for-cfml-angular-js-todomvc-breeze-js-and-taffy) and play with the interface.  All model operations are initiated client-side by Breeze and persisted server-side by ColdFusion.

## So, how does it work?
Breeze.js uses a simple RESTful api to communicate model actions to and from a back-end server.  It caches data locally, provides a rich set of query functions for LINQ style data queries against the server or locally cached data, provides change tracking so changes can be queued and sent to the server in batch and much more.  The breeze.js library has many features, too many to list here so check out their [documentation](http://www.breezejs.com/) for a better sales pitch.

## Where does CFML come in?
CFML is a powerful language built on the JVM that allows very rapid development of any type of web application.  It has many features that allow you to easily bridge disparate systems out of the box.  One of the things it lacks however is a standard way to describe and communicate model schemas between systems.  Sure, we've got ORM, but nothing that binds the model to RESTFul APIs or the like.  If you want to share your data with another system (i.e. the browser/JavaScript) you need to mirror the server's model schema on the remote system and hand code all the interactions.  The DAO library aims to provide a standard way to communicate model schemas and data to other systems.  It does so by adopting the principals behind the Breeze.js project, which was originally developed to ineract with the oData protocol and the .Net WebAPI standards.  These work by using a pre-defined metadata schema that both ends speak.  The breeze.js client will request this metadata from the server and "consume" it, automatically generating a mirrored schema on the client.  The server, when asked for the metadata will "produce" the metadata that describes the schema (tables/entities, properties, validations, etc... ).

## Putting it all together
Basically, breeze sends a request to the server asking for the schema, DAO then builds that schema and sends it back as JSON.  Then breeze consumes the JSON and caches the model schema on the client.  Then breeze can query the server for data within that model, which is returned as a JSON object that is mapped to the originally fetched schema.  Breeze consumes that and updates it's local model with the changes from the server.   Then when the client data changes, breeze sends a post to the server with an array of entities that have changed (including information on what type of change, what exactly changed, what the original values were, etc...) as a JSON object.  DAO then consumes that JSON and performs the necessary actions on the data store and returns the entities with the saved values (plus any errors and new PK mappings) to breeze.

# About this example
This example was copied directly from [Todo-Angular sample](http://www.breezejs.com/samples/todo-angular).  The front-end JS/HTML/CSS has only changed slightly to point to the DAO for the breeze.js EntityManager "serviceName", and the title on the html page to include _(Backed by ColdFusion via DAO)_

The *new* code for this sample pertains to the back-end and resides in the `/api` folder, specifically in the `/api/resources` folder.  The rest of the CFML files are standard library files ([DAO](https://github.com/abramadams/dao/tree/breezeJS) and [Taffy](http://github.com/adamtuttle/Taffy))

## The dependancies and folder structure for this example
The example Todo app has the following folder structure:

* breezejs
	* api
		* resources `-- REST API -- produces and consumes breeze metadata to query and persist data to/from server`
		* taffy`-- Taffy REST framework`
	* assets `-- static assets (CSS)`
	* model `-- model CFC`
	* scripts `-- JavaScript Libraries`
		* app `-- JavaScript files for application`
* /src/com/dao `-- DAO framework`

Of all of the files, there's only a few that are specific to this example.  The rest are just standard library dependancies.  So the actual code involved in this project is boiled down to:

### CFML

* api/resources/
	* breezeMetaData.cfc `REST endpoint that "produces" the metadata`
	* todoMember.cfc `REST endpoint that persists changes made on the client to the server`
	* todosCollection.cfc `REST endpoint that returns data based on client requests`
* api/resources/Application.cfc `This is simply used to reset the sample data and "wire" up the TAFFY framework`

### JavaScript

* scripts/app/
	* controller.js `Angular.js view controller - handles view interaction`
	* dataservice.js `Angular.js factory that uses breeze.js to interact with the model (client and server)`
	* logger.js `Angular.js factor to display color-coded messages in "toasts" and to console`
	* main.js `Angular.js startup script creates the 'todo' module and its Angular directives`
