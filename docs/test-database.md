# Changing the test database

The test suite uses whichever datasource is named in **`this.datasource`** in **`tests/Application.cfc`**. All three DBs are defined in one **`this.datasources`** block with distinct names.

## Switch by changing one line

In **`tests/Application.cfc`**, set **`this.datasource`** to the datasource you want:

| Use this DB | Set this |
|-------------|----------|
| **SQLite** (default) | `this.datasource = "dao_sqlite";` |
| **MySQL** | `this.datasource = "dao_mysql";` |
| **MSSQL** | `this.datasource = "dao_mssql";` |

The **`this.datasources`** block already defines **dao_sqlite**, **dao_mysql**, and **dao_mssql** with the usual connection settings. Adjust connection strings, usernames, or passwords in that block if your environment differs (e.g. different host or Docker credentials).

Restart the server and run tests. The first line of output will show **Database: sqlite** | **mysql** | **mssql**.

## Optional: use server.json instead

You can define **dao_sqlite**, **dao_mysql**, and **dao_mssql** (or a single **dao**) in **`server.json`**, comment out the **`this.datasources`** block in Application.cfc, and set **`this.datasource`** to the name of the datasource to use. Same idea: one line selects the DB.
