#!/usr/bin/env bash

if [ -z $PROXY_FQDN ]
then
    echo "The variable 'PROXY_FQDN' is missing"
    exit 1
fi

export PG_VERSION=${PG_VERSION:-11}

export PG_CLUSTER_NAME=${PG_CLUSTER_NAME:-shuttle}

export PG_DATA=${PG_DATA:-/var/lib/postgresql/$PG_VERSION/$PG_CLUSTER_NAME}

export PG_CONF=${PG_CONF:-/etc/postgresql/$PG_VERSION/$PG_CLUSTER_NAME}

if [ ! -z $COPY_PG_CONF ]; then
    mkdir -p $PG_CONF
    cp -R $COPY_PG_CONF $PG_CONF
fi

export PG_PORT=${PG_PORT:-5432}

export PG_PASSWORD=${PG_PASSWORD:-postgres}

if [[ "$(pg_lsclusters -h | wc -l)" -ne "1" ]]; then
    set -e
    pg_createcluster -d $PG_DATA $PG_VERSION $PG_CLUSTER_NAME

    conftool() {
        pg_conftool $PG_VERSION $PG_CLUSTER_NAME set $1 $2
    }
    conftool listen_addresses \"*\"
    conftool port $PG_PORT
    conftool log_statement all

    pg_ctlcluster $PG_VERSION $PG_CLUSTER_NAME start
    su postgres -c "psql -c \"ALTER USER postgres PASSWORD '${PG_PASSWORD}'\""
    pg_ctlcluster $PG_VERSION $PG_CLUSTER_NAME stop
    set +e
fi

export PG_LOG=$(pg_lsclusters -h | cut -d' ' -f7)

export PG_HOST=localhost

export PG_URI=postgres://postgres:${PG_PASSWORD}@localhost:${PG_PORT}/postgres

export CRATES_PATH=${CRATES_PATH:-/var/lib/shuttle/crates}

mkdir -p $CRATES_PATH

export PROXY_PORT=${PROXY_PORT:-8000}

export API_PORT=${API_PORT:-8001}

export FIRST_USER=${FIRST_USER:first-user}

if [[ ! -z "${SHUTTLE_USERS_TOML}" && ! -s "${SHUTTLE_USERS_TOML}" ]]
then
    if [[ -z "${SHUTTLE_INITIAL_KEY}" ]]
    then
        echo "\$SHUTTLE_INITIAL_KEY is not set to create initial user's key"
        exit 1
    fi

    echo "Creating a first user with key '${SHUTTLE_INITIAL_KEY}' at '${SHUTTLE_USERS_TOML}'"
    mkdir -p $(dirname "${SHUTTLE_USERS_TOML}")
    echo -e "[$SHUTTLE_INITIAL_KEY]\nname = '${FIRST_USER}'\nprojects = []" > "${SHUTTLE_USERS_TOML}"
fi

exec supervisord -n -c /usr/share/supervisord/supervisord.conf
