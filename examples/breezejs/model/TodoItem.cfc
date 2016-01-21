component norm_persistent="true" table="TodoItem" extends="com.database.Norm" accessors="true" {

	property name="_id" type="string" fieldtype="id" generator="uuid";	
	property name="ID" type="numeric" fieldtype="id" generator="increment";	
	property name="description" type="string" length="30";
	property name="isDone" type="boolean";
	property name="isArchived" type="boolean";	
	property name="createdAt" type="date";

	/* Relationships */
	//property name="userID" type="numeric";
	//property name="user" inverseJoinColumn="ID" cascade="save-update" fieldType="one-to-one" fkcolumn="userID" cfc="model.User";

}