local M = {}

-- Configuration for plugins that support hot reloading
-- Format: { pattern = "module.pattern", entry_point = "module.to.require", reset_globals = function() }
M.plugins = {}

-- Register a plugin for hot reloading
---@param name string Plugin identifier (e.g., "journal")
---@param config table Configuration with pattern, entry_point, and optional reset_globals function
function M.register_plugin(name, config)
    if not config.pattern then
        error("Plugin config must have a 'pattern' field (lua pattern for module matching)")
    end
    
    M.plugins[name] = config
    print("📦 Registered hot-reload for: " .. name)
end

-- Reloads all modules matching a pattern
---@param pattern string Lua pattern to match module names
---@return string[] List of reloaded module names
function M.reload_modules(pattern)
    local reloaded = {}
    
    for module_name, _ in pairs(package.loaded) do
        if module_name:match(pattern) then
            package.loaded[module_name] = nil
            table.insert(reloaded, module_name)
        end
    end
    
    return reloaded
end

-- Reload a specific registered plugin
---@param name string Plugin identifier
function M.reload_plugin(name)
    local config = M.plugins[name]
    
    if not config then
        print("❌ Plugin '" .. name .. "' not registered for hot reload")
        print("Available plugins: " .. vim.inspect(vim.tbl_keys(M.plugins)))
        return
    end
    
    print("🔄 Reloading " .. name .. "...")
    
    -- Reset global state if configured
    if config.reset_globals then
        config.reset_globals()
    end
    
    -- Unload all matching modules
    local reloaded = M.reload_modules(config.pattern)
    
    -- Re-require entry point if specified
    if config.entry_point then
        local success, result = pcall(require, config.entry_point)
        if not success then
            print("❌ Error loading entry point: " .. result)
            return
        end
    end
    
    -- Pretty print results
    if #reloaded > 0 then
        print("✓ Reloaded " .. #reloaded .. " modules:")
        for _, module_name in ipairs(reloaded) do
            print("  • " .. module_name)
        end
    else
        print("⚠ No modules found matching pattern: " .. config.pattern)
    end
end

-- Reload all registered plugins
function M.reload_all()
    print("🔄 Reloading all registered plugins...")
    local count = 0
    for name, _ in pairs(M.plugins) do
        M.reload_plugin(name)
        count = count + 1
    end
    print("✓ Reloaded " .. count .. " plugins")
end

-- Inspect what modules are currently loaded for a pattern
---@param pattern string Lua pattern to match module names
function M.inspect_loaded(pattern)
    print("Loaded modules matching '" .. pattern .. "':")
    local found = false
    for module_name, _ in pairs(package.loaded) do
        if module_name:match(pattern) then
            print("  • " .. module_name)
            found = true
        end
    end
    if not found then
        print("  (none)")
    end
end

-- List all registered plugins
function M.list_plugins()
    print("Registered hot-reload plugins:")
    if vim.tbl_count(M.plugins) == 0 then
        print("  (none)")
    else
        for name, config in pairs(M.plugins) do
            print("  • " .. name .. " -> " .. config.pattern)
        end
    end
end

return M
