component output="false" {	
	this.name = "breeze-Test";  
  
  
  public function onApplicationStart(){
    reInit();
  }
   reInit();
  
  public function reInit(){
    /*****************************
    * Initialize Sample Table/Data
    ******************************/
	var httpService = new http( url = "/api/index.cfm/breeze/todos/Todos", method = "POST" );
	httpService.addParam(type="header",name="Content-Type", value="application/json");
	httpService.addParam(type="body", value=""); 
	var response = httpService.send().getPrefix();    
 
  }
}