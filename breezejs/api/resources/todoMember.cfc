component extends="taffy.core.resource" taffy_uri="breeze/todos/SaveChanges" {
	
	dao = new com.database.dao( dsn = "dao" );

	remote function post(){
		//writeDump(arguments);abort;
		var todo = new model.TodoItem( dao = dao );				
		
		for (var entity in arguments.entities ){
			todo.load( entity.ID );
			//writeDump(todo);
			todo.setDescription( entity.description );
			todo.setIsDone( entity.isDone );
			todo.setIsArchived( entity.isArchived );
			//todo.setCreatedAt( entity.createdAt );
			todo.save();
			//writeDump(todo);
			//writeDump(entity);abort;
		}


		return noData().withStatus(200);
		//return representationOf( todo.listAsBreezeData() ).withStatus(200);

	}
}
