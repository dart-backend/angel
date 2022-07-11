# Working with Docker

## Postgresql

### Starting the container

    ```bash
    docker-compose -f docker-compose-pg.yml up
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

## MySQL

## Redis
