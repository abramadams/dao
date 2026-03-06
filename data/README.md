# SQLite test database

The file `dao.sqlite` is used by the test suite when the **dao** datasource is configured for SQLite (see `tests/Application.cfc`).

- **Creation:** The file is created automatically on first run when the tests connect (JDBC creates an empty DB at this path if it doesn’t exist).
- **Path:** `data/dao.sqlite` (relative to project root). The test app uses `expandPath("/data/dao.sqlite")`.
- **Driver:** The test datasource uses `org.sqlite.JDBC`. Lucee 6+ includes a SQLite driver; on Lucee 5 you may need to add the SQLite JDBC JAR to your server’s classpath.

You can also point any SQLite client at `data/dao.sqlite` to inspect or edit the test data after running tests.
