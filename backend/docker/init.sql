-- Runs once when the Postgres data volume is created.
-- Creates the separate test database so tests never touch the app database.
CREATE DATABASE talkitout_test;
