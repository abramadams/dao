component extends="taffy.core.resource" taffy_uri="breeze/todos/SaveChanges" {
	
	dao = new com.database.dao( dsn = "dao" );

	remote function post(){
		//writeDump(arguments);abort;
		var todo = new model.TodoItem( dao = dao );				
		
		for (var entity in arguments.entities ){
			todo.load( entity.ID );
			if( entity.entityAspect.EntityState == "Deleted" ){
				todo.delete();
			}else{				
				//writeDump(todo);
				todo.setDescription( entity.description );
				todo.setIsDone( entity.isDone ? true : false );
				todo.setIsArchived( entity.isArchived ? true : false );		
				//todo.setCreatedAt( entity.createdAt );
				
				//writeDump(todo);
				todo.save();
				//writeDump(todo);abort;
				//writeDump(entity);abort;
			}
		}


		return noData().withStatus(200);
		//return representationOf( todo.listAsBreezeData() ).withStatus(200);

	}
}
