-- Arduino compile / upload / serial monitor for .ino buffers.
--
-- Board FQBN and port are auto-detected from `arduino-cli board list` at
-- run time, so a changing port (e.g. ttyACM0 -> ttyACM1) just works.
--
-- `setup()` registers a FileType autocmd that binds <leader><F5> (buffer-
-- local) to a picker menu offering Compile / Upload / Monitor. The
-- buffer-local map shadows the global <leader><F5> (UndotreeToggle) only
-- inside arduino buffers.

local M = {}

--- Detect the first connected board with a matching FQBN.
--- Returns { port, fqbn, name } or nil (after notifying the user).
local function detect()
    local out = vim.fn.system({ "arduino-cli", "board", "list", "--format", "json" })
    if vim.v.shell_error ~= 0 then
        vim.notify("arduino-cli board list failed:\n" .. out, vim.log.levels.ERROR)
        return nil
    end
    local ok, data = pcall(vim.json.decode, out)
    if not ok or type(data) ~= "table" or not data.detected_ports then
        vim.notify("Could not parse arduino-cli board list output", vim.log.levels.ERROR)
        return nil
    end
    for _, dp in ipairs(data.detected_ports) do
        local boards = dp.matching_boards
        if boards and boards[1] and boards[1].fqbn and dp.port and dp.port.address then
            return { port = dp.port.address, fqbn = boards[1].fqbn, name = boards[1].name }
        end
    end
    vim.notify("No Arduino board detected. Is it plugged in?", vim.log.levels.WARN)
    return nil
end

--- Run a shell command string in a bottom terminal split so output
--- (and the serial monitor) stays interactive and visible.
local function run_shell(shell_cmd, title)
    vim.notify(title, vim.log.levels.INFO)
    vim.cmd("botright split | resize 15 | terminal " .. shell_cmd)
    vim.cmd("startinsert")
end

--- Run an arduino-cli invocation (given as an argv list) in a terminal.
local function run_term(cmd, title)
    local parts = vim.tbl_map(vim.fn.shellescape, cmd)
    run_shell(table.concat(parts, " "), title)
end

function M.compile()
    local b = detect()
    if not b then return end
    local sketch = vim.fn.expand("%:p:h")
    run_term({ "arduino-cli", "compile", "--fqbn", b.fqbn, sketch },
        "Arduino: compiling (" .. b.name .. ")")
end

function M.upload()
    local b = detect()
    if not b then return end
    local sketch = vim.fn.expand("%:p:h")
    run_term({ "arduino-cli", "compile", "--upload", "-p", b.port, "--fqbn", b.fqbn, sketch },
        "Arduino: compile + upload (" .. b.name .. " @ " .. b.port .. ")")
end

function M.monitor()
    local b = detect()
    if not b then return end
    run_term({ "arduino-cli", "monitor", "-p", b.port },
        "Arduino: serial monitor (" .. b.port .. ")")
end

--- Compile + upload, then open the serial monitor (only if upload succeeds).
function M.upload_monitor()
    local b = detect()
    if not b then return end
    local sketch = vim.fn.expand("%:p:h")
    local esc = vim.fn.shellescape
    local upload = table.concat(vim.tbl_map(esc,
        { "arduino-cli", "compile", "--upload", "-p", b.port, "--fqbn", b.fqbn, sketch }), " ")
    local monitor = table.concat(vim.tbl_map(esc,
        { "arduino-cli", "monitor", "-p", b.port }), " ")
    run_shell(upload .. " && " .. monitor,
        "Arduino: upload + monitor (" .. b.name .. " @ " .. b.port .. ")")
end

--- vim.ui.select picker between the three actions.
function M.menu()
    local actions = {
        { label = "Compile", run = M.compile },
        { label = "Upload (compile + flash)", run = M.upload },
        { label = "Monitor (serial)", run = M.monitor },
        { label = "Upload + Monitor", run = M.upload_monitor },
    }
    vim.ui.select(actions, {
        prompt = "Arduino:",
        format_item = function(item) return item.label end,
    }, function(choice)
        if choice then choice.run() end
    end)
end

--- Register the buffer-local keymap for arduino filetype buffers.
function M.setup()
    vim.api.nvim_create_autocmd("FileType", {
        pattern = "arduino",
        callback = function(ev)
            vim.keymap.set("n", "<leader><F5>", M.menu,
                { buffer = ev.buf, silent = true, desc = "Arduino: compile/upload/monitor menu" })
        end,
    })
end

return M
