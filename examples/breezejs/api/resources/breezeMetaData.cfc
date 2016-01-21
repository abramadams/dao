component extends="taffy.core.resource" taffy_uri="breeze/todos/Metadata" {

	remote function get(){

		var todo = new com.database.Norm( dao = application.dao, table = "TodoItem");

		return representationOf( todo.getoDataMetaData( excludeKeys = [ "_id" ] ) ).withStatus(200);

	}
}
