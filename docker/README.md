# Docker setup

## PostreSQL

### Starting the PostreSQL container

    ```bash
    docker compose -f docker-compose-pg.yml up -d
    ```

### Stopping the PostreSQL container

    ```bash
    docker compose -f docker-compose-pg.yml stop
    docker compose -f docker-compose-pg.yml down
    ```

### Checking the PostreSQL container log

    ```bash
    docker logs docker-pg-1 -f
    ```

### Running psql

    ```bash
    docker exec -it <container id> /bin/bash
    psql --username postgres
    ```

### Create database, user and access

    ```psql
    postgres=# create database orm_test;
    postgres=# create user test with encrypted password 'test123';
    postgres=# grant all privileges on database orm_test to test;
    ```

## MariaDB

### Starting the MariaDB container

    ```bash
    docker compose -f docker-compose-mariadb.yml up -d
    ```

### Stopping the MariaDB container

    ```bash
    docker compose -f docker-compose-mariadb.yml stop
    docker compose -f docker-compose-mariadb.yml down
    ```

### Checking the MariaDB container log

    ```bash
    docker logs docker-mariadb-1 -f
    ```

## MySQL

### Starting the MySQL container

    ```bash
    docker compose -f docker-compose-mysql.yml up -d
    ```

### Stopping the MySQL container

    ```bash
    docker compose -f docker-compose-mysql.yml stop
    docker compose -f docker-compose-mysql.yml down
    ```

### Checking the MySQL container log

    ```bash
    docker logs docker-mysql-1 -f
    ```

## MongoDB

### Starting the MongoDB container

    ```bash
    docker compose -f docker-compose-mongo.yml up -d
    ```

### Stopping the MongoDB container

    ```bash
    docker compose -f docker-compose-mongo.yml stop
    docker compose -f docker-compose-mongo.yml down
    ```

### Checking the MongoDB container log

    ```bash
    docker logs docker-mongo-1 -f
    ```

## rethinkDB

### Starting the rethinkDB container

    ```bash
    docker compose -f docker-compose-rethinkdb.yml up -d
    ```

### Stopping the rethinkDB container

    ```bash
    docker compose -f docker-compose-rethinkdb.yml stop
    docker compose -f docker-compose-rethinkdb.yml down
    ```

### Checking the rethinkDB container log

    ```bash
    docker logs docker-rethinkdb-1 -f
    ```

## Redis

### Starting the Redis container

    ```bash
    docker compose -f docker-compose-redis.yml up -d
    ```

### Stopping the Redis container

    ```bash
    docker compose -f docker-compose-redis.yml stop
    docker compose -f docker-compose-redis.yml down
    ```

### Checking the Redis container log

    ```bash
    docker logs docker-redis-1 -f
    ```
