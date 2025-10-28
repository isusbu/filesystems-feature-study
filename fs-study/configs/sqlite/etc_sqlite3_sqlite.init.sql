-- SQLite global-style init
-- Enable Write-Ahead Logging (WAL)
PRAGMA journal_mode = WAL;

-- Use foreign keys
PRAGMA foreign_keys = ON;

-- Synchronous mode for safety (FULL or NORMAL)
PRAGMA synchronous = FULL;

-- Enable automatic indexing
PRAGMA automatic_index = ON;

-- Cache settings
PRAGMA cache_size = -2000;  -- about 2MB
PRAGMA temp_store = MEMORY;

-- Secure delete for data wiping
PRAGMA secure_delete = ON;

-- Busy timeout for concurrent access
PRAGMA busy_timeout = 5000;

-- Enable incremental vacuum
PRAGMA auto_vacuum = INCREMENTAL;
