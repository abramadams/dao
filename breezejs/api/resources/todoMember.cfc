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
				todo.setDescription( entity.description );
				todo.setIsDone( entity.isDone ? true : false );
				todo.setIsArchived( entity.isArchived ? true : false );		
				//If createdAt was not populated in the entity record, populate it
				if( !len( trim( todo.getCreatedAt() ) ) ){
					// CF9 doesn't natively parse HTTP dates very well, so this'll have to do for now.
					todo.setCreatedAt( listFirst( entity.createdAt, 'T' ) & ' ' & listFirst( listLast( entity.createdAt, 'T' ), 'Z' ) );				
				}

				todo.save();
				
			}
		}

		return noData().withStatus(200);
		//return representationOf( todo.toJSON() ).withStatus(200);

	}
}
