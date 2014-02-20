component extends="taffy.core.resource" taffy_uri="breeze/todos/Todos" {
	
	dao = new com.database.dao( dsn = "daoSQL", dbtype = "mssql" );

	remote function get(string $filter = "" ,string $orderby = "", string $skip = "", string $top = ""){
		
		//you could have a entity CFC and invoke such as:
  		//var todo = new model.TodoItem( dao = dao );	
    	//or just invoke the BaseModelObject and point it at a table
		var todo = new com.database.BaseModelObject( dao = dao, table = "TodoItem");

		return representationOf( 
        //returns a breeze object containing all of the matching entities in our DB
				todo.listAsBreezeData( 
						filter = arguments.$filter, 
						orderby = arguments.$orderby, 
						skip = arguments.$skip, 
						top = arguments.$top
					) 
				).withStatus(200);

	}
  
  remote function post(){
    /*****************************
    * Initialize Sample Table/Data
    ******************************/
    
    // create instance o fthe TodoItem entity CFC.  This will create the table in the database
    // if it does not already exist
    todoItem = new model.TodoItem( dao = dao );
    // if there is any data present in the TodoItem table, delete it
    dao.delete("TodoItem","*");
    
    // now we'll add in our sample data
    todoItem.setDescription('Food');
    todoItem.setIsArchived(true);
    todoItem.setIsDone(true);
    todoItem.save();
    
    //todoItem = new model.TodoItem( dao = dao );
    todoItem.setID(0);
    todoItem.setDescription('Water');
    todoItem.setIsArchived(true);
    todoItem.setIsDone(true);
    todoItem.save();
    
    //todoItem = new model.TodoItem( dao = dao );
    todoItem.setID(0);
    todoItem.setDescription('Shelter');
    todoItem.setIsArchived(true);
    todoItem.setIsDone(true);
    todoItem.save();
    
    //todoItem = new model.TodoItem( dao = dao );
    todoItem.setID(0);
    todoItem.setDescription('Bread');
    todoItem.setIsArchived(false);
    todoItem.setIsDone(false);
    todoItem.save();
    
    //todoItem = new model.TodoItem( dao = dao );
    todoItem.setID(0);
    todoItem.setDescription('Cheese');
    todoItem.setIsArchived(false);
    todoItem.setIsDone(true);
    todoItem.save();
    
    //todoItem = new model.TodoItem( dao = dao );
    todoItem.setID(0);
    todoItem.setDescription('Wine');
    todoItem.setIsArchived(false);
    todoItem.setIsDone(false);
    todoItem.save();
  
    return representationOf( todoItem.listAsBreezeData( ) ).withStatus(200);
  }
}
