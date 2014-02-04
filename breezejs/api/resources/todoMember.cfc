component extends="taffy.core.resource" taffy_uri="breeze/todos/SaveChanges" {
	
	dao = new com.database.dao( dsn = "dao" );

	remote function post(){
		
		var todo = new model.TodoItem( dao = dao );				
				
		todo.breezeSave( arguments.entities );

		return noData().withStatus(200);

	}
}
