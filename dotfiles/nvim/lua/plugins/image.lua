-- Inline image rendering (png/jpg/gif/webp/svg) via the kitty graphics
-- protocol, which ghostty speaks. Pairs with render-markdown.nvim: that one
-- styles the text, this one draws the picture behind `![alt](path.png)`.
--
-- Requires ImageMagick on PATH (`brew install imagemagick`) -- it is what
-- rasterises SVGs and does the scaling. The `magick_cli` processor shells out
-- to it, so there is no luarocks/magick-rock build step to keep working.
return {
    "3rd/image.nvim",
    -- The repo's build step is only for the luarock backend.
    build = false,
    ft = { "markdown", "vimwiki", "quarto" },
    ---@module 'image'
    ---@type Options
    opts = {
        backend = "kitty",
        processor = "magick_cli",
        integrations = {
            markdown = {
                enabled = true,
                clear_in_insert_mode = true,
                -- Only local files; flip on if you want http(s) images fetched.
                download_remote_images = false,
                only_render_image_at_cursor = false,
                filetypes = { "markdown", "vimwiki", "quarto" },
            },
            neorg = { enabled = false },
            typst = { enabled = false },
            html = { enabled = false },
            css = { enabled = false },
        },
        -- Keep an image from eating the whole window.
        max_height_window_percentage = 50,
        window_overlap_clear_enabled = true,
        window_overlap_clear_ft_ignore = {
            "cmp_menu", "cmp_docs", "snacks_notif", "scrollview", "scrollview_sign",
        },
        editor_only_render_when_focused = true,
        tmux_show_only_in_active_window = true,
        -- Opening an image file directly renders it instead of showing bytes.
        hijack_file_patterns = { "*.png", "*.jpg", "*.jpeg", "*.gif", "*.webp", "*.avif", "*.svg" },
    },
    keys = {
        {
            "<Leader>mi",
            function()
                local image = require("image")
                if image.is_enabled() then image.disable() else image.enable() end
            end,
            desc = "Toggle inline image rendering",
        },
    },
}
