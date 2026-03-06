# Testing with MySQL via Docker

Use the included Docker Compose stack to run the test suite against MySQL.

## 1. Start MySQL

```bash
docker compose up -d
```

Wait for the container to be healthy (or a few seconds), then confirm:

```bash
docker compose ps
```

**Connection details** (used below):

| Setting    | Value      |
|-----------|------------|
| Host      | localhost  |
| Port      | 3306       |
| Database  | dao_test   |
| User      | dao        |
| Password  | dao        |

## 2. Point the test app at MySQL

In **`tests/Application.cfc`**, set **`this.datasource`** to **`"dao_mysql"`** (the **dao_mysql** entry is already in the **`this.datasources`** block). Restart and run tests:

```bash
box server restart
box testbox run
```

The first line of output should show **Database: mysql**.

## 3. Stop MySQL

```bash
docker compose down
```
