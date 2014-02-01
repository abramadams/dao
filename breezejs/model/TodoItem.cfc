component persistent="true" extends="com.database.BaseModelObject" accessors="true" {

	property name="ID" type="numeric" fieldtype="id" generator="increment";	
	property name="description" type="string" length="30";

	property name="isDone" type="numeric";
	property name="isArchived" type="numeric";
	
	property name="createdAt" type="date";	

	/* Relationships */
	//property name="user" inverseJoinColumn="ID" cascade="save-update" fieldType="one-to-one" fkcolumn="userID" cfc="model.User";

}