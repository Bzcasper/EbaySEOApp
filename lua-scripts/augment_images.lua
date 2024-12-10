#!/usr/bin/env lua

local lfs = require("luafilesystem")
local json = require("dkjson")

-- Initialize Python bridge for image processing
local py = require("python")
py.execute([[
import sys
import cv2
import numpy as np
from PIL import Image
import albumentations as A

# Define augmentation pipeline
transform = A.Compose([
    A.RandomBrightnessContrast(p=0.5),
    A.HorizontalFlip(p=0.5),
    A.VerticalFlip(p=0.1),
    A.Rotate(limit=30, p=0.5),
    A.RandomScale(scale_limit=0.2, p=0.5),
    A.GaussNoise(p=0.3),
    A.Blur(blur_limit=3, p=0.3),
])

def augment_image(image_path, output_path, num_augmentations=5):
    try:
        # Read image
        image = cv2.imread(image_path)
        image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        
        augmented_paths = []
        for i in range(num_augmentations):
            # Apply augmentation
            augmented = transform(image=image)['image']
            
            # Save augmented image
            output_file = f"{output_path}/aug_{i}_{os.path.basename(image_path)}"
            Image.fromarray(augmented).save(output_file)
            augmented_paths.append(output_file)
            
        return augmented_paths
    except Exception as e:
        print(f"Error augmenting {image_path}: {str(e)}")
        return []
]])

local M = {}

-- Configuration
local CONFIG = {
    input_dir = "/app/images/input",
    output_dir = "/app/images/augmented",
    temp_dir = "/app/images/temp",
    num_augmentations = 5,
    supported_formats = {
        [".jpg"] = true,
        [".jpeg"] = true,
        [".png"] = true
    }
}

-- Create necessary directories
local function ensure_directories()
    for _, dir in ipairs({CONFIG.output_dir, CONFIG.temp_dir}) do
        lfs.mkdir(dir)
    end
end

-- Check if file is an image
local function is_image(filename)
    local ext = filename:match("%.(%w+)$"):lower()
    return CONFIG.supported_formats["." .. ext]
end

-- Process single image
function M.augment_single_image(image_path)
    ensure_directories()
    
    if not is_image(image_path) then
        return nil, "Unsupported image format"
    end
    
    local output_paths = py.eval(string.format([[
augment_image("%s", "%s", %d)
    ]], image_path, CONFIG.output_dir, CONFIG.num_augmentations))
    
    return output_paths
end

-- Process directory of images
function M.augment_directory(dir_path)
    ensure_directories()
    local results = {
        successful = {},
        failed = {}
    }
    
    for file in lfs.dir(dir_path) do
        if file ~= "." and file ~= ".." then
            local full_path = dir_path .. "/" .. file
            if is_image(file) then
                local success, outputs = pcall(M.augment_single_image, full_path)
                if success and outputs then
                    results.successful[full_path] = outputs
                else
                    results.failed[full_path] = outputs
                end
            end
        end
    end
    
    return results
end

-- Save augmentation metadata
function M.save_metadata(results, output_file)
    local metadata = {
        timestamp = os.date("%Y-%m-%d %H:%M:%S"),
        config = CONFIG,
        results = results
    }
    
    local file = io.open(output_file, "w")
    if file then
        file:write(json.encode(metadata, {indent = true}))
        file:close()
        return true
    end
    return false
end

-- Main augmentation function
function M.run_augmentation(input_path, options)
    options = options or {}
    local results
    
    if type(input_path) == "string" then
        local attr = lfs.attributes(input_path)
        if attr.mode == "directory" then
            results = M.augment_directory(input_path)
        else
            local success, outputs = pcall(M.augment_single_image, input_path)
            results = {
                successful = success and {[input_path] = outputs} or {},
                failed = not success and {[input_path] = outputs} or {}
            }
        end
    end
    
    -- Save metadata if requested
    if options.save_metadata then
        local metadata_file = CONFIG.output_dir .. "/augmentation_metadata.json"
        M.save_metadata(results, metadata_file)
    end
    
    return results
end

return M