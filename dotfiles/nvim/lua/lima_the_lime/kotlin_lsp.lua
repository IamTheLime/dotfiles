-- =====================================================================
-- Kotlin LSP support
-- =====================================================================
-- Upstream quirks in kotlin-lsp (JetBrains, pre-alpha as of 2026-04):
--
--   1. Completion textEdits place the cursor at the wrong offset.
--      Workaround lives in blink-cmp.lua (transform_items strips
--      textEdits and forces plain-label insertion).
--
--   2. Library symbols are returned as `jar:` / `jrt:` URIs, which
--      Neovim can't natively open, and which bypass auto-attach
--      because we give the resulting scratch buffers buftype=nofile.
--
--   3. `textDocument/definition` (and typeDefinition/hover/…) return
--      `{}` when the request originates from a jar:/jrt: URI — the
--      server doesn't resolve symbols in library buffers.
--      See https://github.com/Kotlin/kotlin-lsp/issues/44.
--
-- Mitigations in this file:
--   * `open_kotlin_library_uri` fetches jar/jrt content via
--     `workspace/executeCommand { command = "decompile" }` and loads
--     it into a named scratch buffer (one per URI).
--   * `attach_virtual_lsp` fakes an LSP attachment by sending
--     `didOpen` for the jar URI and setting buffer-local keymaps
--     that route requests through `client:request()` with the
--     stashed `b:kotlin_virtual_uri`.
--   * `jar_symbol_fallback` grep-scans gradle-cache -sources.jar
--     archives when a definition/typeDefinition request inside a
--     library buffer comes back empty (quirk #3).
--   * A quickfix `<CR>` override and a `BufReadCmd` (near the end of
--     this file) are the other two entry points into
--     `open_kotlin_library_uri`.
--
-- Set `vim.g.kotlin_lsp_barebones = true` to skip the workaround
-- patches and test the upstream LSP behavior directly. The kotlin_lsp
-- server itself is still registered.
-- =====================================================================

local M = {}

-- Forward declarations — these helpers reference each other cyclically.
local get_kotlin_client, build_params, find_declaration_line
local handle_location_result, goto_location
local open_kotlin_library_uri, attach_virtual_lsp
local setup_kotlin_nav_keymaps, jar_symbol_fallback

-- ─── Helpers ─────────────────────────────────────────────────────────

--- Returns the kotlin_lsp client if one is attached, else nil.
get_kotlin_client = function()
    return vim.lsp.get_clients({ name = "kotlin_lsp" })[1]
end

--- Build textDocument/position params for `buf`. On library buffers
--- the normal LSP machinery has no attached client to derive the URI
--- from, so we use the stashed `b:kotlin_virtual_uri` instead.
build_params = function(buf)
    local virtual = vim.b[buf].kotlin_virtual_uri
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    if virtual then
        return {
            textDocument = { uri = virtual },
            position = { line = row - 1, character = col },
        }
    end
    local client = vim.lsp.get_clients({ bufnr = buf })[1]
    return vim.lsp.util.make_position_params(0, client and client.offset_encoding)
end

--- Scan `lines` for the first Kotlin/Java declaration of `symbol`.
--- Used to re-position the cursor after landing in a decompiled
--- file via the jar-grep fallback (where we only know the filename,
--- not the symbol's line).
--- Returns (row, col) with row 1-indexed and col 0-indexed — the
--- shape nvim_win_set_cursor expects — or nil if nothing matched.
find_declaration_line = function(lines, symbol)
    if not symbol or symbol == "" then return nil end
    local esc = vim.pesc(symbol)
    local patterns = {
        "class%s+" .. esc .. "[%s<(:{]",
        "interface%s+" .. esc .. "[%s<:{]",
        "object%s+" .. esc .. "[%s:{]",
        "enum%s+" .. esc .. "[%s({]",
        "fun%s+" .. esc .. "[%s<(]",
        "val%s+" .. esc .. "[%s:=]",
        "var%s+" .. esc .. "[%s:=]",
    }
    for i, line in ipairs(lines) do
        for _, pat in ipairs(patterns) do
            if line:find(pat) then
                local sym_col = line:find(esc, 1, false)
                return i, (sym_col or 1) - 1
            end
        end
    end
    return nil
end

-- ─── Virtual library-buffer lifecycle ────────────────────────────────

--- Open a jar:/jrt: URI as a scratch buffer and position the cursor.
--- If `symbol_hint` is provided, we scan the loaded content for a
--- declaration of that name and override (row, col) with the match —
--- this is what lets the jar-grep fallback land on the right line
--- instead of the top of the file. Existing buffers are reused.
open_kotlin_library_uri = function(uri, row, col, symbol_hint)
    row = row or 1
    col = col or 0
    if not (uri:match("^jar:") or uri:match("^jrt:")) then return end
    local client = get_kotlin_client()
    if not client then return end
    local existing = vim.fn.bufnr(uri)

    -- Fast path: buffer already exists, just focus + re-position.
    if existing ~= -1 and vim.b[existing].kotlin_virtual_uri then
        vim.api.nvim_set_current_buf(existing)
        if symbol_hint then
            local lines = vim.api.nvim_buf_get_lines(existing, 0, -1, false)
            local hr, hc = find_declaration_line(lines, symbol_hint)
            if hr then row, col = hr, hc end
        end
        pcall(vim.api.nvim_win_set_cursor, 0, { row, col })
        return
    end

    -- Cold path: ask the server to decompile / read the source.
    client:request("workspace/executeCommand", {
        command = "decompile",
        arguments = { uri },
    }, function(err, res)
        vim.schedule(function()
            if err or not (res and res.code) then
                vim.notify(
                    "kotlin_lsp: failed to decompile " .. uri ..
                    (err and (" (" .. vim.inspect(err) .. ")") or ""),
                    vim.log.levels.WARN)
                return
            end
            local buf = existing ~= -1 and existing
                or vim.api.nvim_create_buf(true, false)
            vim.bo[buf].buftype = "nofile"
            vim.bo[buf].swapfile = false
            vim.bo[buf].modifiable = true
            if vim.api.nvim_buf_get_name(buf) ~= uri then
                vim.api.nvim_buf_set_name(buf, uri)
            end
            local lines = vim.split(res.code, "\n")
            vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
            vim.bo[buf].filetype = res.language or "kotlin"
            vim.bo[buf].modifiable = false
            vim.api.nvim_set_current_buf(buf)
            if symbol_hint then
                local hr, hc = find_declaration_line(lines, symbol_hint)
                if hr then row, col = hr, hc end
            end
            pcall(vim.api.nvim_win_set_cursor, 0,
                { math.min(row, #lines), col })
            attach_virtual_lsp(buf, uri, res.code)
        end)
    end)
end

--- Register a scratch library buffer with kotlin_lsp via didOpen,
--- stash the URI on the buffer, and install our nav keymaps. The
--- server needs didOpen to answer subsequent requests about this
--- URI; we pair it with a didClose on BufDelete / BufWipeout.
attach_virtual_lsp = function(bufnr, uri, contents)
    if vim.b[bufnr].kotlin_virtual_uri == uri then return end
    local client = get_kotlin_client()
    if not client then return end
    vim.b[bufnr].kotlin_virtual_uri = uri
    client:notify("textDocument/didOpen", {
        textDocument = {
            uri = uri,
            languageId = "kotlin",
            version = 0,
            text = contents,
        },
    })
    vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
        buffer = bufnr,
        once = true,
        callback = function()
            local c = get_kotlin_client()
            if c then
                c:notify("textDocument/didClose", {
                    textDocument = { uri = uri },
                })
            end
        end,
    })
    setup_kotlin_nav_keymaps(bufnr)
end

-- ─── Navigation (gd / go) ────────────────────────────────────────────

--- Handle a Location / LocationLink response. File URIs go through
--- vim.lsp.util.show_document; jar:/jrt: URIs route into
--- open_kotlin_library_uri instead. Empty responses and errors are
--- surfaced to the user, prefixed with the responding server's name.
handle_location_result = function(err, result, ctx)
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    local tag = (client and client.name or "lsp") .. ": " .. ctx.method
    if err then
        vim.notify(tag .. " error: " .. vim.inspect(err), vim.log.levels.WARN)
        return
    end
    if not result or (vim.islist(result) and #result == 0) then
        vim.notify(tag .. " returned no result", vim.log.levels.INFO)
        return
    end
    local locs = vim.islist(result) and result or { result }
    local loc = locs[1]
    local uri = loc.targetUri or loc.uri or ""
    local range = loc.targetSelectionRange or loc.targetRange or loc.range or {}
    local row = (range.start and range.start.line or 0) + 1
    local col = range.start and range.start.character or 0

    if uri:match("^jar:") or uri:match("^jrt:") then
        open_kotlin_library_uri(uri, row, col)
    elseif uri == "" then
        vim.notify(tag .. " response has no URI: " .. vim.inspect(loc),
            vim.log.levels.WARN)
    else
        local client = vim.lsp.get_client_by_id(ctx.client_id)
        if client then
            vim.lsp.util.show_document(loc, client.offset_encoding,
                { reuse_win = true, focus = true })
        end
    end
end

--- Send a definition / typeDefinition request for `buf`, handling
--- both project and library buffers. Only JVM buffers (kotlin/java)
--- and kotlin virtual library buffers use this custom path — every
--- other filetype defers to `vim.lsp.buf.*`, which dispatches to
--- clients that actually advertise the method. This avoids sending
--- definition requests to servers like eslint-lsp that respond with
--- JSON-RPC -32601 ("Unhandled method") and then surface via
--- handle_location_result as confusing errors.
goto_location = function(method, buf)
    local is_virtual = vim.b[buf].kotlin_virtual_uri ~= nil
    local ft = vim.bo[buf].filetype
    local is_jvm = ft == "kotlin" or ft == "java"

    if not (is_virtual or is_jvm) then
        if method == "textDocument/typeDefinition" then
            vim.lsp.buf.type_definition({ reuse_win = true })
        else
            vim.lsp.buf.definition({ reuse_win = true })
        end
        return
    end

    local client = is_virtual and get_kotlin_client()
        or vim.lsp.get_clients({ bufnr = buf, method = method })[1]
    if not client then return end

    local cword = vim.fn.expand("<cword>")
    local virtual_uri = vim.b[buf].kotlin_virtual_uri
    client:request(method, build_params(buf), function(err, result, ctx)
        local empty = not err and
            (not result or (vim.islist(result) and #result == 0))
        if empty and is_virtual and
            (method == "textDocument/definition"
             or method == "textDocument/typeDefinition") then
            jar_symbol_fallback(cword, virtual_uri)
            return
        end
        handle_location_result(err, result, ctx)
    end, buf)
end

-- ─── Gradle-cache jar-grep fallback ──────────────────────────────────
-- Invoked when gd/go inside a library buffer returns nothing (see
-- upstream quirk #3). Heuristic: assume the symbol under cursor
-- corresponds to a Kotlin/Java file named `<symbol>.kt` or `.java`
-- inside some -sources.jar. Scan the *current* jar first (synchronous,
-- sub-100ms — hits same-module jumps), then the full gradle cache
-- asynchronously via parallel xargs. Single result jumps directly;
-- multiple results populate the quickfix list. Limitations: misses
-- symbols that live in a file with a different name (e.g. multiple
-- top-level types per file), and Maven / non-gradle layouts.

jar_symbol_fallback = function(symbol, virtual_uri)
    if not symbol or symbol == "" then return end
    local esc = vim.pesc(symbol)

    --- True iff a zip entry matches `<symbol>.kt` or `<symbol>.java`,
    --- anywhere in the archive tree or at the root.
    local function entry_matches(entry)
        return entry:match("/" .. esc .. "%.kt$")
            or entry:match("/" .. esc .. "%.java$")
            or entry:match("^" .. esc .. "%.kt$")
            or entry:match("^" .. esc .. "%.java$")
    end

    --- Return `{{jar, entry}, …}` for matches in a single jar.
    local function scan_jar(jar_path)
        local entries = vim.fn.systemlist({ "unzip", "-Z1", jar_path })
        if vim.v.shell_error ~= 0 then return {} end
        local matches = {}
        for _, entry in ipairs(entries) do
            if entry_matches(entry) then
                table.insert(matches, { jar = jar_path, entry = entry })
            end
        end
        return matches
    end

    --- Jump to the single result, or dump everything to quickfix.
    local function present(results)
        if #results == 0 then
            vim.notify("kotlin: no match for '" .. symbol ..
                "' in gradle cache sources jars", vim.log.levels.WARN)
            return
        end
        if #results == 1 then
            local r = results[1]
            open_kotlin_library_uri("jar://" .. r.jar .. "!/" .. r.entry,
                1, 0, symbol)
            return
        end
        local items = {}
        for _, r in ipairs(results) do
            table.insert(items, {
                filename = "jar://" .. r.jar .. "!/" .. r.entry,
                lnum = 1,
                col = 1,
                text = r.entry,
            })
        end
        vim.fn.setqflist(items, "r")
        vim.cmd("copen")
    end

    -- Pass 1 — current jar only. Fast and catches most intra-module jumps.
    local current_jar = virtual_uri and virtual_uri:match("^jar:///([^!]+)!/")
    if current_jar then current_jar = "/" .. current_jar end
    if current_jar then
        local hits = scan_jar(current_jar)
        if #hits > 0 then
            present(hits)
            return
        end
    end

    -- Pass 2 — full gradle cache, async, parallel.
    local gradle_cache = vim.fn.expand("~/.gradle/caches/modules-2/files-2.1")
    if vim.fn.isdirectory(gradle_cache) ~= 1 then
        vim.notify("kotlin: no gradle cache at " .. gradle_cache,
            vim.log.levels.WARN)
        return
    end
    vim.notify("kotlin: scanning gradle cache for '" .. symbol .. "'...",
        vim.log.levels.INFO)
    local shell_cmd = string.format(
        [[find %s -name '*-sources.jar' -print0 2>/dev/null | ]] ..
        [[xargs -0 -P 8 -I {} sh -c "unzip -Z1 '{}' 2>/dev/null | ]] ..
        [[grep -E '(^|/)%s\.(kt|java)$' | sed 's|^|{}!/|'"]],
        vim.fn.shellescape(gradle_cache),
        symbol:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "\\%1"))
    vim.system({ "sh", "-c", shell_cmd }, { text = true }, function(obj)
        vim.schedule(function()
            local results = {}
            if obj.stdout then
                for line in (obj.stdout):gmatch("[^\n]+") do
                    local jar, entry = line:match("^(.+%-sources%.jar)!/(.+)$")
                    if jar and entry and jar ~= current_jar then
                        table.insert(results, { jar = jar, entry = entry })
                    end
                end
            end
            present(results)
        end)
    end)
end

-- ─── Buffer-local keymaps for library buffers ────────────────────────
-- Installed by attach_virtual_lsp. Mirrors the project-buffer keymaps
-- in the LspAttach handler below, but routes every request through
-- `client:request()` with the stashed virtual URI instead of relying
-- on nvim's auto-attach (which we opted out of with buftype=nofile).
-- Fallbacks only apply to gd/go; K/gs/gr have no useful recovery
-- path when the server returns empty.

setup_kotlin_nav_keymaps = function(bufnr)
    local opts = { buffer = bufnr }

    vim.keymap.set('n', 'gd', function()
        goto_location('textDocument/definition', bufnr)
    end, opts)

    vim.keymap.set('n', 'go', function()
        goto_location('textDocument/typeDefinition', bufnr)
    end, opts)

    vim.keymap.set('n', 'K', function()
        local client = get_kotlin_client()
        if not client then return end
        client:request('textDocument/hover', build_params(bufnr),
            function(err, result, ctx)
                vim.lsp.handlers.hover(err, result, ctx,
                    { border = "single", title = " Hover ", title_pos = "center" })
            end, bufnr)
    end, opts)

    vim.keymap.set('n', 'gs', function()
        local client = get_kotlin_client()
        if not client then return end
        client:request('textDocument/signatureHelp', build_params(bufnr),
            function(err, result, ctx)
                vim.lsp.handlers.signature_help(err, result, ctx,
                    { border = "single", title = " Signature Help ", title_pos = "center" })
            end, bufnr)
    end, opts)

    vim.keymap.set('n', 'gr', function()
        local client = get_kotlin_client()
        if not client then return end
        local params = build_params(bufnr)
        params.context = { includeDeclaration = true }
        client:request('textDocument/references', params, function(_, result)
            if not result or #result == 0 then
                vim.notify("No references found", vim.log.levels.INFO)
                return
            end
            vim.fn.setqflist(
                vim.lsp.util.locations_to_items(result, client.offset_encoding), "r")
            vim.cmd("copen")
        end, bufnr)
    end, opts)
end

-- ─── Public API ──────────────────────────────────────────────────────

--- Custom goto for the LspAttach `gd` / `go` keymaps. In barebones
--- mode, defers entirely to `vim.lsp.buf.*`.
function M.goto_location(method, buf)
    if vim.g.kotlin_lsp_barebones then
        if method == "textDocument/typeDefinition" then
            vim.lsp.buf.type_definition({ reuse_win = true })
        else
            vim.lsp.buf.definition({ reuse_win = true })
        end
        return
    end
    goto_location(method, buf)
end

--- Whether the blink-cmp textEdit-stripping workaround should apply.
--- Read by lua/plugins/blink-cmp.lua.
function M.workarounds_enabled()
    return not vim.g.kotlin_lsp_barebones
end

--- Register the kotlin_lsp server config (and, unless barebones is
--- set, the jar/jrt URI autocmds).
function M.setup()
    vim.fn.mkdir(vim.fn.stdpath("data") .. "/kotlin_lsp/" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t"), "p")

    -- kotlin_lsp storage is namespaced per project directory so indexes
    -- don't collide between repos.
    local kotlin_lsp_storage = vim.fn.stdpath("data") .. "/kotlin_lsp/" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t")

    vim.lsp.config("kotlin_lsp", {
        cmd = {
            "env",
            "JAVA_TOOL_OPTIONS=-Xmx4g -XX:+UseG1GC -XX:SoftRefLRUPolicyMSPerMB=50 -XX:+UseStringDeduplication",
            "kotlin-lsp", "--stdio",
            "--system-path", kotlin_lsp_storage,
        },
        filetypes = { "kotlin" },
        init_options = {
            storageUri = "file://" .. kotlin_lsp_storage,
        },
        root_markers = {
            "settings.gradle.kts",
            "settings.gradle",
            "build.gradle.kts",
            "build.gradle",
            "pom.xml",
        },
    })

    if vim.g.kotlin_lsp_barebones then return end

    -- =====================================================================
    -- Kotlin library-URI entrypoints (quickfix + BufReadCmd)
    -- =====================================================================

    -- Quickfix <CR> override: when a qf entry's filename is a jar:/jrt:
    -- URI (reaches us via `gr` references, :Telescope, etc.), route it
    -- through open_kotlin_library_uri instead of letting nvim try to
    -- open the literal URI — nvim's path parsing chokes on the `!/…`
    -- separator in jar URIs.
    vim.api.nvim_create_autocmd("FileType", {
        pattern = "qf",
        callback = function()
            vim.keymap.set("n", "<CR>", function()
                local items = vim.fn.getqflist()
                local item = items[vim.fn.line(".")]
                if not item then
                    vim.cmd("normal! \r")
                    return
                end
                local fname = item.filename
                    or (item.bufnr ~= 0 and vim.fn.bufname(item.bufnr) or "")
                local row = item.lnum and item.lnum > 0 and item.lnum or 1
                local col = math.max(0, (item.col or 1) - 1)
                if fname:match("^jar:") or fname:match("^jrt:") then
                    vim.cmd("cclose")
                    open_kotlin_library_uri(fname, row, col)
                    return
                end
                vim.cmd("normal! \r")
            end, { buffer = true })
        end,
    })

    -- BufReadCmd fallback: catches any attempt to `:edit` a jar:/jrt:
    -- URI (e.g. when Telescope or another plugin opens a reference
    -- location directly rather than going through our keymaps) and
    -- populates the scratch buffer synchronously via `decompile`.
    vim.api.nvim_create_autocmd("BufReadCmd", {
        pattern = { "jar:*", "jrt:*" },
        callback = function(ev)
            local buf = ev.buf
            local uri = ev.match
            vim.bo[buf].buftype = "nofile"
            vim.bo[buf].swapfile = false
            vim.bo[buf].modifiable = true

            local clients = vim.lsp.get_clients({ name = "kotlin_lsp" })
            if #clients == 0 then
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "-- kotlin_lsp client not available" })
                vim.bo[buf].modifiable = false
                return
            end
            local resp = clients[1]:request_sync("workspace/executeCommand", {
                command = "decompile",
                arguments = { uri },
            }, 5000)
            local contents, language
            if resp and resp.result and resp.result.code then
                contents = resp.result.code
                language = resp.result.language
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(contents, "\n"))
            else
                local err = resp and resp.error and vim.inspect(resp.error) or "timeout or no response"
                vim.notify("kotlin_lsp: failed to load " .. uri .. " (" .. err .. ")", vim.log.levels.WARN)
                vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "-- Error loading JAR: " .. err })
            end
            vim.bo[buf].filetype = language or "kotlin"
            vim.bo[buf].modifiable = false
            if contents then
                attach_virtual_lsp(buf, uri, contents)
            end
        end,
    })
end

return M
