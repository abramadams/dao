component extends="taffy.core.api" {
    this.name = hash(getCurrentTemplatePath());
    this.mappings['/com'] = expandPath( '/' );
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
        // Create a global instance of the dao component.
        application.dao = new com.database.dao( dsn = "dao" );
        // Initialize the data
        setupData();
        super.onApplicationStart();
      }

    public function setupData(){
        /**********************************************************************
        * Initialize Sample Table/Data
        * Normally you're data would be real, so you'd use a service for this.
        ***********************************************************************/
        todoItem = new model.TodoItem( dao = application.dao );
        // if there is any data present in the TodoItem table, delete it
        application.dao.delete("TodoItem","*");

        // now we'll add in our sample data
        todoItem.setDescription('Food');
        todoItem.setIsArchived(true);
        todoItem.setIsDone(true);
        todoItem.setCreatedAt( now() );
        todoItem.save();

        todoItem.copy();
        todoItem.setDescription('Water');
        todoItem.setIsArchived(true);
        todoItem.setIsDone(true);
        todoItem.save();

        todoItem.copy();
        todoItem.setDescription('Shelter');
        todoItem.setIsArchived(true);
        todoItem.setIsDone(true);
        todoItem.save();

        todoItem.copy();
        todoItem.setDescription('Bread');
        todoItem.setIsArchived(false);
        todoItem.setIsDone(false);
        todoItem.save();

        todoItem.copy();
        todoItem.setDescription('Cheese');
        todoItem.setIsArchived(false);
        todoItem.setIsDone(true);
        todoItem.save();

        todoItem.copy();
        todoItem.setDescription('Wine');
        todoItem.setIsArchived(false);
        todoItem.setIsDone(false);
        todoItem.save();

    }

}