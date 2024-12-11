#!/usr/bin/env lua

local lfs = require("luafilesystem")
local socket = require("socket")

-- Configuration
local CONFIG = {
    required_dirs = {
        "/app/logs",
        "/app/data",
        "/app/backup",
        "/app/metrics"
    },
    required_files = {
        "/app/lua-scripts/pipeline.lua",
        "/app/data/ebay_data.db"
    },
    metrics_port = 8080,
    min_disk_space = 1024 * 1024 * 100, -- 100MB
    max_log_size = 1024 * 1024 * 500    -- 500MB
}
-- Check log file size
local function check_log_size()
    local log_file = "/app/logs/pipeline.log"
    local size = lfs.attributes(log_file, "size")
    if size and size > CONFIG.max_log_size then
        return false, "Log file too large"
    end

    return true
end

-- Check system resources
local function check_resources()
    -- Check disk space
    local handle = io.popen("df -B1 /app | tail -1 | awk '{print $4}'")
    local free_space = tonumber(handle:read("*a"))
    handle:close()
    
    if free_space < CONFIG.min_disk_space then
        return false, "Insufficient disk space"
    end
    
    return true
end

-- Check required directories
local function check_directories()
    for _, dir in ipairs(CONFIG.required_dirs) do
        local mode = lfs.attributes(dir, "mode")
        if mode ~= "directory" then
            return false, "Directory not found: " .. dir
        end
    end
    
    return true
end

-- Check required files
local function check_files()
    for _, file in ipairs(CONFIG.required_files) do
        local exists = io.open(file, "r")
        if not exists then
            return false, "File not found: " .. file
        end
        exists:close()
    end
    
    return true
end

-- Check database connection
local function check_database()
    local sql = require("luasql.sqlite3")
    local env = sql.sqlite3()
    local db = env:connect("/app/data/ebay_data.db")
    
    if not db then
        return false, "Database connection failed"
    end
    
    db:close()
    env:close()
    return true
end

-- Check metrics endpoint
local function check_metrics()
    local client = socket.connect("localhost", CONFIG.metrics_port)
    if not client then
        return false, "Metrics endpoint not responding"
    end
    
    client:close()
    return true
end

-- Main health check function
local function run_health_check()
    local checks = {
        { name = "Resources", func = check_resources },
        { name = "Directories", func = check_directories },
        { name = "Files", func = check_files },
        { name = "Database", func = check_database },
        { name = "Metrics", func = check_metrics }
    }
    
    local all_passed = true
    local failures = {}
    
    for _, check in ipairs(checks) do
        local success, error_msg = check.func()
        if not success then
            all_passed = false
            table.insert(failures, {
                check = check.name,
                error = error_msg
            })
        end
    end
    
    return all_passed, failures
end

-- Execute health check
local success, failures = run_health_check()

if success then
    print("Health check passed!")
    os.exit(0)
else
    print("Health check failed!")
    for _, failure in ipairs(failures) do
        print(string.format("- %s: %s", failure.check, failure.error))
    end
    os.exit(1)
end
