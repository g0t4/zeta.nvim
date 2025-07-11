local weslcs = require('devtools.diff.weslcs')
local combined = require('devtools.diff.combined')
local files = require('zeta.helpers.files')
local messages = require('devtools.messages')
local window = require('zeta.helpers.vimz.windows')

local M = {}

function M.show_diff_extmarks()
    -- this was an early prototype to test showing a diff with extmarks
    -- FYI this can be removed

    messages.ensure_open()
    -- dump.clear()

    -- local before, after = files.files_difftastic_ada()
    local before, after = files.request1_response2()

    -- * PICK WHICH DIFF (combined (histogram line level => weslcs word level) or just lcs (weslcs))
    -- local diff = combined.combined_diff(before, after)
    local diff = weslcs.lcs_diff_with_sign_types_from_text(before, after)
    messages.append(diff)
    -- weslcs:   "same", "del", "add"
    -- combined: "=",    "-",   "+"
    local bufnr, _window_id = messages.get_ids()
    M.extmarks_for(diff, bufnr, _window_id)
end

function M.setup()
    vim.keymap.set('n', '<leader>z', function()
        M.show_diff_extmarks()
    end, {})
end

-- * highlight groups
local hl_same = 'zeta-same'
local hl_added = 'zeta-added'
local hl_deleted = 'zeta-deleted'
-- 0 == global namespace (otherwise have to activate them if not global ns on hlgroup)
vim.api.nvim_set_hl(0, hl_same, {}) -- for now just keep it as is
-- vim.api.nvim_set_hl(0, hl_added, { fg = "#a6e3a1", }) -- ctermfg = "green"
-- vim.api.nvim_set_hl(0, hl_added, { fg = "#b5f4cb", }) -- ctermfg = "green"
vim.api.nvim_set_hl(0, hl_added, { fg = '#81c8be', }) -- ctermfg = "green"
-- vim.api.nvim_set_hl(0, hl_deleted, { fg = "#f28b82", }) -- ctermfg = "red"
vim.api.nvim_set_hl(0, hl_deleted, { fg = '#ff6b6b', }) -- ctermfg = "red"
-- vim.api.nvim_set_hl(0, hl_deleted, { fg = "#e06c75", }) -- ctermfg = "red"

local extmark_ns_id = vim.api.nvim_create_namespace('devtools.diff')

function M.extmarks_for(diff, bufnr, _window_id)
    local extmark_lines = vim.iter(diff):fold({ {} }, function(accum, chunk)
        if chunk == nil then
            messages.append('nil chunk: ' .. tostring(chunk))
        else
            -- each chunk has has two strings: { "text\nfoo\nbar", "type" }
            --   type == "same", "add", "del"
            -- text must be split on new line into an array
            --  when \n is encountered, start a new line in the accum
            local current_line = accum[#accum]
            local type = chunk[1]
            local text = chunk[2]

            local type_hlgroup = hl_same
            if type == '+' then
                type_hlgroup = hl_added -- mine (above)
                -- FYI nvim and plugins have a bunch of options already registerd too (color/highlight wise)
                -- type_hlgroup = "Added" -- light green
                -- type_hlgroup = "diffAdded" -- darker green/cyan - *** FAVORITE
            elseif type == '-' then
                type_hlgroup = hl_deleted -- mine (above)
                -- type_hlgroup = "Removed" -- very light red (almost brown/gray)
                -- type_hlgroup = "diffRemoved" -- dark red - *** FAVORITE
                -- return accum
                -- actually, based on how I aggregate between sames... there should only be one delete and one add between any two sames... so, I could just show both and it would appaer like remove / add (probably often lines removed then lines added, my diff processor puts the delete first which makes sense for that to be on top)
            end
            if not text:find('\n') then
                -- no new lines, so we just tack on to end of current line
                local len_text = #text
                if len_text > 0 then
                    table.insert(current_line, { text, type_hlgroup })
                end
            else
                local splits = vim.split(text, '\n')
                for i, piece in ipairs(splits) do
                    -- FYI often v will be empty (i.e. a series of newlines)... do not exclude these empty lines!
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

    -- dump.header("extmark_lines")
    -- for _, v in ipairs(extmark_lines) do
    --     dump.append(vim.inspect(v))
    -- end

    if #extmark_lines < 1 then
        messages.append('no lines')
        return
    end


    -- * extmark
    local num_lines = vim.api.nvim_buf_line_count(bufnr)
    local to_row_1indexed = num_lines
    local ext_mark_row_0indexed = to_row_1indexed - 1
    local _mark_id = vim.api.nvim_buf_set_extmark(bufnr, extmark_ns_id, ext_mark_row_0indexed, 0, {
        hl_mode = 'combine',
        virt_text = { { '' } }, -- add blank line
        virt_lines = extmark_lines, -- rest after first
        -- virt_text = { { "twat waffl3", hl_added } }, -- line of extmark
        -- virt_lines = virt_lines, -- lines below
        virt_text_pos = 'overlay', -- "overlay", "eol", "inline"
    })

    if _window_id ~= nil then
        -- if window is open, then scroll down
        -- * scroll down enough to see extmarks that are past the last line of the buffer (so, moving cursor won't work to see them)
        window.set_topline(num_lines + #extmark_lines, _window_id)
    end
end

return M
