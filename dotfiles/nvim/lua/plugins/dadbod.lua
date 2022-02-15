return {
    'kristijanhusak/vim-dadbod-ui',
    dependencies = {
        { 'tpope/vim-dadbod',                     lazy = true },
        { 'kristijanhusak/vim-dadbod-completion', ft = { 'sql', 'mysql', 'plsql' }, lazy = true },
    },
    cmd          = {
        'DBUI',
        'DBUIToggle',
        'DBUIAddConnection',
        'DBUIFindBuffer',
    },
    init         = function()
        -- Your DBUI configuration
        vim.g.db_ui_use_nerd_fonts = 1
    end,
    config       = function()
        local status, dadbod_config = pcall(require, "lima_the_lime/dadbodgitignore")
        if (not status) then return end
        vim.g.dbs = dadbod_config.dbs
        -- this is configured on a dadbod_gitignore.lua file
    end
}
