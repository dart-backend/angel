# Running as Container Services using Podman

The required applications by the framework can be run using the Docker compose files provided in this folder.

## Installation

### PostreSQL

* Starting the PostreSQL container

    ```bash
    podman-compose -f podman-compose-pg.yml -p pg up -d
    ```

* Stopping the PostreSQL container

    ```bash
    podman-compose -f podman-compose-pg.yml -p pg stop
    podman-compose -f podman-compose-pg.yml -p pg down
    ```

* Checking the PostreSQL container log

    ```bash
    podman logs -f podman-pg-1
    ```

* Running psql

    ```bash
    podman exec -it <container id> /bin/bash
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
    podman-compose -f podman-compose-mariadb.yml -p maria up -d
    ```

* Stopping the MariaDB container

    ```bash
    podman-compose -f podman-compose-mariadb.yml -p maria stop
    podman-compose -f podman-compose-mariadb.yml -p maria down
    ```

* Checking the MariaDB container log

    ```bash
    podman logs -f maria-mariadb-1
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
    podman-compose -f podman-compose-mysql.yml -p mysql up -d
    ```

* Stopping the MySQL container

    ```bash
    podman-compose -f podman-compose-mysql.yml -p mysql stop
    podman-compose -f podman-compose-mysql.yml -p mysql down
    ```

* Checking the MySQL container log

    ```bash
    podman logs -f mysql-mysql-1
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
    podman-compose -f podman-compose-mongo.yml -p mongo up -d
    ```

* Stopping the MongoDB container

    ```bash
    podman-compose -f podman-compose-mongo.yml -p mongo stop
    podman-compose -f podman-compose-mongo.yml -p mongo down
    ```

* Checking the MongoDB container log

    ```bash
    podman logs -f mongo-mongo-1
    ```

### rethinkDB

* Starting the rethinkDB container

    ```bash
    podman-compose -f podman-compose-rethinkdb.yml -p rethink up -d
    ```

* Stopping the rethinkDB container

    ```bash
    podman-compose -f podman-compose-rethinkdb.yml -p rethink stop
    podman-compose -f podman-compose-rethinkdb.yml -p rethink down
    ```

* Checking the rethinkDB container log

    ```bash
    podman logs -f rethink-rethinkdb-1
    ```

### Redis

* Starting the Redis container

    ```bash
    podman-compose -f podman-compose-redis.yml -p redis up -d
    ```

* Stopping the Redis container

    ```bash
    podman-compose -f podman-compose-redis.yml -p redis stop
    podman-compose -f podman-compose-redis.yml -p redis down
    ```

* Checking the Redis container log

    ```bash
    podman logs -f redis-redis-1
    ```
