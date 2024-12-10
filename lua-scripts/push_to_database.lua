#!/usr/bin/env lua

local luasql = require("luasql.sqlite3")
local json = require("dkjson")

local M = {}

-- Configuration
local CONFIG = {
    db_path = "/app/data/ebay_data.db",
    batch_size = 50,
    max_retries = 3,
    tables = {
        items = [[
            CREATE TABLE IF NOT EXISTS items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                price REAL,
                url TEXT UNIQUE,
                image_url TEXT,
                condition TEXT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            )]],
        analysis = [[
            CREATE TABLE IF NOT EXISTS analysis (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                item_id INTEGER,
                features TEXT,
                objects TEXT,
                colors TEXT,
                quality_score REAL,
                FOREIGN KEY(item_id) REFERENCES items(id)
            )]],
        seo = [[
            CREATE TABLE IF NOT EXISTS seo (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                item_id INTEGER,
                description TEXT,
                keywords TEXT,
                metadata TEXT,
                FOREIGN KEY(item_id) REFERENCES items(id)
            )]]
    }
}

-- Initialize database connection
local function connect_db()
    local env = luasql.sqlite3()
    local conn = env:connect(CONFIG.db_path)
    if not conn then
        return nil, "Failed to connect to database"
    end
    return conn, env
end

-- Initialize database schema
local function init_schema(conn)
    for name, schema in pairs(CONFIG.tables) do
        local success = conn:execute(schema)
        if not success then
            return false, "Failed to create table: " .. name
        end
    end
    return true
end

-- Insert single item
local function insert_item(conn, item)
    local query = [[
        INSERT OR IGNORE INTO items (title, price, url, image_url, condition)
        VALUES (?, ?, ?, ?, ?)
    ]]
    
    local success = conn:execute(query, {
        item.title,
        item.price,
        item.url,
        item.image_url,
        item.condition
    })
    
    if not success then
        return nil
    end
    
    -- Get the inserted item's ID
    local id_query = [[
        SELECT id FROM items WHERE url = ? LIMIT 1
    ]]
    local cursor = conn:execute(id_query, {item.url})
    local id = cursor:fetch()
    cursor:close()
    
    return id
end

-- Insert analysis data
local function insert_analysis(conn, item_id, analysis)
    local query = [[
        INSERT INTO analysis (item_id, features, objects, colors, quality_score)
        VALUES (?, ?, ?, ?, ?)
    ]]
    
    return conn:execute(query, {
        item_id,
        json.encode(analysis.features),
        json.encode(analysis.objects),
        json.encode(analysis.colors),
        analysis.quality_score
    })
end

-- Insert SEO data
local function insert_seo(conn, item_id, seo)
    local query = [[
        INSERT INTO seo (item_id, description, keywords, metadata)
        VALUES (?, ?, ?, ?)
    ]]
    
    return conn:execute(query, {
        item_id,
        seo.description,
        json.encode(seo.keywords),
        json.encode(seo.metadata)
    })
end

-- Begin transaction wrapper
local function with_transaction(conn, func)
    conn:execute("BEGIN TRANSACTION")
    
    local success, result = pcall(func)
    
    if success then
        conn:execute("COMMIT")
        return true, result
    else
        conn:execute("ROLLBACK")
        return false, result
    end
end

-- Main insert function
function M.batch_insert(data)
    local conn, env = connect_db()
    if not conn then
        return false, "Database connection failed"
    end
    
    -- Initialize schema
    local schema_ok = init_schema(conn)
    if not schema_ok then
        conn:close()
        env:close()
        return false, "Schema initialization failed"
    end
    
    -- Process in batches
    local success = with_transaction(conn, function()
        for _, item_data in ipairs(data) do
            -- Insert main item data
            local item_id = insert_item(conn, item_data.item)
            if not item_id then
                error("Failed to insert item: " .. item_data.item.title)
            end
            
            -- Insert analysis data if available
            if item_data.analysis then
                local analysis_ok = insert_analysis(conn, item_id, item_data.analysis)
                if not analysis_ok then
                    error("Failed to insert analysis for item: " .. item_id)
                end
            end
            
            -- Insert SEO data if available
            if item_data.seo_description then
                local seo_ok = insert_seo(conn, item_id, item_data.seo_description)
                if not seo_ok then
                    error("Failed to insert SEO data for item: " .. item_id)
                end
            end
        end
    end)
    
    conn:close()
    env:close()
    
    return success
end

-- Query functions
function M.get_items(filters)
    local conn, env = connect_db()
    if not conn then
        return nil, "Database connection failed"
    end
    
    local query = [[
        SELECT i.*, a.features, a.objects, s.description, s.keywords
        FROM items i
        LEFT JOIN analysis a ON i.id = a.item_id
        LEFT JOIN seo s ON i.id = s.item_id
    ]]
    
    local cursor = conn:execute(query)
    local results = {}
    
    local row = cursor:fetch({}, "a")
    while row do
        table.insert(results, row)
        row = cursor:fetch({}, "a")
    end
    
    cursor:close()
    conn:close()
    env:close()
    
    return results
end

return M