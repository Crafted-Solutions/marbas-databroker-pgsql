@echo off
@for /F "delims== tokens=1,* eol=#" %%i in (db.env) do set %%i=%%~j
scripts/create-db.cmd
scripts/setup-db.cmd
