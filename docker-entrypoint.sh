#!/bin/sh
set -e

# run migrations before starting the server
echo "running database migrations..."
node ace migration:run --force

# start the adonisjs server
echo "starting adonisjs server..."
exec node bin/server.js
