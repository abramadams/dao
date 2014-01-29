component persistent="true" table="eventLog" extends="com.database.BaseModelObject" accessors="true" {
	property name="ID" type="numeric" fieldtype="id" generator="increment";
	property name="userID" type="string";

	property name="event" type="string";
	property name="description" type="string";
	property name="eventDate" type="date";
	/* Relationships */
	property name="user" inverseJoinColumn="ID" cascade="save-update" fieldType="one-to-one" fkcolumn="userID" cfc="model.User";
}