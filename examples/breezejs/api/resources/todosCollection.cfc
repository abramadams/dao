component extends="taffy.core.resource" taffy_uri="breeze/todos/Todos" {
	
	remote function get(string $filter = "" ,string $orderby = "", string $skip = "", string $top = ""){
		
		//you could have an entity CFC modeling your table and invoke it such as:
  		//var todo = new model.TodoItem( dao = dao );	
    	//or just invoke the BaseModelObject and point it at a table in the datasource (identified in dao)
		var todo = new com.database.BaseModelObject( dao = application.dao, table = "TodoItem");

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
    /**********************************************************************
    * Initialize Sample Table/Data
    * Normally you're data would be real, so you'd use a service for this.
    ***********************************************************************/
    
    // create instance of the TodoItem entity CFC.  This will create the table in the database
    // if it does not already exist
    todoItem = new model.TodoItem( dao = application.dao );
    // if there is any data present in the TodoItem table, delete it
    application.dao.delete("TodoItem","*");
    
    // now we'll add in our sample data
    todoItem.setDescription('Food');
    todoItem.setIsArchived(true);
    todoItem.setIsDone(true);
    todoItem.setCreatedAt( now() );
    todoItem.save();

    todoItem.clone();
    todoItem.setDescription('Water');
    todoItem.setIsArchived(true);
    todoItem.setIsDone(true);
    todoItem.save();

    todoItem.clone();
    todoItem.setDescription('Shelter');
    todoItem.setIsArchived(true);
    todoItem.setIsDone(true);
    todoItem.save();

    todoItem.clone();
    todoItem.setDescription('Bread');
    todoItem.setIsArchived(false);
    todoItem.setIsDone(false);
    todoItem.save();

    todoItem.clone();
    todoItem.setDescription('Cheese');
    todoItem.setIsArchived(false);
    todoItem.setIsDone(true);
    todoItem.save();

    todoItem.clone();
    todoItem.setDescription('Wine');
    todoItem.setIsArchived(false);
    todoItem.setIsDone(false);
    todoItem.save();
  
    return representationOf( todoItem.listAsBreezeData( ) ).withStatus(200);
  }
}
