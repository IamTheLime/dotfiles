return {
    'nvim-pack/nvim-spectre',
    config = function()
        require('spectre').setup({
            live_update = true, -- auto execute search again when you write to any file in vim
            default = {
                replace = {
                   cmd="rg" 
                }
            }
        })
        vim.keymap.set('n', '<leader>S', '<cmd>lua require("spectre").open()<CR>', {
            desc = "Open Spectre"
        })
        vim.keymap.set('n', '<leader>sw', '<cmd>lua require("spectre").open_visual({select_word=true})<CR>', {
            desc = "Search current word"
        })
        vim.keymap.set('v', '<leader>sw', '<esc><cmd>lua require("spectre").open_visual()<CR>', {
            desc = "Search current word"
        })
        vim.keymap.set('n', '<leader>sp', '<cmd>lua require("spectre").open_file_search({select_word=true})<CR>', {
            desc = "Search on current file"
        })
    end
}
