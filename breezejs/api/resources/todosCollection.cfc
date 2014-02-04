component extends="taffy.core.resource" taffy_uri="breeze/todos/Todos" {
	
	dao = new com.database.dao( dsn = "dao" );

	remote function get(string $filter = "" ,string $orderby = ""){
		//writeDump(variables);abort;
		var todo = new model.TodoItem( dao = dao );	

		return representationOf( todo.listAsBreezeData( filter = arguments.$filter, orderby = arguments.$orderby ) ).withStatus(200);

	}
}
