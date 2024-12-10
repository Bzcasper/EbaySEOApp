#!/usr/bin/env lua

local json = require("dkjson")
local http = require("http.request")

local M = {}

-- Configuration
local CONFIG = {
    max_description_length = 5000,
    min_description_length = 100,
    keywords_per_description = 10,
    templates = {
        "Discover %s - %s perfect for %s. %s",
        "Experience the quality of %s featuring %s. %s",
        "Premium %s with %s - ideal for %s. %s"
    }
}

-- Initialize Python bridge for NLP processing
local function init_python()
    local py = require("python")
    py.execute([[
import sys
sys.path.append("/app/python_src")
from generate_seo import SEOGenerator
generator = SEOGenerator()
    ]])
    return py
end

local py = init_python()

-- Extract key features from item and analysis
local function extract_features(item, analysis)
    local features = {
        title = item.title,
        price = item.price,
        condition = item.condition,
        brand = item.brand,
        category = item.category
    }
    
    if analysis then
        features.visual_attributes = analysis.attributes or {}
        features.detected_objects = analysis.objects or {}
        features.colors = analysis.colors or {}
        features.quality_score = analysis.quality_score
    end
    
    return features
end

-- Generate keywords from features
local function generate_keywords(features)
    return py.eval(string.format([[
generator.generate_keywords(%s)
    ]], json.encode(features)))
end

-- Generate description using template and features
local function generate_description(features, keywords)
    return py.eval(string.format([[
generator.generate_description(%s, %s)
    ]], json.encode(features), json.encode(keywords)))
end

-- Main generation function
function M.generate(item, analysis)
    -- Extract features from item and analysis
    local features = extract_features(item, analysis)
    
    -- Generate relevant keywords
    local keywords = generate_keywords(features)
    
    -- Generate SEO description
    local description = generate_description(features, keywords)
    
    -- Format and structure the output
    return {
        description = description,
        keywords = keywords,
        metadata = {
            title = item.title,
            timestamp = os.date("%Y-%m-%d %H:%M:%S"),
            source = "ebay",
            category = item.category,
            features = features
        }
    }
end

-- Batch process items
function M.batch_generate(items)
    local results = {}
    for _, item in ipairs(items) do
        local seo_data = M.generate(item.item, item.analysis)
        if seo_data then
            table.insert(results, seo_data)
        end
    end
    return results
end

return M