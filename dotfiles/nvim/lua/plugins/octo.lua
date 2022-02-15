-- octo.nvim — full in-editor GitHub PR/issue review.
-- This is the tool that does file-tree navigation AND inline commenting in one
-- place (snacks gh = comments but popup-only; codediff = tree but no comments).
-- Pickers routed through snacks to match the rest of the config.
return {
    "pwntester/octo.nvim",
    cmd = "Octo",
    dependencies = {
        "nvim-lua/plenary.nvim",
        "folke/snacks.nvim",
        "nvim-tree/nvim-web-devicons",
    },
    opts = {
        picker = "snacks",
    },
    keys = {
        -- Entry points (snacks gh keeps <leader>gd/gi/gI/gp/gP; these are free).
        { "<leader>gr", "<cmd>Octo pr list<cr>",      desc = "Octo: PR list (review)" },
        { "<leader>gR", "<cmd>Octo review start<cr>", desc = "Octo: start review of current branch's PR" },
    },
    -- Review flow once a review tab is open (localleader = `\` in this config):
    --   \ca  add a review comment (normal, or visual for multi-line)   ← the thing you wanted
    --   \sa  add a review suggestion
    --   \e   focus the changed-files panel   \b  toggle the panel
    --   ]q / [q  next / prev changed file    ]u / [u  next / prev *unviewed* file
    --   ]t / [t  next / prev comment thread  \<space>  toggle file "viewed"
    --   \vs  submit review (Approve / Request changes / Comment)   \vd  discard review
    --   \qa  approve PR (from the PR buffer)
}
