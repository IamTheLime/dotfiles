return {
    'numToStr/Comment.nvim',
    lazy = false,
    opts = {
        languages = {
            python = {
                template = {
                    annotation_convention = 'numpydoc'
                }
            }
        }
    },
    config = function()
        local ft = require("Comment.ft")
        ft.set("htmlangular", ft.get("html"))
        require("Comment").setup()
    end
}
