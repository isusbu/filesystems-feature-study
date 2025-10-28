CREATE TABLE users (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE posts (
    id INTEGER PRIMARY KEY,
    user_id INTEGER,
    title TEXT,
    content TEXT,
    tags TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX idx_posts_user_id ON posts(user_id);
CREATE INDEX idx_posts_title ON posts(title);

-- Full-text search
CREATE VIRTUAL TABLE post_search USING fts5(title, content, tags);

-- Trigger for automatic FTS update
CREATE TRIGGER posts_ai AFTER INSERT ON posts BEGIN
    INSERT INTO post_search (rowid, title, content, tags)
    VALUES (new.id, new.title, new.content, new.tags);
END;

CREATE VIEW user_post_count AS
SELECT u.name, COUNT(p.id) as post_count
FROM users u LEFT JOIN posts p ON u.id = p.user_id
GROUP BY u.id;
