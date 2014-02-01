component extends="taffy.core.resource" taffy_uri="breeze/todos/Metadata" {
	
	dao = new com.database.dao( dsn = "dao" );

	remote function get() {

		var todo = new model.TodoItem( dao = dao );

		return representationOf( todo.getBreezeMetaData() ).withStatus(200);

	}
}
