#!/usr/bin/env lua

local lfs = require("luafilesystem")
local json = require("dkjson")

local M = {}

-- Configuration
local CONFIG = {
    output_dir = "/app/data/datasets",
    image_dir = "/app/images/processed",
    text_dir = "/app/data/descriptions",
    temp_dir = "/app/images/temp",
    batch_size = 50,
    formats = {
        "json",
        "csv",
        "parquet"
    }
}

-- Initialize Python bridge for dataset creation
local py = require("python")
py.execute([[
import pandas as pd
import numpy as np
from PIL import Image
import base64
import io

def image_to_base64(image_path):
    try:
        with open(image_path, 'rb') as img_file:
            return base64.b64encode(img_file.read()).decode()
    except Exception as e:
        print(f"Error encoding image {image_path}: {str(e)}")
        return None

def create_paired_dataset(image_paths, texts, output_path, format):
    try:
        data = []
        for img_path, text in zip(image_paths, texts):
            img_data = image_to_base64(img_path)
            if img_data:
                data.append({
                    'image_path': img_path,
                    'image_data': img_data,
                    'text': text
                })
        
        df = pd.DataFrame(data)
        
        if format == 'csv':
            df.to_csv(output_path, index=False)
        elif format == 'parquet':
            df.to_parquet(output_path, index=False)
        elif format == 'json':
            df.to_json(output_path, orient='records', lines=True)
        
        return True
    except Exception as e:
        print(f"Error creating dataset: {str(e)}")
        return False
]])

-- Load text data
local function load_text_data(text_path)
    local file = io.open(text_path, "r")
    if not file then
        return nil
    end
    
    local content = file:read("*all")
    file:close()
    
    return json.decode(content)
end

-- Match images with text descriptions
local function match_pairs(image_dir, text_data)
    local pairs = {}
    
    for file in lfs.dir(image_dir) do
        if file ~= "." and file ~= ".." then
            local base_name = file:match("(.+)%..+")
            if base_name and text_data[base_name] then
                table.insert(pairs, {
                    image_path = image_dir .. "/" .. file,
                    text = text_data[base_name]
                })
            end
        end
    end
    
    return pairs
end

-- Create dataset with paired image-text data
function M.create_paired_dataset(image_dir, text_file, options)
    options = options or {}
    local formats = options.formats or CONFIG.formats
    local output_dir = options.output_dir or CONFIG.output_dir
    
    -- Load text data
    local text_data = load_text_data(text_file)
    if not text_data then
        return nil, "Failed to load text data"
    end
    
    -- Match images with text
    local pairs = match_pairs(image_dir, text_data)
    if #pairs == 0 then
        return nil, "No matching pairs found"
    end
    
    -- Separate images and texts
    local images = {}
    local texts = {}
    for _, pair in ipairs(pairs) do
        table.insert(images, pair.image_path)
        table.insert(texts, pair.text)
    end
    
    -- Create datasets in requested formats
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local results = {}
    
    for _, format in ipairs(formats) do
        local output_path = string.format(
            "%s/paired_dataset_%s.%s",
            output_dir,
            timestamp,
            format
        )
        
        local success = py.eval(string.format([[
create_paired_dataset(%s, %s, "%s", "%s")
        ]], py.eval(json.encode(images)), 
           py.eval(json.encode(texts)), 
           output_path,