component extends="taffy.core.resource" taffy_uri="breeze/todos/SaveChanges" {
	
	dao = new com.database.dao( dsn = "daoSQL", dbtype = "mssql" );

	remote function post(){
		
		//var todo = new model.TodoItem( dao = dao );
		var todo = new com.database.BaseModelObject( dao = dao, table = "TodoItem");
				
		var ret = todo.breezeSave( arguments.entities );
		
		return representationOf( ret ).withStatus(200);

	}
}