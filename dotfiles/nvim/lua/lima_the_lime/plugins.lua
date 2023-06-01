local status, packer = pcall(require, "packer")
if (not status) then
    print("Packer is not installed")
    return
end

vim.cmd [[packadd packer.nvim]]

packer.startup(function(use)
    use 'wbthomason/packer.nvim'
    use 'nvim-lualine/lualine.nvim' -- Statusline
    use 'nvim-lua/plenary.nvim'     -- Common utilities
    --use 'onsails/lspkind-nvim'    -- vscode-like pictograms
    use {
        'VonHeikemen/lsp-zero.nvim',
        branch = 'v2.x',
        requires = {
            -- LSP Support
            { 'neovim/nvim-lspconfig' },             -- Required
            { 'williamboman/mason.nvim' },           -- Optional
            { 'williamboman/mason-lspconfig.nvim' }, -- Optional

            -- Autocompletion
            { 'hrsh7th/nvim-cmp' },         -- Required
            { 'hrsh7th/cmp-nvim-lsp' },     -- Required
            { 'hrsh7th/cmp-buffer' },       -- Optional
            { 'hrsh7th/cmp-path' },         -- Optional
            { 'saadparwaiz1/cmp_luasnip' }, -- Optional
            { 'hrsh7th/cmp-nvim-lua' },     -- Optional

            -- Snippets
            { 'L3MON4D3/LuaSnip' },             -- Required
            { 'rafamadriz/friendly-snippets' }, -- Optional
            { "ray-x/lsp_signature.nvim" }
        }
    }
    use "jose-elias-alvarez/null-ls.nvim"
    use {
        "jay-babu/mason-null-ls.nvim",
    }
    use 'joechrisellis/lsp-format-modifications.nvim'
    use 'MunifTanjim/prettier.nvim' -- Prettier plugin for Neovim's built-in LSP client
    use 'williamboman/mason.nvim'
    use 'williamboman/mason-lspconfig.nvim'
    use({ 'rose-pine/neovim', as = 'rose-pine' })
    use 'L3MON4D3/LuaSnip'
    use 'mbbill/undotree'
    use {
        'nvim-treesitter/nvim-treesitter',
        run = function() require('nvim-treesitter.install').update({ with_sync = true }) end,
    }
    use {
        'tpope/vim-fugitive',
    }
    use 'kyazdani42/nvim-web-devicons' -- File icons
    use 'nvim-telescope/telescope.nvim'
    use 'nvim-telescope/telescope-file-browser.nvim'
    use 'windwp/nvim-autopairs'
    use 'windwp/nvim-ts-autotag'
    use 'norcalli/nvim-colorizer.lua'
    use 'folke/zen-mode.nvim'
    use({
        "iamcco/markdown-preview.nvim",
        run = function() vim.fn["mkdp#util#install"]() end,
    })
    use 'akinsho/nvim-bufferline.lua'
    -- use 'github/copilot.vim'
    use 'lewis6991/gitsigns.nvim'
    use 'dinhhuy258/git.nvim' -- For git blame & browse
    use "lukas-reineke/indent-blankline.nvim"
    use { 'TimUntersberger/neogit', requires = 'nvim-lua/plenary.nvim' }
    use { "rcarriga/nvim-dap-ui", requires = { "mfussenegger/nvim-dap" } }
    use {
        'VonHeikemen/fine-cmdline.nvim',
        requires = {
            { 'MunifTanjim/nui.nvim' }
        }
    }
    use {
        'numToStr/Comment.nvim',
        config = function()
            require('Comment').setup({
                languages = {
                    python = {
                        template = {
                            annotation_convention = "numpydoc" }
                    }
                }
            })
        end
    }
    use 'voldikss/vim-floaterm'
    use {
        "danymat/neogen",
        config = function()
            require('neogen').setup {}
        end,
        requires = "nvim-treesitter/nvim-treesitter",
        -- Uncomment next line if you want to follow only stable versions
        -- tag = "*"
    }
    use({
        "ray-x/sad.nvim",
        requires = { "ray-x/guihua.lua", run = "cd lua/fzy && make" },
        config = function()
            require("sad").setup {}
        end,

    })
end)
