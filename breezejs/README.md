=== DAO/BaseModelObject Integration with Breeze.js ===

This example application demonstrates the basic CRUD features provided by Breeze.js backed by a custom CFML library. The server-side code to make this nteraction work is surprisingly minimal.  For instance, to add, update or delete one or more records in the TodoItem table, one simply has to do this:

```javascript
  remote function get() httpmethod="POST" restpath="/SaveChanges" produces="application/json"{
    var dao = new com.database.dao( dsn = "dao" );
    var todo = new com.database.BaseModelObject( dao = dao, table = "TodoItem");
    
    return todo.breezeSave( arguments.entities );   
  }
```

That's it.  No class (Value Object/Entity) CFCs, no crazy SQL.  To be fair, the table TodoItem has to exist, but that can be done with thesame library like this:

```javascript
    var dao = new com.database.dao( dsn = "dao" );
    var todo = new model.TodoItem( dao = dao );
```

Simple, right? This does require that you have a CFC named model/TodoItem.cfc and that it has the entity properties (see /model/TodoItem.cfc in this sample for an example)
   
It should be noted that the example get() method above is not really how this sample is designed.  I opted to use the Taffy (http://github.com/adamtuttle/Taffy) framework for my REST api instead of the built-in ColdFusion REST functionalty.  I believe the Taffy framework is much easier to work with than the native one, but it is not required.  You just need to be able to respond to REST calls.  All the actual server-side code (i.e. non-library code) lives in the /api/resources folder (yup, three little files).  The rest are canned libraries or setup code (/api/Application.cfc sets up the Taffy framework, and /Application.cfc sets up the initial data but that's pretty much it).

Anyway, check out this sample on [runnable.com](http://runnable.com/UvQMOhwB3flbAAAw/breezejs-angularjs-todo-sample-with-coldfusion-backend-for-cfml-angular-js-todomvc-breeze-js-and-taffy) and play with the interface.  All model operations are initiated client-side by Breeze and persisted server-side by ColdFusion.