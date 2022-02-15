return {
  "esmuellert/codediff.nvim",
  dependencies = { "MunifTanjim/nui.nvim" },
  cmd = { "CodeDiff", "ReviewPR" },
  init = function()
    -- :GitDiff [rev | base...target] — thin alias to :CodeDiff. No args opens the
    -- working-tree explorer diff; running :CodeDiff lazy-loads this plugin on demand.
    vim.api.nvim_create_user_command("GitDiff", function(o)
      vim.cmd("CodeDiff " .. o.args)
    end, {
      nargs = "*",
      desc = "Diff via CodeDiff (no args = working tree; or <rev> / <base>...<target>)",
    })
  end,
  config = function()
    require("codediff").setup({
      -- Highlight configuration
      highlights = {
        -- Line-level: accepts highlight group names or hex colors (e.g., "#2ea043")
        line_insert = "DiffAdd",      -- Line-level insertions
        line_delete = "DiffDelete",   -- Line-level deletions

        -- Character-level: accepts highlight group names or hex colors
        -- If specified, these override char_brightness calculation
        char_insert = nil,            -- Character-level insertions (nil = auto-derive)
        char_delete = nil,            -- Character-level deletions (nil = auto-derive)

        -- Brightness multiplier (only used when char_insert/char_delete are nil)
        -- nil = auto-detect based on background (1.4 for dark, 0.92 for light)
        char_brightness = nil,        -- Auto-adjust based on your colorscheme

        -- Conflict sign highlights (for merge conflict views)
        -- Accepts highlight group names or hex colors (e.g., "#f0883e")
        -- nil = use default fallback chain
        conflict_sign = nil,          -- Unresolved: DiagnosticSignWarn -> #f0883e
        conflict_sign_resolved = nil, -- Resolved: Comment -> #6e7681
        conflict_sign_accepted = nil, -- Accepted: GitSignsAdd -> DiagnosticSignOk -> #3fb950
        conflict_sign_rejected = nil, -- Rejected: GitSignsDelete -> DiagnosticSignError -> #f85149
      },

      -- Diff view behavior
      diff = {
        disable_inlay_hints = true,         -- Disable inlay hints in diff windows for cleaner view
        max_computation_time_ms = 5000,     -- Maximum time for diff computation (VSCode default)
        hide_merge_artifacts = false,       -- Hide merge tool temp files (*.orig, *.BACKUP.*, *.BASE.*, *.LOCAL.*, *.REMOTE.*)
        original_position = "left",         -- Position of original (old) content: "left" or "right"
        conflict_ours_position = "right",   -- Position of ours (:2) in conflict view: "left" or "right"
      },

      -- Explorer panel configuration
      explorer = {
        position = "left",  -- "left" or "bottom"
        width = 40,         -- Width when position is "left" (columns)
        height = 15,        -- Height when position is "bottom" (lines)
        indent_markers = true,  -- Show indent markers in tree view (│, ├, └)
        icons = {
          folder_closed = "",  -- Nerd Font folder icon (customize as needed)
          folder_open = "",    -- Nerd Font folder-open icon
        },
        view_mode = "list",    -- "list" or "tree"
        file_filter = {
          ignore = {},  -- Glob patterns to hide (e.g., {"*.lock", "dist/*"})
        },
      },

      -- Keymaps in diff view
      keymaps = {
        view = {
          quit = "q",                    -- Close diff tab
          toggle_explorer = "<leader>b",  -- Toggle explorer visibility (explorer mode only)
          next_hunk = "]c",   -- Jump to next change
          prev_hunk = "[c",   -- Jump to previous change
          next_file = "]f",   -- Next file in explorer mode
          prev_file = "[f",   -- Previous file in explorer mode
          diff_get = "do",    -- Get change from other buffer (like vimdiff)
          diff_put = "dp",    -- Put change to other buffer (like vimdiff)
        },
        explorer = {
          select = "<CR>",    -- Open diff for selected file
          hover = "K",        -- Show file diff preview
          refresh = "R",      -- Refresh git status
          toggle_view_mode = "i",  -- Toggle between 'list' and 'tree' views
          toggle_stage = "-", -- Stage/unstage selected file
          stage_all = "S",    -- Stage all files
          unstage_all = "U",  -- Unstage all files
          restore = "X",      -- Discard changes (restore file)
        },
        conflict = {
          accept_incoming = "<leader>ct",  -- Accept incoming (theirs/left) change
          accept_current = "<leader>co",   -- Accept current (ours/right) change
          accept_both = "<leader>cb",      -- Accept both changes (incoming first)
          discard = "<leader>cx",          -- Discard both, keep base
          next_conflict = "]x",            -- Jump to next conflict
          prev_conflict = "[x",            -- Jump to previous conflict
          diffget_incoming = "2do",        -- Get hunk from incoming (left/theirs) buffer
          diffget_current = "3do",         -- Get hunk from current (right/ours) buffer
        },
      },
    })

    -- :ReviewPR [number] — full-window GitHub PR review.
    -- snacks gh shows PR diffs only in a floating popup (no file tree). This
    -- checks out the PR (current branch's PR if no number) and opens it in
    -- codediff's real tab layout: file-tree explorer + side-by-side panes,
    -- scoped to the PR's changes via merge-base (`<base>...HEAD`, = GitHub's
    -- "Files changed"). Use snacks (<leader>gp → actions) for comment/approve.
    vim.api.nvim_create_user_command("ReviewPR", function(opts)
      local arg = vim.trim(opts.args)
      local view = { "gh", "pr", "view", "--json", "number,baseRefName" }
      if arg ~= "" then table.insert(view, 4, arg) end -- gh pr view <n> --json …
      vim.system(view, { text = true }, function(res)
        vim.schedule(function()
          if res.code ~= 0 then
            vim.notify("ReviewPR: " .. (res.stderr ~= "" and res.stderr
              or "gh pr view failed (in a GitHub repo? gh authed?)"),
              vim.log.levels.ERROR)
            return
          end
          local ok, info = pcall(vim.json.decode, res.stdout)
          if not ok or not info.number then
            vim.notify("ReviewPR: could not parse PR info", vim.log.levels.ERROR)
            return
          end
          local base = info.baseRefName or "main"
          vim.notify(("ReviewPR: checking out PR #%d (base %s)…")
            :format(info.number, base))
          vim.system({ "gh", "pr", "checkout", tostring(info.number) },
            { text = true }, function(co)
              vim.schedule(function()
                if co.code ~= 0 then
                  vim.notify("ReviewPR: checkout failed (commit/stash first?): "
                    .. (co.stderr or ""), vim.log.levels.ERROR)
                  return
                end
                -- ensure the base ref exists locally for merge-base; proceed
                -- regardless (CodeDiff will error clearly if it's truly absent)
                vim.system({ "git", "fetch", "origin", base }, {}, function()
                  vim.schedule(function()
                    vim.cmd("CodeDiff " .. base .. "...HEAD")
                  end)
                end)
              end)
            end)
        end)
      end)
    end, {
      nargs = "?",
      desc = "Checkout a GitHub PR (current branch's if omitted) and review it full-window in codediff",
    })
  end,
}
