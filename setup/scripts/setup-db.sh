#!/bin/sh
THISDIR=`dirname -- "$0"`
psql -U $POSTGRES_USER -d $POSTGRES_DATABASE -c "BEGIN TRANSACTION;" -f "$THISDIR/marbas.postgres.sql" -f "$THISDIR/marbas-data.postgres.sql" -f "$THISDIR/marbas-logo.postgres.sql" -c "COMMIT;"
