#!/bin/sh
set -a
. ./db.env
./scripts/create-db.sh
./scripts/setup-db.sh
set +a