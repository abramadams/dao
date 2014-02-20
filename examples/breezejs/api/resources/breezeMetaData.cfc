component extends="taffy.core.resource" taffy_uri="breeze/todos/Metadata" {
	
	dao = new com.database.dao( dsn = "daoSQL", dbtype = "mssql" );

	remote function get(){

		//var todo = new model.TodoItem( dao = dao );	
		var todo = new com.database.BaseModelObject( dao = dao, table = "TodoItem");
		
		return representationOf( todo.getBreezeMetaData() ).withStatus(200);

	}
}
