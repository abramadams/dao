# Testing with MSSQL via Docker

Use the Docker Compose stack to run the test suite against Microsoft SQL Server.

## 1. Start MSSQL

```bash
docker compose up -d mssql
```

Wait ~30 seconds for SQL Server to be ready, then create the test database (one-time):

```bash
docker compose exec mssql /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P 'DaoTest123!' -d master -C -Q "IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'dao_test') CREATE DATABASE dao_test"
```

The server image includes `sqlcmd` at `/opt/mssql-tools18/bin/sqlcmd`. The `-C` flag trusts the server certificate (required for local Docker).

**Connection details:**

| Setting  | Value        |
|----------|---------------|
| Host     | localhost     |
| Port     | 1433          |
| Database | dao_test      |
| User     | sa            |
| Password | DaoTest123!   |

## 2. Point the test app at MSSQL

In **`tests/Application.cfc`**, set **`this.datasource`** to **`"dao_mssql"`** (the **dao_mssql** entry is already in the **`this.datasources`** block). Restart and run tests:

```bash
box server restart
box testbox run
```

The first line of output should show **Database: mssql**.

## 3. Stop MSSQL

```bash
docker compose down
```
