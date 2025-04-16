#!/bin/sh

# Validate the configuration
python3 manage.py check

# Retry until the database is running
# until python3 manage.py migrate 2> /dev/null; do
until python3 manage.py migrate; do
    sleep 5;
done;

python3 manage.py create-initial-admin-account
python3 manage.py create-demo-questions

if [ -n "$STATIC_ROOT" ]; then
    python3 manage.py collectstatic --no-input;
fi

exec gunicorn server.wsgi
