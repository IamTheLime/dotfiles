local setup_dap = function()
    local dap = require("dap")
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

    -- Add keybinding to launch Gradle with debug in a terminal
    vim.keymap.set('n', '<leader>kg', function()
        -- Open a terminal and run gradlew with debug
        vim.cmd('vsplit')
        vim.cmd('terminal')
        vim.api.nvim_chan_send(vim.b.terminal_job_id, './gradlew run --debug-jvm\n')
        vim.cmd('wincmd p') -- Return to previous window

        vim.notify("Gradle running with debug enabled. Press <leader>dd then <F5> to attach.", vim.log.levels.INFO)
    end, { desc = 'Run Gradle with Debug' })

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
