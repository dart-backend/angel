# Change Log

## 8.0.0

* Require Dart >= 3.0
* Upgraded: angel3_http_exception
* Upgraded: angel3_route
* Upgraded: angel3_model
* Upgraded: angel3_container
* Upgraded: angel3_container_generator
* Upgraded: angel3_mock_request
* Upgraded: angel3_framework
* Upgraded: angel3_auth (4 failed test cases)
* Upgraded: angel3_configuration
* Upgraded: angel3_validate
* Upgraded: angel3_client (1 failed test cases)
* Upgraded: angel3_websocket
* Upgraded: angel3_test

## 7.0.0

* Require Dart >= 2.17

## 6.0.0

* Require Dart >= 2.16
* Added ORM MySQL

## 5.0.0

* Skipped version

## 4.1.x

* Refactored the framework internal to use [Belatuk Common Utilities](<https://github.com/dart-backend/belatuk-common-utilities>)
* Updated to use `lints` linter
* Updated [website](<https://angel3-framework.web.app/>)
* Updated [examples](<https://github.com/dart-backend/belatuk-examples>)
* Fixed ORM code generator
* Fixed Serializer code generator
* Fixed graphQL code generator
* Fixed CLI
* Fixed failed test cases

## 4.0.0 (NNBD)

* Published all packages with `angel3_` prefix
* Changed Dart SDK requirements for all packages to ">=2.12.0 <3.0.0" to support NNBD.
* Migrated pretty_logging to 3.0.0 (0/0 tests passed)
* Migrated angel_http_exception to 3.0.0 (0/0 tests passed)
* Moved angel_cli to [CLI Repository](<https://github.com/dukefirehawk/cli>) (Not migrated yet)
* Added code_buffer and migrated to 2.0.0 (16/16 tests passed)
* Added combinator and migrated to 2.0.0 (16/16 tests passed)
* Migrated angel_route to 5.0.0 (35/35 tests passed)
* Migrated angel_model to 3.0.0 (0/0 tests passed)
* Migrated angel_container to 3.0.0 (55/55 tests passed)
* Added merge_map and migrated to 2.0.0 (6/6 tests passed)
* Added mock_request and migrated to 2.0.0 (5/5 tests)
* Migrated angel_framework to 4.0.0 (149/150 tests passed)
* Migrated angel_auth to 4.0.0 (31/31 tests passed)
* Migrated angel_configuration to 4.0.0 (8/8 testspassed)
* Migrated angel_validate to 4.0.0 (7/7 tests passed)
* Migrated json_god to 4.0.0 (13/13 tests passed)
* Migrated angel_client to 4.0.0 (13/13 tests passed)
* Migrated angel_websocket to 4.0.0 (3/3 tests passed)
* Migrated angel_test to 4.0.0 (1/1 test passed)
* Added symbol_table and migrated to 2.0.0 (16/16 tests passed)
* Migrated jael to 4.0.0 (20/20 tests passed)
* Migrated jael_preprocessor to 3.0.0 (5/5 tests passed)
* Migrated angel_jael to 4.0.0 (1/1 test passed)
* Migrated pub_sub to 4.0.0 (16/16 tests passed)
* Migrated production to 3.0.0 (0/0 tests passed)
* Added html_builder and migrated to 2.0.0 (1/1 tests passed)
* Migrated hot to 4.0.0 (0/0 tests passed)
* Added range_header and migrated to 3.0.0 (12/12 tests passed)
* Migrated angel_static to 4.0.0 (12/12 test passed)
* Created basic-sdk-2.12.x_nnbd template (1/1 test passed) <= Milestone 1
* Migrated angel_serialize to 4.0.0 (0/0 test passed)
* Migrated angel_serialize_generator to 4.0.0 (33/33 tests passed)
* Migrated angel_orm to 3.0.0 (0/0 tests passed)
* Migrated angel_migration to 3.0.0 (0/0 tests passed)
* Added inflection2 and migrated to 1.0.0 (28/32 tests passed)
* Migrated angel_orm_generator to 4.0.0 (0/0 tests passed)
* Migrated angel_migration_runner to 3.0.0 (0/0 tests passed)
* Migrated angel_orm_test to 3.0.0 (0/0 tests passed)
* Migrated angel_orm_postgres to 3.0.0 (51/54 tests passed)
* Create orm-sdk-2.12.x boilerplate (in progress) <= Milestone 2
* Migrated angel_auth_oauth2 to 4.0.0 (0/0 tests passed)
* Migrated angel_auth_cache to 4.0.0 (7/7 tests passed)
* Migrated angel_auth_cors to 4.0.0  (15/15 tests passed)
* Migrated angel_oauth2 to 4.0.0 (17/25 tests passed)
* Migrated angel_proxy to 4.0.0 (6/7 tests passed)
* Migrated angel_file_service to 4.0.0 (6/6 tests passed)
* Migrated graphql_parser to 2.0.0 (55/55 tests passed)
* Migrated graphql_schema to 2.0.0 (34/35 tests passed)
* Migrated graphql_server to 2.0.0 (9/10 tests passed)
* Migrated graphql_generator to 2.0.0 (0/0 tests passed)
* Migrated data_loader to 2.0.0 (7/7 tests passed)
* Migrated angel_graphql to 2.0.0 (0/0 tests passed)
* Migrated angel_mongo to 3.0.0 (0/0 tests passed)
* Migrated angel_orm_mysql to 2.0.0 (0/0 tests passed)
* Migrated angel_orm_service to 2.0.0 (0/0 tests passed)
* Migrated body_parser to 2.0.0 (11/11 tests passed)
* Migrated angel_markdown to 3.0.0 (0/0 tests passed)
* Migrated angel_jinja to 2.0.0 (0/0 tests passed)
* Migrated angel_html to 3.0.0 (1/3 tests passed)
* Migrated angel_mustache to 2.0.0 (3/3 tests passed)
* Migrated angel_paginate to 3.0.0 (18/18 tests passed)
* Migrated angel_poll to 2.0.0 (0/5 tests passed)
* Migrated angel_redis to 2.0.0 (0/8 tests passed)
* Migrated angel_seeder to 2.0.0 (0/0 tests passed)
* Migrated angel_relations to 2.0.0 (0/0 tests passed)
* Migrated angel_rethink to 2.0.0 (0/0 tests passed)
* Migrated angel_security to 2.0.0 (0/1 tests passed)
* Migrated angel_sembast to 2.0.0 (10/10 tests passed)
* Migrated angel_sync to 3.0.0 (0/1 tests passed)
* Migrated angel_typed_service to 3.0.0 (4/4 tests passed)
* Migrated angel_shelf to 2.0.0 (0/1 tests passed)
* Migrated user_agent to 2.0.0 (0/0 tests passed)
* Migrated angel_user_agent to 2.0.0 (0/0 tests passed)

## 3.0.0 (Non NNBD)

* Changed Dart SDK requirements for all packages to ">=2.10.0 <3.0.0"
* Updated pretty_logging to 2.0.0 (0/0 tests passed)
* Updated angel_http_exception to 2.0.0 (0/0 tests passed)
* Updated angel_cli to 3.0.0. (Rename not working)
* Updated angel_route to 4.0.0 (35/35 tests passed)
* Updated angel_model to 2.0.0 (0/0 tests passed)
* Updated angel_container to 2.0.0 (55/55 tests passed)
* Updated angel_framework to 3.0.0 (150/151 tests passed)
* Updated angel_auth to 3.0.0 (28/32 tests passed)
* Updated angel_configuration to 3.0.0 (6/8 tests passed)
* Updated angel_validate to 3.0.0 (7/7 tests passed)
* Added and updated json_god to 3.0.0 (7/7 tests passed)
* Updated angel_client to 3.0.0 (10/13 tests passed)
* Updated angel_websocket to 3.0.0 (3/3 tests passed)
* Updated jael to 3.0.0 (20/20 tests passed)
* Updated jael_preprocessor to 3.0.0 (5/5 tests passed)
* Updated test to 3.0.0 (1/1 tests passed)
* Updated angel_jael to 3.0.0 (1/1 tests passed, Issue with 2 dependencies)
* Added pub_sub and updated to 3.0.0 (16/16 tests passed)
* Updated production to 2.0.0 (0/0 tests passed)
* Updated hot to 3.0.0 (0/0 tests passed)
* Updated static to 3.0.0 (12/12 tests passed)
* Update basic-sdk-2.12.x boilerplate (1/1 tests passed)
* Updated angel_serialize to 3.0.0 (0/0 tests passed)
* Updated angel_serialize_generator to 3.0.0 (33/33 tests passed)
* Updated angel_orm to 3.0.0 (0/0 tests passed)
* Updated angel_migration to 3.0.0 (0/0 tests passed)
* Updated angel_orm_generator to 3.0.0 (0/0 tests passed, use a fork of postgres)
* Updated angel_migration_runner to 3.0.0 (0/0 tests passed)
* Updated angel_orm_test to 1.0.0 (0/0 tests passed)
* Updated angel_orm_postgres to 2.0.0 (52/54 tests passed)
* Update orm-sdk-2.12.x boilerplate
* Updated angel_auth_oauth2 to 3.0.0 (0/0 tests passed)
* Updated angel_auth_cache to 3.0.0 (0/7 tests passed)
* Updated angel_auth_cors to 3.0.0 (15/15 tests passed)
* Updated angel_oauth2 to 3.0.0 (17/25 tests passed)
* Updated angel_container_generator to 2.0.0
* Updated angel_file_service to 3.0.0
* Updated angel_eventsource to 2.0.0 (use a fork of eventsource)
* Updated angel_auth_twitter to 3.0.0 (use a fork of twitter and oauth)

## 2.2.0

* Changed Dart SDK requirements for all packages to ">=2.10.0 <2.12.0"
* Upgraded 3rd party libraries to the latest version prior to dart 2.12
* Fixed broken code due to 3rd party libraries update
* Revert packages/validate from version 3.0 to version 2.2

## 2.1.x and below

* Refer to the orginal repo before the fork
