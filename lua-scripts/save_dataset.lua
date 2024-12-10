#!/usr/bin/env lua

local json = require("dkjson")
local lfs = require("luafilesystem")

local M = {}

-- Configuration
local CONFIG = {
    data_dir = "/app/data",
    backup_dir = "/app/backup",
    formats = {
        json = true,
        csv = true,
        sqlite = true
    }
}

-- Create backup filename with timestamp
local function get_backup_filename(base_name, format)
    local timestamp = os.date("%Y%m%d_%H%M%S")
    return string.format("%s/%s_%s.%s", 
        CONFIG.backup_dir, 
        base_name, 
        timestamp, 
        format)
end

-- Save data as JSON
function M.save_json(data, filename)
    local file = io.open(filename, "w")
    if not file then
        return false, "Could not open file for writing"
    end
    
    local success, json_str = pcall(json.encode, data, { indent = true })
    if not success then
        file:close()
        return false, "JSON encoding failed"
    end
    
    file:write(json_str)
    file:close()
    
    return true
end

-- Save data as CSV
function M.save_csv(data, filename)
    local file = io.open(filename, "w")
    if not file then
        return false, "Could not open file for writing"
    end
    
    -- Write headers
    local headers = {}
    for key in pairs(data[1] or {}) do
        table.insert(headers, key)
    end
    file:write(table.concat(headers, ",") .. "\n")
    
    -- Write data
    for _, row in ipairs(data) do
        local values = {}
        for _, header in ipairs(headers) do
            local value = row[header] or ""
            -- Escape commas and quotes in values
            if type(value) == "string" and (value:find(",") or value:find('"')) then
                value = '"' .. value:gsub('"', '""') .. '"'
            end
            table.insert(values, value)
        end
        file:write(table.concat(values, ",") .. "\n")
    end
    
    file:close()
    return true
end

-- Create backup of database
function M.backup_database()
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local backup_file = string.format("%s/ebay_data_%s.db", 
        CONFIG.backup_dir, 
        timestamp)
    
    local command = string.format(
        "sqlite3 %s/ebay_data.db '.backup %s'",
        CONFIG.data_dir,
        backup_file
    )
    
    local success = os.execute(command)
    return success, backup_file
end

-- Save complete dataset
function M.save_dataset(data, options)
    options = options or {}
    local base_name = options.base_name or "ebay_dataset"
    local formats = options.formats or CONFIG.formats
    
    local results = {}
    
    -- Save in requested formats
    if formats.json then
        local filename = get_backup_filename(base_name, "json")
        local success = M.save_json(data, filename)
        results.json = { success = success, filename = filename }
    end
    
    if formats.csv then
        local filename = get_backup_filename(base_name, "csv")
        local success = M.save_csv(data, filename)
        results.csv = { success = success, filename = filename }
    end
    
    if formats.sqlite then
        local success, filename = M.backup_database()
        results.sqlite = { success = success, filename = filename }
    end
    
    return results
end

-- Clean up old backups
function M.cleanup_old_backups(days)
    days = days or 30
    local cutoff = os.time() - (days * 24 * 60 * 60)
    
    for file in lfs.dir(CONFIG.backup_dir) do
        if file ~= "." and file ~= ".." then
            local path = CONFIG.backup_dir .. "/" .. file
            local attr = lfs.attributes(path)
            if attr and attr.modification < cutoff then
                os.remove(path)
            end
        end
    end
end

return M