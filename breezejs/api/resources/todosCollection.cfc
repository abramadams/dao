component extends="taffy.core.resource" taffy_uri="breeze/todos/Todos" {
	
	dao = new com.database.dao( dsn = "dao" );

	remote function get(string $filter = "" ,string $orderby = ""){
		
		//var todo = new model.TodoItem( dao = dao );	
		var todo = new com.database.BaseModelObject( dao = dao, table = "TodoItem");

		return representationOf( todo.listAsBreezeData( filter = arguments.$filter, orderby = arguments.$orderby ) ).withStatus(200);

	}
}
