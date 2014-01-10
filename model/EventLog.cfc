component persistent="true" table="eventLog" extends="com.database.BaseModelObject" accessors="true" {
	property name="userID" type="string";
	/* Relationships */
	property name="user" inverseJoinColumn="ID" cascade="save-update" fieldType="one-to-one" fkcolumn="userID" cfc="model.User";
}