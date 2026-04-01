-- Shared fixed-bottom terminal pane for all DAP processes.
-- Always opens at the bottom of the screen, reuses the same window on restart.
local dap_term = { winid = nil, bufnr = nil, job_id = nil }
local DAP_TERM_HEIGHT = 15

local function get_or_create_dap_term_win()
    local prev_win = vim.api.nvim_get_current_win()

    if dap_term.winid and vim.api.nvim_win_is_valid(dap_term.winid) then
        vim.api.nvim_set_current_win(dap_term.winid)
        -- Clean up old buffer if present
        if dap_term.bufnr and vim.api.nvim_buf_is_valid(dap_term.bufnr) then
            if dap_term.job_id then
                pcall(vim.fn.jobstop, dap_term.job_id)
                dap_term.job_id = nil
            end
            vim.api.nvim_buf_delete(dap_term.bufnr, { force = true })
        end
    else
        vim.cmd('botright ' .. DAP_TERM_HEIGHT .. 'split')
        dap_term.winid = vim.api.nvim_get_current_win()
        vim.api.nvim_win_set_option(dap_term.winid, 'winfixheight', true)
    end

    return prev_win
end

local setup_dap = function()
    local dap = require("dap")

    -- Route all DAP integrated terminals to the fixed bottom pane
    dap.defaults.fallback.terminal_win_cmd = function()
        local prev_win = get_or_create_dap_term_win()
        -- DAP expects us to return the buffer number; it will run the process in it
        vim.cmd('enew')
        local bufnr = vim.api.nvim_get_current_buf()
        dap_term.bufnr = bufnr
        dap_term.job_id = nil -- DAP manages the job for integrated terminals
        vim.api.nvim_set_current_win(prev_win)
        return bufnr
    end

    local pythonPath = function()
        local cwd = vim.fn.getcwd()
        if vim.fn.executable(cwd .. '/venv/bin/python') == 1 then
            return cwd .. '/venv/bin/python'
        elseif vim.fn.executable(cwd .. '/.local/bin/python') == 1 then
            return cwd .. '/.local/bin/python'
        elseif vim.fn.executable(cwd .. '/.venv/bin/python') == 1 then
            return cwd .. '/.venv/bin/python'
        else
            return '/usr/bin/python'
        end
    end

    dap.adapters.python = {
        type = 'executable',
        command = pythonPath(),
        args = { '-m', 'debugpy.adapter' },
    }

    dap.configurations.python = {
        {
            type = 'python',
            request = 'launch',
            name = "Launch File",
            program = "${file}",
            pythonPath = pythonPath(),
        },
        {
            name = "Pytest: Current File",
            type = "python",
            request = "launch",
            module = "pytest",
            args = {
                "${file}",
                "-sv",
                "--log-cli-level=INFO",
                "--log-file=test_out.log"
            },
            console = "integratedTerminal",
            pythonPath = pythonPath(),
        }
    }

    local config = {
        type = "python",
        request = "launch",
        name = "Omni launch Configuration",
        program = "",
        justMyCode = true,
        pythonPath = pythonPath(),
        console = "integratedTerminal",
    }

    local function get_last_two_parts(path)
        local parts = {}
        for part in string.gmatch(path, "[^/]+") do
            table.insert(parts, part)
        end

        local count = #parts
        if count >= 2 then
            return parts[count - 1] .. "/" .. parts[count]
        elseif count == 1 then
            return parts[1]
        else
            return ""
        end
    end

    local utils = require("lima_the_lime/utils")
    for entry in string.gmatch(vim.fn.system("fd -d 3 -a '.*(server|main)\\.py'"), "[^%s]+") do
        local config_c = utils.deepcopy(config)
        config_c["program"] = entry
        config_c["name"] = config_c["name"] .. " " .. get_last_two_parts(entry)
        table.insert(dap.configurations.python, config_c)
    end

    -- ============================================
    -- KOTLIN DAP CONFIGURATION
    -- ============================================

    dap.adapters.kotlin = {
        type = 'executable',
        command = 'kotlin-debug-adapter',
    }

    -- Helper function to find Gradle project root
    local function find_gradle_root()
        local cwd = vim.fn.getcwd()
        -- Check if we're in a multi-module project (has app/ directory)
        if vim.fn.isdirectory(cwd .. "/app") == 1 then
            return cwd .. "/app"
        end
        return cwd
    end

    -- Helper function to extract mainClass from build.gradle.kts
    local function get_main_class()
        local gradle_file = find_gradle_root() .. "/build.gradle.kts"

        if vim.fn.filereadable(gradle_file) == 1 then
            local content = vim.fn.readfile(gradle_file)
            for _, line in ipairs(content) do
                local main = line:match('mainClass%s*=%s*"([^"]+)"')
                if main then
                    return main
                end
            end
        end

        return nil
    end

    -- Helper to build Gradle project and return classpath
    local function build_and_get_classpath()
        local project_root = find_gradle_root()
        local gradle_wrapper = vim.fn.getcwd() .. "/gradlew"

        -- Build the project first
        vim.notify("Building Kotlin project...", vim.log.levels.INFO)
        local build_cmd = string.format("cd %s && %s build -q", vim.fn.getcwd(), gradle_wrapper)
        vim.fn.system(build_cmd)

        if vim.v.shell_error ~= 0 then
            vim.notify("Build failed!", vim.log.levels.ERROR)
            return {}
        end

        vim.notify("Build successful!", vim.log.levels.INFO)

        -- Collect classpath entries
        local paths = {}

        -- Add compiled classes
        table.insert(paths, project_root .. "/build/classes/kotlin/main")
        table.insert(paths, project_root .. "/build/classes/java/main")

        -- Add resources
        table.insert(paths, project_root .. "/build/resources/main")

        -- Get runtime classpath from Gradle
        local classpath_cmd = string.format(
            "cd %s && %s dependencies --configuration runtimeClasspath | grep -E '\\.jar$' | sed 's/.*--- //' | sed 's/ (\\*)$//'",
            vim.fn.getcwd(),
            gradle_wrapper
        )

        local deps = vim.fn.systemlist(classpath_cmd)
        for _, dep in ipairs(deps) do
            if dep:match("%.jar$") then
                -- Try to find the jar in Gradle cache
                local jar_name = dep:match("([^:]+)%.jar")
                if jar_name then
                    local find_cmd = string.format(
                        "find ~/.gradle/caches -name '%s.jar' 2>/dev/null | head -1",
                        jar_name
                    )
                    local jar_path = vim.fn.system(find_cmd):gsub("%s+", "")
                    if jar_path ~= "" then
                        table.insert(paths, jar_path)
                    end
                end
            end
        end

        return paths
    end

    -- Spawns a gradle process in the shared DAP bottom terminal pane.
    -- Port polling is async via libuv timer so the editor stays responsive.
    -- Once the port is up, it auto-attaches via dap.run().
    local function gradle_spawn(label, cmd, port)
        -- Kill anything on the debug port from a previous run
        vim.fn.system('lsof -ti :' .. port .. ' | xargs kill -9 2>/dev/null')

        local prev_win = get_or_create_dap_term_win()
        vim.cmd('terminal ' .. cmd)
        dap_term.bufnr = vim.api.nvim_get_current_buf()
        dap_term.job_id = vim.b.terminal_job_id
        vim.api.nvim_set_current_win(prev_win)

        vim.notify("Waiting for JVM on :" .. port .. " (async)...", vim.log.levels.INFO)
    end

    local function poll_and_attach(port, attempts)
        attempts = attempts or 0
        if attempts >= 120 then
            vim.notify("Timed out waiting for JVM on :" .. port, vim.log.levels.WARN)
            return
        end
        vim.fn.jobstart('lsof -ti :' .. port .. ' 2>/dev/null', {
            stdout_buffered = true,
            on_stdout = function(_, data)
                local output = table.concat(data, '')
                if output ~= '' then
                    vim.schedule(function()
                        vim.notify("JVM ready on :" .. port .. ", attaching.", vim.log.levels.INFO)
                        dap.run({
                            type = 'kotlin',
                            request = 'attach',
                            name = 'auto-attach',
                            projectRoot = find_gradle_root(),
                            hostName = 'localhost',
                            port = port,
                            timeout = 30000,
                        })
                    end)
                else
                    -- Not ready yet, try again in 500ms
                    vim.defer_fn(function()
                        poll_and_attach(port, attempts + 1)
                    end, 500)
                end
            end,
        })
    end

    dap.configurations.kotlin = {
        -- Configuration 1: Launch with auto-build and classpath detection
        {
            type = 'kotlin',
            request = 'launch',
            name = 'Kotlin: Launch (Auto)',
            projectRoot = find_gradle_root,
            mainClass = function()
                local main = get_main_class()
                if main then
                    vim.notify("Using mainClass: " .. main, vim.log.levels.INFO)
                    return main
                end
                return vim.fn.input('Main class: ')
            end,
            classPaths = build_and_get_classpath,
        },

        -- Configuration 2: Attach to running Gradle app (RECOMMENDED)
        {
            type = 'kotlin',
            request = 'attach',
            name = 'Kotlin: Attach (Recommended)',
            projectRoot = find_gradle_root,
            hostName = 'localhost',
            port = 5005,
            timeout = 30000,
        },

        -- Configuration 3: Manual entry
        {
            type = 'kotlin',
            request = 'launch',
            name = 'Kotlin: Manual',
            projectRoot = find_gradle_root,
            mainClass = function()
                return vim.fn.input('Main class: ', 'org.limathelime.AppKt')
            end,
            classPaths = build_and_get_classpath,
        },

    }

    -- Async spawn-and-attach configs. These appear in the F5 picker alongside
    -- the standard configs above, but they spawn the process and poll
    -- asynchronously instead of blocking the editor.
    local async_kotlin_configs = {
        {
            name = 'Kotlin: bootRun',
            run = function()
                local port = vim.g.kotlin_debug_port or 5005
                gradle_spawn('bootRun', './gradlew bootRun --debug-jvm', port)
                poll_and_attach(port)
            end,
        },
        {
            name = 'Kotlin: Test',
            run = function()
                local port = vim.g.kotlin_debug_port or 5005
                local filter = vim.fn.input('Test filter (empty for all): ')
                local cmd = './gradlew test --debug-jvm'
                if filter ~= '' then
                    cmd = cmd .. ' --tests "' .. filter .. '"'
                end
                gradle_spawn('test', cmd, port)
                poll_and_attach(port)
            end,
        },
    }

    -- Override dap.continue() to inject async configs into the picker
    local original_continue = dap.continue
    dap.continue = function(opts)
        -- If a session is active, just continue normally
        if dap.session() then
            return original_continue(opts)
        end

        -- Build combined list: standard kotlin configs + async configs
        local configs = dap.configurations.kotlin or {}
        local items = {}
        for _, cfg in ipairs(configs) do
            table.insert(items, { name = cfg.name, type = 'config', config = cfg })
        end
        for _, acfg in ipairs(async_kotlin_configs) do
            table.insert(items, { name = acfg.name, type = 'async', run = acfg.run })
        end

        -- Check if we have configs for the current filetype too
        local ft = vim.bo.filetype
        if ft ~= 'kotlin' and dap.configurations[ft] then
            for _, cfg in ipairs(dap.configurations[ft]) do
                table.insert(items, { name = cfg.name, type = 'config', config = cfg })
            end
        end

        if #items == 0 then
            return original_continue(opts)
        end

        vim.ui.select(items, {
            prompt = 'Debug configuration:',
            format_item = function(item) return item.name end,
        }, function(choice)
            if not choice then return end
            if choice.type == 'async' then
                choice.run()
            else
                dap.run(choice.config)
            end
        end)
    end

    -- Keymaps
    vim.keymap.set('n', '<F5>', function() dap.continue() end)
    vim.keymap.set('n', '<F10>', function() dap.step_over() end)
    vim.keymap.set('n', '<F11>', function() dap.step_into() end)
    vim.keymap.set('n', '<F12>', function() dap.step_out() end)
    vim.keymap.set("n", "<Leader>bp", function() dap.toggle_breakpoint() end)

    vim.fn.sign_define('DapBreakpoint', { text = '🚨', texthl = '', linehl = '', numhl = '' })
    vim.fn.sign_define('DapStopped', { text = '💂', texthl = '', linehl = '', numhl = '' })
end

local toggle_dapui = function()
    local dapui = require("dapui")
    dapui.toggle()
end

local toggle_breakpoint = function()
    local dap = require("dap")
    dap.toggle_breakpoint()
end

return {
    "rcarriga/nvim-dap-ui",
    lazy = true,
    dependencies = {
        {
            "mfussenegger/nvim-dap",
            config = function()
                setup_dap()
            end
        },
        {
            "theHamsta/nvim-dap-virtual-text",
            config = function()
                require("nvim-dap-virtual-text").setup({
                    enabled = true,
                    enabled_commands = true
                })
            end
        },
        "nvim-neotest/nvim-nio"
    },
    opts = {
        layouts = {
            {
                elements = {
                    { id = "console", size = 0.2 },
                    { id = "repl",    size = 0.8 },
                },
                position = "right",
                size = 70,
            },
            {
                elements = {
                    { id = "scopes",      size = 0.50 },
                    { id = "breakpoints", size = 0.20 },
                    { id = "stacks",      size = 0.15 },
                    { id = "watches",     size = 0.15 },
                },
                position = "left",
                size = 50,
            },
        },
    },
    config = function(_, opts)
        local dapui = require("dapui")
        dapui.setup(opts)
    end,
    keys = {
        {
            "<leader>dd",
            function()
                toggle_dapui()
            end,
            desc = "Dap UI"
        },
        {
            "<leader>bp",
            function()
                toggle_breakpoint()
            end,
            desc = "Toggle Breakpoint"
        },
        {
            "<leader>bex",
            function()
                local dap = require("dap")
                dap.listeners.after.event_initialized["dap-exception-config"] = function()
                    dap.set_exception_breakpoints({ "raised", "uncaught" })
                end
                dap.set_exception_breakpoints({ "raised", "uncaught" })
            end,
            desc = "Break on Exceptions"
        }
    },
}
