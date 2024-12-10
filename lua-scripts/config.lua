local yaml = require("yaml")
local json = require("dkjson")

local M = {}
local config = nil

-- Helper function to split string by separator
local function split(str, sep)
    local fields = {}
    local pattern = string.format("([^%s]+)", sep)
    str:gsub(pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

-- Helper function to get nested table value
local function get_nested_value(tbl, path)
    local current = tbl
    for _, key in ipairs(path) do
        if type(current) ~= "table" then return nil end
        current = current[key]
    end
    return current
end

-- Helper function to set nested table value
local function set_nested_value(tbl, path, value)
    local current = tbl
    for i = 1, #path - 1 do
        local key = path[i]
        current[key] = current[key] or {}
        current = current[key]
    end
    current[path[#path]] = value
end

-- Load configuration
function M.load_config()
    if config then
        return config
    end

    local config_path = os.getenv("CONFIG_PATH") or "config/config.yaml"
    
    -- Try to load config file
    local file = io.open(config_path, "r")
    if not file then
        error("Could not open config file: " .. config_path)
    end
    
    local content = file:read("*all")
    file:close()
    
    -- Parse YAML
    local ok, parsed = pcall(yaml.load, content)
    if not ok then
        error("Failed to parse config file: " .. parsed)
    end
    
    config = parsed
    
    -- Override with environment variables
    for key, value in pairs(os.environ) do
        if key:match("^EBAYSEO_") then
            local config_path = split(key:gsub("^EBAYSEO_", ""):lower(), "_")
            set_nested_value(config, config_path, value)
        end
    end
    
    return config
end

-- Get configuration value
function M.get(...)
    if not config then
        M.load_config()
    end
    
    local keys = {...}
    return get_nested_value(config, keys)
end

return M