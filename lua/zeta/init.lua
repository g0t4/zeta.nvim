local wesdiff = require("zeta.diff.wesdiff")
local parser = require("zeta.helpers.response-parser")
local M = {}

function M.show_diff_extmarks()
    BufferDumpClear()

    local zed_request =
    '{"outline":"```lua/ask-openai/prediction/tests/calc/calc.lua\nfunction M.add\n```\n","input_events":"User edited \\"lua/ask-openai/prediction/tests/calc/calc.lua\\":\n```diff\n@@ -7,4 +7,5 @@\n \n \n \n+\n return M\n\n```\n\nUser edited \\"lua/ask-openai/prediction/tests/calc/calc.lua\\":\n```diff\n@@ -8,4 +8,5 @@\n \n \n \n+\n return M\n\n```\n\nUser edited \\"lua/ask-openai/prediction/tests/calc/calc.lua\\":\n```diff\n@@ -8,5 +8,4 @@\n \n \n \n-\n return M\n\n```","input_excerpt":"```ask-openai.nvim/lua/ask-openai/prediction/tests/calc/calc.lua\n<|start_of_file|>\n<|editable_region_start|>\nlocal M = {}\n\nfunction M.add(a, b)\n    return a + b\nend\n\n<|user_cursor_is_here|>\n\n\n\nreturn M\n\n<|editable_region_end|>\n```","speculated_output":"<|editable_region_start|>\nlocal M = {}\n\nfunction M.add(a, b)\n    return a + b\nend\n\n<|user_cursor_is_here|>\n\n\n\nreturn M\n\n<|editable_region_end|>","can_collect_data":false,"diagnostic_groups":[]}'
    local zed_response =
    '{"output_excerpt":"<|editable_region_start|>\nlocal M = {}\n\nfunction M.add(a, b)\n    return a + b\nend\n\nfunction M.subtract(a, b)\n    return a - b\nend\n\nfunction M.multiply(a, b)\n    return a * b\nend\n\nfunction M.divide(a, b)\n    if b == 0 then\n        error(\\"Division by zero\\")\n    end\n    return a / b\nend\n\n\n\nreturn M\n\n<|editable_region_end|>\n```\n","request_id":"8319778f2ac147f7b1fbe1b0d5424132"}'

    local request_decoded = vim.json.decode(zed_request)
    local response_decoded = vim.json.decode(zed_response)
    local input_excerpt = request_decoded.input_excerpt
    local output_excerpt = response_decoded.output_excerpt

    local input_editable = parser.get_editable(input_excerpt)
    local output_editable = parser.get_editable(output_excerpt)
    assert(input_editable ~= nil)
    assert(output_editable ~= nil)

    input_editable = input_editable:gsub(parser.tag_cursor_here, "")

    local diff = wesdiff.get_diff_from_text(input_editable, output_editable)
    BufferDumpAppend(diff)
    -- luadiff: "same", "out",  "in"
    -- wesdiff: "same", "del", "add"

    -- * highlight groups
    local hl_same = "zeta-same"
    local hl_added = "zeta-added"
    local hl_deleted = "zeta-deleted"
    -- 0 == global namespace (otherwise have to activate them if not global ns on hlgroup)
    vim.api.nvim_set_hl(0, hl_same, {}) -- for now just keep it as is
    vim.api.nvim_set_hl(0, hl_added, { fg = "#00ff00", }) -- ctermfg = "green"
    vim.api.nvim_set_hl(0, hl_deleted, { fg = "#ff0000", }) -- ctermfg = "red"

    local lines = vim.iter(diff):fold({ {} }, function(accum, key, value)
        local chunk = value
        if chunk == nil then
            BufferDumpAppend("nil chunk: " .. tostring(key))
        elseif type(chunk) == "function" then
            -- TODO can I delete the to_html... or how can I avoid iterating it too?
            BufferDumpAppend("func chunk: " .. tostring(key))
        else
            BufferDumpAppend("chunk", chunk)
            -- each chunk has has two strings: { "text\nfoo\nbar", "type" }
            --   type == "same", "add", "del"
            -- text must be split on new line into an array
            --  when \n is encountered, start a new line in the accum
            local current_line = accum[#accum]
            local text = chunk[1]
            local type = chunk[2]
            local type_hlgroup = hl_same
            if type == "add" then
                type_hlgroup = hl_added
            elseif type == "del" then
                -- TODO dont show deleted for now
                type_hlgroup = hl_deleted
            end
            if not text:find("\n") then
                -- no new lines, so we just tack on to end of current line
                local len_text = #text
                if len_text > 0 then
                    table.insert(current_line, { text, type_hlgroup })
                end
            else
                local splits = vim.split(text, "\n")
                for _, piece in ipairs(splits) do
                    -- FYI often v will be empty (i.e. a series of newlines)... do not exclude these empty lines!
                    BufferDumpAppend("  " .. piece)
                    local len_text = #piece
                    if len_text > 0 then
                        -- don't add empty pieces, just make sure we add the lines (even if empty)
                        table.insert(current_line, { piece, type_hlgroup })
                    end
                    -- start a new, empty line (even if last piece was empty)
                    current_line = {}
                    accum[#accum + 1] = current_line
                    -- next piece will be first, which could be next in splits OR a subsequent chunk
                end
            end
        end
        return accum
    end)

    BufferDumpAppend("## lines")
    vim.print(lines)
    for k, v in ipairs(lines) do
        BufferDumpAppend(vim.inspect(v))
    end

    do return end

    if #lines < 1 then
        BufferDumpAppend("no lines")
        return
    end

    -- FYI this removes first line from lines
    local first_line = table.remove(lines, 1)
    -- thus lines == rest of lines

    -- * extmark
    local ns_id = vim.api.nvim_create_namespace('zeta_diff')
    local bufnr, window_id = GetBufferDumpNumbers()
    local num_lines = vim.api.nvim_buf_line_count(bufnr)
    local to_row_1based = num_lines
    local to_col_0based = 0
    vim.api.nvim_win_set_cursor(window_id, { to_row_1based, to_col_0based })
    local ext_mark_row_0based = to_row_1based - 1 - 20
    local mark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, ext_mark_row_0based, 0, {
        hl_mode = "combine",
        virt_text = first_line,
        virt_lines = lines, -- rest after first
        -- virt_text = { { "twat waffl3", hl_added } }, -- line of extmark
        -- virt_lines = virt_lines, -- lines below
        virt_text_pos = "overlay", -- "overlay", "eol", "inline"
    })
end

function M.setup()
    vim.keymap.set("n", "<leader>z", function()
        M.show_diff_extmarks()
    end, {})
    vim.keymap.set("n", "<leader>zl", function()
        require("zeta.learn.find-diff-tool").test_zeta()
    end, {})
end

return M
