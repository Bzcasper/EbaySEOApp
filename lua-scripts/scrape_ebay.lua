#!/usr/bin/env lua

local http = require("http.request")
local json = require("dkjson")
local lfs = require("luafilesystem")

local M = {}

-- Configuration
local CONFIG = {
    base_url = "https://www.ebay.com/sch/i.html",
    max_pages = 10,
    delay = 2,  -- seconds between requests
    user_agent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
    categories = {
        "Electronics",
        "Fashion",
        "Home & Garden"
    }
}

-- Helper function to make HTTP requests
local function make_request(url)
    local headers = {
        ["User-Agent"] = CONFIG.user_agent,
        ["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        ["Accept-Language"] = "en-US,en;q=0.5"
    }
    
    local req = http.new_from_uri(url)
    for k, v in pairs(headers) do
        req.headers:upsert(k, v)
    end
    
    local headers, stream = req:go()
    if not headers then
        return nil, "Failed to connect"
    end
    
    local body = stream:get_body_as_string()
    if not body then
        return nil, "Failed to read response"
    end
    
    return body
end

-- Parse listing data from HTML
local function parse_listing(html_element)
    -- Basic parsing of key elements
    local title = html_element:match('class="s%-item__title".->(.-)</h3>')
    local price = html_element:match('class="s%-item__price".->(.-)</span>')
    local image_url = html_element:match('src="(https://i%.ebayimg%.com/[^"]+)"')
    local item_url = html_element:match('href="(https://www%.ebay%.com/itm/[^"]+)"')
    
    if not (title and price) then
        return nil
    end
    
    return {
        title = title:gsub("<[^>]+>", ""):gsub("%s+", " "):trim(),
        price = price:gsub("[^%d%.]", ""),
        image_url = image_url,
        url = item_url,
        timestamp = os.date("%Y-%m-%d %H:%M:%S")
    }
end

-- Scrape a single page
local function scrape_page(url)
    local body, err = make_request(url)
    if not body then
        return nil, err
    end
    
    local listings = {}
    for listing_html in body:gmatch('<div class="s%-item__info.-</div>') do
        local listing_data = parse_listing(listing_html)
        if listing_data then
            table.insert(listings, listing_data)
        end
    end
    
    return listings
end

-- Main scraping function
function M.scrape_listings(keywords, options)
    options = options or {}
    local max_pages = options.max_pages or CONFIG.max_pages
    local results = {}
    
    for _, keyword in ipairs(keywords) do
        for page = 1, max_pages do
            local url = string.format(
                "%s?_nkw=%s&_pgn=%d",
                CONFIG.base_url,
                keyword:gsub("%s+", "+"),
                page
            )
            
            local page_listings, err = scrape_page(url)
            if page_listings then
                for _, listing in ipairs(page_listings) do
                    listing.keyword = keyword
                    table.insert(results, listing)
                end
            end
            
            -- Respect rate limiting
            os.execute("sleep " .. CONFIG.delay)
        end
    end
    
    return results
end

-- Save results to JSON file
function M.save_results(results, filename)
    local file = io.open(filename, "w")
    if not file then
        return false, "Could not open file for writing"
    end
    
    local json_str = json.encode(results, { indent = true })
    file:write(json_str)
    file:close()
    
    return true
end

return M