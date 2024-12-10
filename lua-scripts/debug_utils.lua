local M = {}

-- Debug levels
M.DEBUG = 1
M.INFO = 2
M.WARNING = 3
M.ERROR = 4

-- Current debug level
M.current_level = M.INFO

-- Debug output file
M.log_file = "debug.log"

-- Initialize logging
function M.init(options)
    options = options or {}
    M.current_level = options.level or M.INFO
    M.log_file = options.log_file or "debug.log"
    
    -- Create log file
    local f = io.open(M.log_file, "a")
    if f then
        f:write("\n--- New Debug Session Started ---\n")
        f:close()
    end
end

-- Log message with level
function M.log(level, message, data)
    if level >= M.current_level then
        local timestamp = os.date("%Y-%m-%d %H:%M:%S")
        local level_str = "INFO"
        
        if level == M.DEBUG then level_str = "DEBUG"
        elseif level == M.WARNING then level_str = "WARNING"
        elseif level == M.ERROR then level_str = "ERROR"
        end
        
        local log_message = string.format("[%s] [%s] %s", timestamp, level_str, message)
        
        if data then
            local success, json_str = pcall(require("dkjson").encode, data)
            if success then
                log_message = log_message .. "\nData: " .. json_str
            end
        end
        
        -- Print to console
        print(log_message)
        
        -- Write to file
        local f = io.open(M.log_file, "a")
        if f then
            f:write(log_message .. "\n")
            f:close()
        end
    end
end

-- Convenience functions
function M.debug(message, data)
    M.log(M.DEBUG, message, data)
end

function M.info(message, data)
    M.log(M.INFO, message, data)
end

function M.warning(message, data)
    M.log(M.WARNING, message, data)
end

function M.error(message, data)
    M.log(M.ERROR, message, data)
end

-- Function call tracer
function M.trace_function(func, name)
    return function(...)
        M.debug("Entering function: " .. name)
        local start_time = os.clock()
        
        local results = {pcall(func, ...)}
        local success = table.remove(results, 1)
        
        local end_time = os.clock()
        local duration = end_time - start_time
        
        if success then
            M.debug(string.format("Exiting function: %s (duration: %.4fs)", name, duration))
            return table.unpack(results)
        else
            M.error(string.format("Error in function %s: %s", name, results[1]))
            error(results[1])
        end
    end
end

-- Memory usage tracker
function M.track_memory()
    local memory = collectgarbage("count")
    M.debug(string.format("Memory usage: %.2f KB", memory))
    return memory
end

return M