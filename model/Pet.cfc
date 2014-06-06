component persistent="true" table="pets" extends="com.database.BaseModelObject" accessors="true" {
	
	property name="ID" type="numeric" fieldtype="id" generator="increment";
	property name="_id" fieldtype="id" generator="uuid" type="string" length="45";
	property name="userID" type="string";
	property name="firstName" type="string" column="first_name";
	property name="lastName" type="string" column="last_name";	
	property name="createdDate" type="date" column="created_datetime";
	property name="modifiedDate" type="date" column="modified_datetime" formula="now()";

	/* Relationships */
	property name="user" inverseJoinColumn="ID" cascade="save-update" fieldType="one-to-one" fkcolumn="userID" cfc="model.User";

	public string function getFullName(){
		return variables.firstName & " " & variables.lastName;
	}
}