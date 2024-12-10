#!/usr/bin/env lua

local lfs = require("luafilesystem")
local json = require("dkjson")
local http = require("http.request")

local M = {}

-- Configuration
local CONFIG = {
    output_dir = "/app/data/datasets",
    image_dir = "/app/images/processed",
    temp_dir = "/app/images/temp",
    batch_size = 100,
    min_image_size = 224,  -- minimum dimension for ML models
    formats = {
        "tfrecord",
        "json",
        "csv"
    }
}

-- Initialize Python bridge for dataset creation
local py = require("python")
py.execute([[
import tensorflow as tf
import pandas as pd
import cv2
import numpy as np
from PIL import Image

def create_tf_example(image_path, metadata):
    try:
        # Read and process image
        image = tf.io.read_file(image_path)
        
        # Create feature dictionary
        feature = {
            'image': tf.train.Feature(
                bytes_list=tf.train.BytesList(value=[image.numpy()])
            ),
            'path': tf.train.Feature(
                bytes_list=tf.train.BytesList(value=[image_path.encode()])
            )
        }
        
        # Add metadata features
        for key, value in metadata.items():
            if isinstance(value, (int, bool)):
                feature[key] = tf.train.Feature(
                    int64_list=tf.train.Int64List(value=[value])
                )
            elif isinstance(value, float):
                feature[key] = tf.train.Feature(
                    float_list=tf.train.FloatList(value=[value])
                )
            elif isinstance(value, str):
                feature[key] = tf.train.Feature(
                    bytes_list=tf.train.BytesList(value=[value.encode()])
                )
        
        return tf.train.Example(
            features=tf.train.Features(feature=feature)
        )
    except Exception as e:
        print(f"Error creating TF example for {image_path}: {str(e)}")
        return None
]])

-- Validate image
local function validate_image(path)
    local success, image = pcall(py.eval, string.format([[
try:
    img = cv2.imread("%s")
    if img is None:
        return False
    height, width = img.shape[:2]
    return height >= %d and width >= %d
except:
    return False
    ]], path, CONFIG.min_image_size, CONFIG.min_image_size))
    
    return success and image
end

-- Create TFRecord dataset
function M.create_tfrecord(images, metadata, output_path)
    py.execute(string.format([[
with tf.io.TFRecordWriter("%s") as writer:
    for image_path, meta in zip(%s, %s):
        example = create_tf_example(image_path, meta)
        if example:
            writer.write(example.SerializeToString())
    ]], output_path, py.eval(json.encode(images)), py.eval(json.encode(metadata))))
end

-- Create JSON dataset
function M.create_json(images, metadata, output_path)
    local dataset = {}
    for i, image_path in ipairs(images) do
        table.insert(dataset, {
            image_path = image_path,
            metadata = metadata[i]
        })
    end
    
    local file = io.open(output_path, "w")
    if file then
        file:write(json.encode(dataset, {indent = true}))
        file:close()
        return true
    end
    return false
end

-- Create CSV dataset
function M.create_csv(images, metadata, output_path)
    -- Convert to pandas DataFrame in Python
    py.execute(string.format([[
data = []
for image_path, meta in zip(%s, %s):
    row = {'image_path': image_path}
    row.update(meta)
    data.append(row)
df = pd.DataFrame(data)
df.to_csv("%s", index=False)
    ]], py.eval(json.encode(images)), py.eval(json.encode(metadata)), output_path))
end

-- Process images and create dataset
function M.create_dataset(image_dir, options)
    options = options or {}
    local formats = options.formats or CONFIG.formats
    local output_dir = options.output_dir or CONFIG.output_dir
    
    -- Collect and validate images
    local valid_images = {}
    local valid_metadata = {}
    
    for file in lfs.dir(image_dir) do
        if file ~= "." and file ~= ".." then
            local path = image_dir .. "/" .. file
            if validate_image(path) then
                table.insert(valid_images, path)
                table.insert(valid_metadata, {
                    filename = file,
                    timestamp = os.date("%Y-%m-%d %H:%M:%S"),
                    size = lfs.attributes(path, "size")
                })
            end
        end
    end
    
    -- Create datasets in requested formats
    local timestamp = os.date("%Y%m%d_%H%M%S")
    local results = {}
    
    for _, format in ipairs(formats) do
        local output_path = string.format(
            "%s/dataset_%s.%s",
            output_dir,
            timestamp,
            format
        )
        
        if format == "tfrecord" then
            M.create_tfrecord(valid_images, valid_metadata, output_path)
        elseif format == "json" then
            M.create_json(valid_images, valid_metadata, output_path)
        elseif format == "csv" then
            M.create_csv(valid_images, valid_metadata, output_path)
        end
        
        results[format] = output_path
    end
    
    return results
end

return M