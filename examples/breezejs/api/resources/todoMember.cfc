component extends="taffy.core.resource" taffy_uri="breeze/todos/SaveChanges" {

	remote function post(){

		//var todo = new model.TodoItem( dao = dao );
		var todo = new com.database.Norm( dao = application.dao, table = "TodoItem");

		var ret = todo.oDataSave( arguments.entities );

		return representationOf( ret ).withStatus(200);

	}
}