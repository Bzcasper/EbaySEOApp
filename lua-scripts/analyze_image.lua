#!/usr/bin/env lua

local http = require("http.request")
local json = require("dkjson")
local lfs = require("luafilesystem")

local M = {}

-- Configuration
local CONFIG = {
    temp_dir = "/app/images/temp",
    cache_dir = "/app/images/cache",
    max_image_size = 5 * 1024 * 1024,  -- 5MB
    supported_formats = {
        jpg = true,
        jpeg = true,
        png = true,
        webp = true
    }
}

-- Initialize Python bridge for image processing
local function init_python()
    local py = require("python")
    py.execute([[
import sys
sys.path.append("/app/python_src")
from analyze_image import ImageAnalyzer
analyzer = ImageAnalyzer()
    ]])
    return py
end

local py = init_python()

-- Download image
local function download_image(url, filename)
    local headers = {
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    }
    
    local req = http.new_from_uri(url)
    for k, v in pairs(headers) do
        req.headers:upsert(k, v)
    end
    
    local headers, stream = req:go()
    if not headers then
        return false, "Download failed"
    end
    
    local body = stream:get_body_as_string()
    if not body then
        return false, "Failed to read image data"
    end
    
    local file = io.open(filename, "wb")
    if not file then
        return false, "Failed to open file for writing"
    end
    
    file:write(body)
    file:close()
    
    return true
end

-- Analyze image using Python module
function M.analyze(image_url)
    -- Create cache key from URL
    local cache_key = image_url:gsub("[^%w]", "_")
    local cache_file = string.format("%s/%s.json", CONFIG.cache_dir, cache_key)
    
    -- Check cache first
    local cached = io.open(cache_file, "r")
    if cached then
        local content = cached:read("*all")
        cached:close()
        return json.decode(content)
    end
    
    -- Download and analyze image
    local temp_file = string.format("%s/%s", CONFIG.temp_dir, cache_key)
    local success, err = download_image(image_url, temp_file)
    if not success then
        return nil, err
    end
    
    -- Analyze using Python
    local analysis = py.eval(string.format([[
analyzer.analyze_image("%s")
    ]], temp_file))
    
    -- Cache results
    local cache = io.open(cache_file, "w")
    if cache then
        cache:write(json.encode(analysis))
        cache:close()
    end
    
    -- Cleanup
    os.remove(temp_file)
    
    return analysis
end

-- Batch process images
function M.batch_analyze(urls)
    local results = {}
    for _, url in ipairs(urls) do
        local analysis = M.analyze(url)
        if analysis then
            table.insert(results, {
                url = url,
                analysis = analysis
            })
        end
    end
    return results
end

return M