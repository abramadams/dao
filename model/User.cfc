component norm_persistent="true" table="users" singularName="User" extends="com.database.BaseModelObject" accessors="true" {

	property name="ID" type="numeric" fieldtype="id" generator="increment";
	property name="_id" fieldtype="id" generator="uuid" type="string" length="45";
	property name="firstName" type="string" column="first_name";
	property name="lastName" type="string" column="last_name";
	property name="email" type="string";
	property name="createdDate" type="date" column="created_datetime";
	property name="modifiedDate" type="date" column="modified_datetime" formula="now()"; 	


	public string function getFullName(){
		return variables.firstName & " " & variables.lastName;
	}
}