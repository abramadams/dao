component extends="taffy.core.resource" taffy_uri="breeze/todos/Metadata" {
	
	remote function get(){

		//var todo = new model.TodoItem( dao = dao );	
		var todo = new com.database.BaseModelObject( dao = application.dao, table = "TodoItem");
		
		return representationOf( todo.getBreezeMetaData( excludeKeys = [ "_id" ] ) ).withStatus(200);

	}
}
