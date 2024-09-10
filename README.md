# marbas-databroker-pgsql
Data broker PostgreSQL engine for MarBas system.

## Prerequisites
The app expects a PostgresSQL instance with `marbas` DB properly set up. Setup options are described below.

*Please note*: in development mode the API app is pre-configured to connect to `marbas` DB at `db-devel.marbas.local:5432` with user `marbas` and password `marbas`, it is strongly recommended leaving the configuration unchanged and instead adding to your `/etc/hosts` (replace the IP accordingly if the DB is running on different host):
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

API is then available at https://localhost:7277/swagger/index.html. Endpoints require authentication, for testing purposes dummy basic auth is turned on. In Swagger go to "Authorize" and login using arbitrary user name with password "*b*"

## Using NuGet Packages
1. Generate your GitHub personal access token [here](https://github.com/login?return_to=https%3A%2F%2Fgithub.com%2Fsettings%2Ftokens) with **read:packages** permission.
1. Add https://nuget.pkg.github.com/Crafted-Solutions/index.json repository to your **local** `nuget.config`:
    ```xml
    <packageSources>
        <add key="crafted-solutions" value="https://nuget.pkg.github.com/Crafted-Solutions/index.json"/>
    </packageSources>
    <packageSourceCredentials>
        <crafted-solutions>
            <add key="Username" value="YOUR_USER_NAME"/>
            <add key="ClearTextPassword" value="YOUR_PACKAGE_TOKEN"/>
        </crafted-solutions>
    </packageSourceCredentials>
    ```
    Alternatively run this command
    ```sh
    dotnet nuget add source https://nuget.pkg.github.com/Crafted-Solutions/index.json -n crafted-solutions -u YOUR_USER_NAME -p YOUR_PACKAGE_TOKEN --store-password-in-clear-text
    ```
    Alternatively in Visual Studio go to “Tools” -> “Options” -> “NuGet Package Manager” -> “Package Sources” and add the repository as new source.
    
    *DON'T COMMIT ANY CONFIGURATION CONTAINING TOKENS!*
