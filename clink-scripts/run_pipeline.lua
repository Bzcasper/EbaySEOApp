-- Clink Lua script to create shortcuts for running different pipeline parts

-- Alias to run the full pipeline
clink.aliases[""runpipeline""] = function()
    clink.send('pwsh -NoLogo -NoProfile -File ""C:\\Users\\Bobby\\D\\EbaySEOApp\\RunPipeline.ps1""')
end

-- Alias to push images to database
clink.aliases[""pushdb""] = function()
    clink.send('pwsh -NoLogo -NoProfile -File ""C:\\Users\\Bobby\\D\\EbaySEOApp\\PushToDatabase.ps1""')
end

-- Alias to create datasets
clink.aliases[""createdatasets""] = function()
    clink.send('pwsh -NoLogo -NoProfile -File ""C:\\Users\\Bobby\\D\\EbaySEOApp\\CreateDatasets.ps1""')
end

-- Keybindings
clink.on_key("Ctrl+Shift+P", function()
    clink.send("runpipeline")
    return true
end)

clink.on_key("Ctrl+Shift+D", function()
    clink.send("pushdb")
    return true
end)

clink.on_key("Ctrl+Shift+S", function()
    clink.send("createdatasets")
    return true
end)
