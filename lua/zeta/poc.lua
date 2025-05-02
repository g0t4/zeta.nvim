local weslcs = require("zeta.diff.weslcs")
local combined = require("zeta.diff.combined")
local parser = require("zeta.helpers.response-parser")
local files = require("zeta.helpers.files")
local window = require("zeta.helpers.vimz.windows")
local gather = require("zeta.gather")


local M = {}

-- !!! right now this just shows a diff using extmarks, the basis of showing the prediction from the zeta model / predictions API server
function M.show_diff_extmarks()
    BufferDumpClear()
    BufferDumpOpen()

    -- local before, after = files.files_difftastic_ada()
    local before, after = files.request1_response2()
    BufferDumpAppend("before: " .. before)
    BufferDumpAppend("after: " .. after)

    -- local diff = combined.combined_diff(before, after)
    local diff = weslcs.lcs_diff_with_sign_types_from_text(before, after)
    BufferDumpAppend(diff)
    -- weslcs:   "same", "del", "add"
    -- combined: "=",    "-",   "+"

    -- * highlight groups
    local hl_same = "zeta-same"
    local hl_added = "zeta-added"
    local hl_deleted = "zeta-deleted"
    -- 0 == global namespace (otherwise have to activate them if not global ns on hlgroup)
    vim.api.nvim_set_hl(0, hl_same, {}) -- for now just keep it as is
    vim.api.nvim_set_hl(0, hl_added, { fg = "#00ff00", }) -- ctermfg = "green"
    vim.api.nvim_set_hl(0, hl_deleted, { fg = "#ff0000", }) -- ctermfg = "red"

    local extmark_lines = vim.iter(diff):fold({ {} }, function(accum, chunk)
        if chunk == nil then
            BufferDumpAppend("nil chunk: " .. tostring(chunk))
        else
            BufferDumpAppend("chunk", chunk)
            -- each chunk has has two strings: { "text\nfoo\nbar", "type" }
            --   type == "same", "add", "del"
            -- text must be split on new line into an array
            --  when \n is encountered, start a new line in the accum
            local current_line = accum[#accum]
            local type = chunk[1]
            local text = chunk[2]

            local type_hlgroup = hl_same
            if type == "+" then
                -- type_hlgroup = hl_added -- mine (above)
                -- FYI nvim and plugins have a bunch of options already registerd too (color/highlight wise)
                -- type_hlgroup = "Added" -- light green
                type_hlgroup = "diffAdded" -- darker green/cyan
            elseif type == "-" then
                -- type_hlgroup = hl_deleted mine (above)
                -- type_hlgroup = "Removed" -- very light red (almost brown/gray)
                type_hlgroup = "diffRemoved" -- dark red
                -- return accum
                -- actually, based on how I aggregate between sames... there should only be one delete and one add between any two sames... so, I could just show both and it would appaer like remove / add (probably often lines removed then lines added, my diff processor puts the delete first which makes sense for that to be on top)
            end
            if not text:find("\n") then
                -- no new lines, so we just tack on to end of current line
                local len_text = #text
                if len_text > 0 then
                    table.insert(current_line, { text, type_hlgroup })
                end
            else
                local splits = vim.split(text, "\n")
                for i, piece in ipairs(splits) do
                    -- FYI often v will be empty (i.e. a series of newlines)... do not exclude these empty lines!
                    BufferDumpAppend("  piece: " .. piece)
                    local len_text = #piece
                    if len_text > 0 then
                        -- don't add empty pieces, just make sure we add the lines (even if empty)
                        table.insert(current_line, { piece, type_hlgroup })
                    end
                    if i < #splits then
                        -- start a new, empty line (even if last piece was empty)
                        current_line = {}
                        accum[#accum + 1] = current_line
                        -- next piece will be first, which could be next in splits OR a subsequent chunk
                    end
                end
            end
        end
        return accum
    end)

    BufferDumpAppend("## lines")
    for k, v in ipairs(extmark_lines) do
        BufferDumpAppend(vim.inspect(v))
    end

    if #extmark_lines < 1 then
        BufferDumpAppend("no lines")
        return
    end

    -- * extmark
    local ns_id = vim.api.nvim_create_namespace('zeta_diff')
    local bufnr, _window_id = GetBufferDumpNumbers()
    local num_lines = vim.api.nvim_buf_line_count(bufnr)
    local to_row_1based = num_lines
    local ext_mark_row_0based = to_row_1based - 1
    local _mark_id = vim.api.nvim_buf_set_extmark(bufnr, ns_id, ext_mark_row_0based, 0, {
        hl_mode = "combine",
        virt_text = { { "" } }, -- add blank line
        virt_lines = extmark_lines, -- rest after first
        -- virt_text = { { "twat waffl3", hl_added } }, -- line of extmark
        -- virt_lines = virt_lines, -- lines below
        virt_text_pos = "overlay", -- "overlay", "eol", "inline"
    })

    -- * scroll down enough to see extmarks that are past the last line of the buffer (so, moving cursor won't work to see them)
    window.set_topline(num_lines + #extmark_lines)
end

function M.setup()
    vim.keymap.set("n", "<leader>z", function()
        M.show_diff_extmarks()
    end, {})
    vim.keymap.set("n", "<leader>zg", function()
        gather.learn_treesitter_node_APIs()
    end, {})
end

return M
