BEGIN TRANSACTION;

-- Insert users
INSERT INTO users (name, email) VALUES ('Alice', 'alice@example.com');
INSERT INTO users (name, email) VALUES ('Bob', 'bob@example.com');

-- Insert posts
INSERT INTO posts (user_id, title, content, tags)
VALUES (1, 'Hello SQLite', 'This is a test of SQLite', 'intro,sqlite');
INSERT INTO posts (user_id, title, content, tags)
VALUES (2, 'Advanced SQLite', 'Testing triggers and FTS', 'fts,trigger,sqlite');

-- Search using FTS
SELECT * FROM post_search WHERE post_search MATCH 'sqlite';

-- Update
UPDATE posts SET title = 'Hello SQLite Updated' WHERE id = 1;

-- View query
SELECT * FROM user_post_count;

-- JSON usage
SELECT json_extract('{"a":1,"b":{"c":2}}', '$.b.c');

COMMIT;

-- Vacuum and checkpoint to test WAL
PRAGMA wal_checkpoint(FULL);
VACUUM;
