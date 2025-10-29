local setup_dap = function()
    local dap = require("dap")
    local pythonPath = function()
        -- debugpy supports launching an application with a different interpreter then the one used to launch debugpy itself.
        -- The code below looks for a `venv` or `.venv` folder in the current directly and uses the python within.
        -- You could adapt this - to for example use the `VIRTUAL_ENV` environment variable.
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
            -- The first three options are required by nvim-dap
            type = 'python', -- the type here established the link to the adapter definition: `dap.adapters.python`
            request = 'launch',
            name = "Launch File",
            -- Options below are for debugpy, see https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for supported options

            program = "${file}", -- This configuration will launch the current file if used.
            pythonPath = pythonPath(),
        }, {
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
    } }

    local config = {
        type = "python",
        request = "launch",
        name = "Omni launch Configuration",
        program = "",
        justMyCode = false,
        pythonPath = pythonPath(),
        console = "integratedTerminal",
    }
    local results = {}
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
        "nvim-neotest/nvim-nio" },
    opts = {
        layouts = {
            {
                elements = {
                    { id = "console", size = 0.2 },
                    -- { id = "repl",    size = 0.8 },
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
            desc = "Dap UI"
        },
    },
}
