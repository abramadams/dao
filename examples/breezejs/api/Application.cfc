component extends="taffy.core.api" {    
    //this.name = "breeze-Test-api";    
    this.name = hash(getCurrentTemplatePath());
    this.mappings['/com'] = expandPath( '/src/com/' );
    this.mappings['/model'] = expandPath( '../model' );
    this.mappings['/taffy'] = expandPath( './taffy' );
    this.mappings['/resources'] = expandPath( './resources' );

    variables.framework = {
        reloadKey = "reload",
        reloadPassword = "true",
        disableDashboard = false,
        disabledDashboardRedirect = "/",
        debugKey = "debugonly"  
    };

    // this function is called after the request has been parsed and all request details are known
    function onTaffyRequest(verb, cfc, requestArguments, mimeExt){
        // this would be a good place for you to check API key validity and other non-resource-specific validation        
        return true;
    }

    public function onApplicationStart(){
        reInit();
        super.onApplicationStart();
      }

    public function reInit(){
        /*****************************
        * Initialize Sample Table/Data
        ******************************/        
        dao = new com.database.dao( dsn = "dao" );
        todoItem = new model.TodoItem( dao = dao );
        // if there is any data present in the TodoItem table, delete it
        dao.delete("TodoItem","*");

        // now we'll add in our sample data
        todoItem.setDescription('Food');
        todoItem.setIsArchived(true);
        todoItem.setIsDone(true);
        todoItem.setCreatedAt( now() );
        todoItem.save();

        todoItem.clone();
        todoItem.setDescription('Water');
        todoItem.setIsArchived(true);
        todoItem.setIsDone(true);
        todoItem.save();

        todoItem.clone();
        todoItem.setDescription('Shelter');
        todoItem.setIsArchived(true);
        todoItem.setIsDone(true);
        todoItem.save();

        todoItem.clone();
        todoItem.setDescription('Bread');
        todoItem.setIsArchived(false);
        todoItem.setIsDone(false);
        todoItem.save();

        todoItem.clone();
        todoItem.setDescription('Cheese');
        todoItem.setIsArchived(false);
        todoItem.setIsDone(true);
        todoItem.save();

        todoItem.clone();
        todoItem.setDescription('Wine');
        todoItem.setIsArchived(false);
        todoItem.setIsDone(false);
        todoItem.save();

    }

}