local histogram = require('devtools.diff.histogram')
local weslcs = require('devtools.diff.weslcs')
require('devtools.inspect')

local M = {}

---@param histogram_line_diff {type: string, line: string}[]
---@return {type: string, chunks: string}[]
function M.step2_lcs_diffs(histogram_line_diff)
    -- FYI, "=" lines are Anchors (they're already matched up)
    -- - "-" and "+" are line level changes, but they might have word level overlap
    -- - so, for every set of "-"/"+" between "=" anchors... run LCS diff on them
    --
    -- For each histogram diff line:
    -- 1. if its "=", leave it as is
    --     NOTE: this is for histogram "=" lines, I am not referring to LCS's "same" lines here
    -- 2. otherwise collect "-"/"+" until next "="
    -- 3. when group is collected/done (before new group started), run LCS diff on it
    --    - add result to groups
    local current_group = {}
    local groups = {}

    function process_group()
        -- * empty groups
        if current_group['='] == nil
            and current_group['-'] == nil
            and current_group['+'] == nil then
            -- if current_group is truly empty (no historgram lines) then don't add it as empty group!
            -- can happen at start and end of loop, this is a nice spot to handle it
            return
        end

        -- * group of consecutive "=" anchor lines
        if current_group['='] then
            -- loop logic stripped the leading '=', and I want that back on individual records
            -- that way these match the structure of LCS diff output
            -- so, add back "=" as line[1] and line[2] is once again the text
            -- result:
            --   { { "=", "line1" }, { "=", "line2" } }
            local consecutive_anchor_lines = vim.iter(current_group['='])
                :map(function(line) return { '=', line } end):totable()
            table.insert(groups, consecutive_anchor_lines)
            -- NO LCS diffing, these are already the same (anchors)
            return
        end

        -- * run LCS diff on lines between anchor lines
        local dels = current_group['-'] or {}
        local adds = current_group['+'] or {}

        -- * histogram "-" (aka deletes) are lines identified as only in the old text
        -- - my LCS algorithm takes a single string, not list of lines
        -- - so, I join histogram "-"s into a single string called "before_text"
        local before_text_string = vim.iter(dels)
            :map(function(line)
                -- super important to add back the _IMPLICIT NEWLINE_ \n suffix on histogram lines
                -- AND, need trailing \n for every line, not just between lines
                return line .. '\n'
            end)
            :join('')
        -- * histogram "+" (aka adds) are lines identified as only in the new text
        local after_text_string = vim.iter(adds)
            :map(function(line)
                return line .. '\n'
            end)
            :join('')
        local lcs_diff = weslcs.lcs_diff_from_text(before_text_string, after_text_string)
        table.insert(groups, lcs_diff)
        -- FYI get_diff (lcs) aggregates consecutive tokens of the same type
        --  so, the result here is ready to be turned into extmarks (for the LCS diff'd lines)
    end

    -- * for each histogram diff line
    for _, current_histogram_line in ipairs(histogram_line_diff) do
        local line_type = current_histogram_line[1]
        local line_text = current_histogram_line[2]

        -- edge triggered on change to/from "=" (histogram's equiv of LCS's "same")
        -- edge triggered on change to/from ANCHOR lines
        local change_to_anchor = current_group['='] and line_type ~= '='
        local change_from_anchor = (not current_group['=']) and line_type == '='
        if change_to_anchor or change_from_anchor then
            process_group()
            current_group = {}
        end

        current_group[line_type] = current_group[line_type] or {}
        table.insert(current_group[line_type], line_text)
        -- last_group looks like one of:
        -- { ["+"] = { "line1", "line2" } ["-"] = { "line3", "line4" } }, -- dels and/or adds
        -- { ["="] = { "line5", "line6" } }, -- sames only (not combined w/ dels/adds)
    end
    process_group()


    return groups
end

---@return { { string, string } } diff_texts
function M.step3_final_aggregate_and_standardize(groups)
    local final_diff = {}
    for _, group in ipairs(groups) do
        -- print("group", inspect(group))
        for _, text in ipairs(group) do
            -- FYI also flattening the groups (SelectMany)
            -- print("  text", inspect(text))
            -- add any missing implicit newlines
            if text[1] == '=' then
                text[2] = text[2] .. '\n'
                -- FYI could leave checks for =/+/- but I already mapped those in step 2 to include explicit newlines
            end

            -- * insert -/+ verbatim (they're already consolidated too)
            if text[1] == 'add' or text[1] == '+' then
                table.insert(final_diff, { '+', text[2] })
                goto continue
            elseif text[1] == 'del' or text[1] == '-' then
                table.insert(final_diff, { '-', text[2] })
                goto continue
            end

            -- * aggregate same/= across groups/items
            local last_text = final_diff[#final_diff]
            if last_text ~= nil and last_text[1] == '=' then
                -- append to preceding same text
                last_text[2] = last_text[2] .. text[2]
            else
                -- insert as a new same text
                table.insert(final_diff, { '=', text[2] })
            end
            ::continue::
        end
    end
    return final_diff
end

function M.combined_diff(old_text, new_text)
    local histogram_line_diff = histogram.split_then_diff_lines(old_text, new_text)
    local groups = M.step2_lcs_diffs(histogram_line_diff)
    local final_diff = M.step3_final_aggregate_and_standardize(groups)
    return final_diff
end

return M
