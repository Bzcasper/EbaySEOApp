local scrape_ebay = require('scrape_ebay')
local push_to_database = require('push_to_database')
local augment_images = require('augment_images')
local analyze_image = require('analyze_image')
local generate_seo_description = require('generate_seo_desc')
local save_dataset = require('save_dataset')
local create_image_dataset = require('create_image_dataset')
local create_image_text_dataset = require('create_image_text_dataset')

local lfs = require('luafilesystem')

-- Function to execute shell commands and log output
local function exec_cmd(cmd)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return result
end

-- Logging function
local function log(message)
    local log_file = io.open('/app/logs/pipeline.log', 'a')
    log_file:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. message .. "\n")
    log_file:close()
end

function main()
    -- Get environment variables
    local search_query = os.getenv('SEARCH_QUERY') or 'jewelry'
    local ebay_api_key_sandbox = os.getenv('EBAY_API_Key_Sandbox') or 'RobertCa-Listinga-SBX-b5c1efb54-3eaf7b3c'
    local ebay_dev_id = os.getenv('EBAY_Dev_ID') or '4fd523b9-bd4d-4ae1-ab11-d29494b3b0da'
    local ebay_cert_id_sandbox = os.getenv('EBAY_Cert_ID_Sandbox') or 'SBX-5c1efb54b1f1-8d59-49e8-aeb8-dc47'
    local ebay_api_key_production = os.getenv('EBAY_API_Key_Production') or 'RobertCa-Listinga-PRD-c2946e49a-8e5456d6'
    local ebay_cert_id_production = os.getenv('EBAY_Cert_ID_Production') or 'PRD-2946e49a31e2-ae4b-4747-bf08-16f9'
    local claude_api_key = os.getenv('CLAUDE_API_Key') or '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'
    local cloud_service = os.getenv('CLOUD_SERVICE') or 'Google' -- or 'AWS'
    local google_vision_credentials = os.getenv('GOOGLE_VISION_CREDENTIALS') or 'C:\Users\Bobby\D\EbaySEOApp\jewelry-search-project-7a34899c68f4.json'
    local aws_access_key = os.getenv('AWS_ACCESS_KEY') or 'your_aws_access_key'
    local aws_secret_key = os.getenv('AWS_SECRET_KEY') or 'your_aws_secret_key'
    local aws_region = os.getenv('AWS_REGION') or 'us-east-1'
    local llm = os.getenv('LLM') or 'Anthropic' -- or 'OpenAI'
    local llm_api_key = os.getenv('LLM_API_Key') or 'your_llm_api_key'
    local storage_service = os.getenv('STORAGE_SERVICE') or 'Google' -- or 'AWS'
    local storage_bucket = os.getenv('STORAGE_BUCKET') or 'my-jewelry-data'

    log('Pipeline started for search query: ' .. search_query)

    -- Step 1: Scrape eBay products
    log('Scraping eBay products...')
    local products = scrape_ebay(search_query)
    log('Found ' .. #products .. ' products.')

    -- Step 2: Push images to database
    log('Pushing images to database...')
    push_to_database('/app/images/input')

    -- Step 3: Download images
    log('Downloading images...')
    for _, product in ipairs(products) do
        -- Create a safe filename
        local safe_title = product.title:gsub('[^%w_-]', '_')
        product.file_name = safe_title .. '.jpg'
        local input_path = '/app/images/input/' .. product.file_name
        local download_cmd = string.format('curl -s -L -o "%s" "%s"', input_path, product.image_url)
        exec_cmd(download_cmd)
        product.image_path = input_path
        log('Downloaded: ' .. input_path)
    end

    -- Step 4: Augment images
    log('Augmenting images...')
    augment_images('/app/images/input', '/app/images/output')

    -- Step 5: Analyze images and generate SEO content
    log('Analyzing images and generating SEO content...')
    for _, product in ipairs(products) do
        local aug_file = '/app/images/output/aug_' .. product.file_name
        -- Analyze image
        local labels = {}
        if cloud_service == 'Google' then
            labels = analyze_image(aug_file, cloud_service, google_vision_credentials)
        elseif cloud_service == 'AWS' then
            labels = analyze_image(aug_file, cloud_service, {Access_Key = aws_access_key, Secret_Key = aws_secret_key, Region = aws_region})
        else
            labels = {}
        end
        product.labels = labels
        -- Generate SEO description
        local keywords = table.concat(product.labels, ', ')
        if llm == 'OpenAI' then
            product.seo_description = generate_seo_description(product.title, keywords, llm, llm_api_key)
        elseif llm == 'Anthropic' then
            product.seo_description = generate_seo_description(product.title, keywords, llm, llm_api_key)
        else
            product.seo_description = "Invalid LLM choice."
        end
        -- Update image path
        product.image_path = aug_file
        log('Processed product: ' .. product.title)
    end

    -- Step 6: Save to dataset
    log('Saving dataset...')
    save_dataset(products)

    -- Step 7: Create high-quality image dataset
    log('Creating high-quality image dataset...')
    create_image_dataset('/app/images/output', '/app/data/high_quality_images.csv')

    -- Step 8: Create image-text dataset
    log('Creating image-text dataset...')
    create_image_text_dataset('/app/data/dataset.db', '/app/data/image_text_dataset.csv')

    -- Step 9: Upload datasets to cloud storage with train and val splits
    log('Uploading datasets to cloud storage with train and val splits...')
    local cloud_upload_cmd = ''
    if storage_service == 'Google' then
        cloud_upload_cmd = string.format('python3 /app/python_src/upload_to_cloud.py "/app/data/high_quality_images.csv" "Google" "%s" "/app/cloud-scripts/google_credentials.json"', storage_bucket)
        exec_cmd(cloud_upload_cmd)
        cloud_upload_cmd = string.format('python3 /app/python_src/upload_to_cloud.py "/app/data/image_text_dataset.csv" "Google" "%s" "/app/cloud-scripts/google_credentials.json"', storage_bucket)
        exec_cmd(cloud_upload_cmd)
    elseif storage_service == 'AWS' then
        cloud_upload_cmd = string.format('python3 /app/python_src/upload_to_cloud.py "/app/data/high_quality_images.csv" "AWS" "%s" "" "%s" "%s" "%s"', storage_bucket, aws_region, aws_access_key, aws_secret_key)
        exec_cmd(cloud_upload_cmd)
        cloud_upload_cmd = string.format('python3 /app/python_src/upload_to_cloud.py "/app/data/image_text_dataset.csv" "AWS" "%s" "" "%s" "%s" "%s"', storage_bucket, aws_region, aws_access_key, aws_secret_key)
        exec_cmd(cloud_upload_cmd)
    else
        log('Invalid storage service choice.')
    end

    log('Pipeline completed successfully.')
    print('Pipeline completed successfully. Check logs for details.')
end

-- Execute the main function
main()
