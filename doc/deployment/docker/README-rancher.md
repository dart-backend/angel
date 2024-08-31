# Docker Container Services

The required applications by the framework can be run using the nerdctl composefiles provided in this folder.

## Rancher

### PostreSQL

* Starting the PostreSQL container

    ```bash
    nerdctl compose -f docker-compose-pg.yml -p pg up -d
    ```

* Stopping the PostreSQL container

    ```bash
    nerdctl compose -f docker-compose-pg.yml -p pg stop
    nerdctl compose -f docker-compose-pg.yml -p pg down
    ```

* Checking the PostreSQL container log

    ```bash
    nerdctl logs docker-pg-1 -f
    ```

* Running psql

    ```bash
    nerdctl exec -it <container id> /bin/bash
    psql --username postgres
    ```

* Create PostgreSQL database, user and grant access

    ```sql
    create database orm_test;
    create user test with encrypted password 'test123';
    grant all privileges on database orm_test to test;
    ```

### MariaDB

* Starting the MariaDB container

    ```bash
    nerdctl compose -f docker-compose-mariadb.yml -p maria up -d
    ```

* Stopping the MariaDB container

    ```bash
    c
    nerdctl compose -f docker-compose-mariadb.yml -p maria down
    ```

* Checking the MariaDB container log

    ```bash
    nerdctl logs maria-mariadb-1 -f
    ```

* Create MariaDB database, user and grant access

    ```sql
    create database orm_test;
    
    -- Granting localhost access only
    create user 'test'@'localhost' identified by 'test123';
    grant all privileges on orm_test.* to 'test'@'localhost';

    -- Granting localhost and remote access
    create user 'test'@'%' identified by 'test123';
    grant all privileges on orm_test.* to 'test'@'%';
    ```

### MySQL

* Starting the MySQL container

    ```bash
    nerdctl compose -f docker-compose-mysql.yml -p mysql up -d
    ```

* Stopping the MySQL container

    ```bash
    nerdctl compose -f docker-compose-mysql.yml -p mysql stop
    nerdctl compose -f docker-compose-mysql.yml -p mysql down
    ```

* Checking the MySQL container log

    ```bash
    nerdctl logs mysql-mysql-1 -f
    ```

* Create MySQL database, user and grant access

    ```sql
    create database orm_test;
    
    -- Granting localhost access only
    create user 'test'@'localhost' identified by 'test123';
    grant all privileges on orm_test.* to 'test'@'localhost';

    -- Granting localhost and remote access
    create user 'test'@'%' identified by 'test123';
    grant all privileges on orm_test.* to 'test'@'%';
    ```

### MongoDB

* Starting the MongoDB container

    ```bash
    nerdctl compose -f docker-compose-mongo.yml -p mongo up -d
    ```

* Stopping the MongoDB container

    ```bash
    nerdctl compose -f docker-compose-mongo.yml -p mongo stop
    nerdctl compose -f docker-compose-mongo.yml -p mongo down
    ```

* Checking the MongoDB container log

    ```bash
    nerdctl logs mongo-mongo-1 -f
    ```

### rethinkDB

* Starting the rethinkDB container

    ```bash
    nerdctl compose -f docker-compose-rethinkdb.yml -p rethink up -d
    ```

* Stopping the rethinkDB container

    ```bash
    nerdctl compose -f docker-compose-rethinkdb.yml -p rethink stop
    nerdctl compose -f docker-compose-rethinkdb.yml -p rethink down
    ```

* Checking the rethinkDB container log

    ```bash
    nerdctl logs rethink-rethinkdb-1 -f
    ```

### Redis

* Starting the Redis container

    ```bash
    nerdctl compose -f docker-compose-redis.yml -p redis up -d
    ```

* Stopping the Redis container

    ```bash
    nerdctl compose -f docker-compose-redis.yml -p redis stop
    nerdctl compose -f docker-compose-redis.yml -p redis down
    ```

* Checking the Redis container log

    ```bash
    nerdctl logs redis-redis-1 -f
    ```
