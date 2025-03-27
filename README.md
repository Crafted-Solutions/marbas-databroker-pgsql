# marbas-databroker-pgsql
![Runs on Windows](https://img.shields.io/badge/_%E2%9C%94-Win-black) ![Runs on MacOS](https://img.shields.io/badge/_%E2%9C%94-Mac-black) ![Runs on Linux](https://img.shields.io/badge/_%E2%9C%94-Linux-black) ![Tool](https://img.shields.io/badge/.Net-8-lightblue) [<img src="https://img.shields.io/github/v/release/Crafted-Solutions/marbas-databroker-pgsql" title="Latest">](../../releases/latest)

Data broker PostgreSQL engine for [MarBas](https://github.com/Crafted-Solutions/marbas-databroker) system.

## Prerequisites
The app expects a PostgresSQL instance with `marbas` DB properly set up. Setup options are described below.

*Please note*: the API app is pre-configured (in `appsettings.json` under `BrokerProfile`) to connect to `marbas` DB at `db-devel.marbas.local:5432` with user `marbas` and password `marbas`, it is strongly recommended leaving the configuration unchanged and instead adding to your `/etc/hosts` (replace the IP accordingly if the DB is running on different host):
```hosts
127.0.0.1 db-devel.marbas.local
```

1. ### Existing Postgres Server
    If you already have a Postgres server running, do the following:

    1. Copy `<SOLUTION_ROOT>/setup` directory to the Posgres host.
    1. Login into shell on the host.
    1. Run
        ```sh
        cd ~/setup
        sudo -u postgres ./bootstrap.sh
        ```
        *postgres* stands for the SUPERUSER in your Postgres instance.

    Alternatively you can login into PgAdmin (or whatever DB management tool you use) and procede there:

    1. Run
        ```sql
        CREATE USER marbas WITH LOGIN CREATEDB CREATEROLE REPLICATION PASSWORD 'marbas';
        CREATE DATABASE marbas WITH OWNER marbas;
        ```
    1. Change to `marbas` DB.
    1. Load and execute `<SOLUTION_ROOT>/setup/scripts/marbas.postgres.sql`.
    1. Load and execute `<SOLUTION_ROOT>/setup/scripts/marbas-data.postgres.sql`.
    1. Load and execute `<SOLUTION_ROOT>/setup/scripts/marbas-logo.postgres.sql`.

1. ### Docker Container
    1. Execute in the `<SOLUTION_ROOT>/setup` directory
        ```sh
        docker-compose up -d
        ```
    1. After containers are spinned up, you will find ready-to-use DB under `db-devel.marbas.local:5432` and a PgAdmin instance under `http://db-devel.marbas.local:5050`.

## Building
Execute in the solution directory
```sh
dotnet build
```

## Running
Execute in the solution directory
```sh
dotnet run --project src/MarBasAPI/MarBasAPI.csproj
```

Swagger test app is then available at https://localhost:7277/swagger/index.html and API - at https://localhost:7277/api/marbas. Endpoints require authentication, for testing purposes dummy basic auth is turned on. In Swagger go to "Authorize" and login using arbitrary user name with password "*b*".

Aleternatively you can download pre-built binary archive of your choice from [Releases](../../releases/latest), extract it somewhere on your computer, change into that directory and run in the terminal
```sh
./MarBasAPI
```
Per default the binary starts production HTTP server (no SSL) on a free port (mostly 5000), i.e. the API endpoints would be reachable via http://localhost:5000/api/marbas. In production mode Swagger is disabled and the only configured user is `reader` with password "*Change_Me*" (can be set in `appsettings.json`). We strongly recommend not using basic authentication with sensitive data, especially when the API is publically accessible - in the future releases we will provide more secure authentication modules.

If you wish that the pre-built executable behaves exactly like the project run by DotNet, set the following environment variables before running `MarBasAPI`
```sh
ASPNETCORE_ENVIRONMENT=Development
ASPNETCORE_URLS=https://localhost:7277
```

### Example Use
```sh
curl -u reader:b "https://localhost:7277/api/marbas/Tree/**"
curl -u reader:b "https://localhost:7277/api/marbas/Role/Current"
```


## Contributing
All contributions to development and error fixing are welcome. Please always use `develop` branch for forks and pull requests, `main` is reserved for stable releases and critical vulnarability fixes only. 
