return {
    'numToStr/Comment.nvim',
    config = function()
        require('Comment').setup({
            languages = {
                python = {
                    template = {
                        annotation_convention = 'numpydoc' }
                }
            }
        })
    end
}
