#!/bin/bash
set -e
set -u

# PostgreSQL Multi-Database Initialization Script
# This script creates multiple databases and users when the container starts
# It only runs on first initialization (when data directory is empty)

function create_user_and_database() {
  local database=$1
  local password=$2

  echo "  Creating user and database '$database'"

  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    CREATE USER $database WITH PASSWORD '$password';
    CREATE DATABASE $database;
    GRANT ALL PRIVILEGES ON DATABASE $database TO $database;
    ALTER DATABASE $database OWNER TO $database;
EOSQL
}

function create_extension_if_not_exists() {
  local database=$1
  local extension=$2

  echo "  Checking extension '$extension' for database '$database'"

  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$database" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS $extension;
EOSQL
}

# Check if multiple databases are requested
if [ -n "${POSTGRES_MULTIPLE_DATABASES:-}" ]; then
  echo "Multiple database creation requested: $POSTGRES_MULTIPLE_DATABASES"

  # Parse databases in format: db1:password1,db2:password2
  # or just: db1,db2 (will use database name as password)
  for db_spec in $(echo "$POSTGRES_MULTIPLE_DATABASES" | tr ',' ' '); do
    if [[ "$db_spec" == *:* ]]; then
      # db:password format
      database="${db_spec%%:*}"
      password="${db_spec#*:}"
    else
      # db format (use db name as password)
      database="$db_spec"
      password="$db_spec"
    fi

    create_user_and_database "$database" "$password"

    # Install commonly used extensions
    create_extension_if_not_exists "$database" "uuid-ossp"
    create_extension_if_not_exists "$database" "pg_trgm"
  done

  echo "Multiple databases created successfully"
fi
