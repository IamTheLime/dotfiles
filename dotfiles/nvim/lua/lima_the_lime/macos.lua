
local uname = vim.fn.system("uname -a");
if not string.match(uname, "WSL2") then
    vim.opt.clipboard:append { 'unnamedplus' }
end
