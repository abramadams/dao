component extends="taffy.core.resource" taffy_uri="breeze/todos/SaveChanges" {
	
	dao = new com.database.dao( dsn = "dao" );

	remote function post(){
		
		//var todo = new model.TodoItem( dao = dao );
		var todo = new com.database.BaseModelObject( dao = dao, table = "TodoItem");
				
		todo.breezeSave( arguments.entities );

		//return noData().withStatus(200);
		return representationOf( arguments.entities ).withStatus(200);

	}
}