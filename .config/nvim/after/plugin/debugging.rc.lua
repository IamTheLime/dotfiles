local dap = require('dap')

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
end;

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
        name = "default_launc_configuration",
        -- Options below are for debugpy, see https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for supported options

        program = "${file}", -- This configuration will launch the current file if used.
        pythonPath = pythonPath(),
    }, {
    -- The first three options are required by nvim-dap
    type = 'python', -- the type here established the link to the adapter definition: `dap.adapters.python`
    request = 'launch',
    name = "custom_launch_springer",
    -- Options below are for debugpy, see https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for supported options

    program = "${workspaceFolder}/app/springer_server.py", -- This configuration will launch the current file if used.
    cwd = "${workspaceFolder}/app",
    pythonPath = pythonPath(),
},
}

vim.keymap.set("n", "<Leader>bp", function() dap.toggle_breakpoint() end)

local dapui = require("dapui")

dapui.setup()

vim.keymap.set('n', '<Leader>d', function()
    dapui.toggle()
end)

vim.fn.sign_define('DapBreakpoint', { text = '⚫', texthl = '', linehl = '', numhl = '' })
vim.fn.sign_define('DapStopped', { text = '▶️', texthl = '', linehl = '', numhl = '' })
