#!/bin/bash

set -e

echo "Starting Taskapp Backend Container..."

echo "⏳ Waiting for database at $DATABASE_HOST:$DATABASE_PORT..."
while ! nc -z $DATABASE_HOST $DATABASE_PORT; do
    sleep 0.1
done

echo "✅ Database is ready!"

echo "Running database migrations..."
alembic upgrade head
echo "Database migrations completed."

echo "Starting Gunicorn server..."
exec gunicorn \
    --bind 0.0.0.0:${PORT:-5000} \
    --workers ${WORKERS:-4} \
    --worker-class sync \
    --worker-connections 1000 \
    --timeout 60 \
    --keep-alive 2 \
    --max-requests 1000 \
    --max-requests-jitter 50 \
    --access-logfile - \
    --error-logfile - \
    --capture-output \
    --enable-stdio-inheritance \
    "run:app"