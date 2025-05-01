local histogram = require("zeta.diff.histogram")
local weslcs = require("zeta.diff.weslcs")
local should = require("zeta.helpers.should")
local files = require("zeta.helpers.files")
require("zeta.helpers.dump")


---@param histogram_line_diff {type: string, line: string}[]
---@return {type: string, chunks: string}[]
function step2_lcs_diffs(histogram_line_diff)
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
        if current_group["="] == nil
            and current_group["-"] == nil
            and current_group["+"] == nil then
            -- if current_group is truly empty (no historgram lines) then don't add it as empty group!
            -- can happen at start and end of loop, this is a nice spot to handle it
            return
        end

        -- * group of consecutive "=" anchor lines
        if current_group["="] then
            -- loop logic stripped the leading '=', and I want that back on individual records
            -- that way these match the structure of LCS diff output
            -- so, add back "=" as line[1] and line[2] is once again the text
            -- result:
            --   { { "=", "line1" }, { "=", "line2" } }
            local consecutive_anchor_lines = vim.iter(current_group["="])
                :map(function(line) return { "=", line } end):totable()
            table.insert(groups, consecutive_anchor_lines)
            -- NO LCS diffing, these are already the same (anchors)
            current_group = {}
            return
        end

        -- * run LCS diff on lines between anchor lines
        local dels = current_group["-"] or {}
        local adds = current_group["+"] or {}

        -- * histogram "-" (aka deletes) are lines identified as only in the old text
        -- - my LCS algorithm takes a single string, not list of lines
        -- - so, I join histogram "-"s into a single string called "before_text"
        local before_text_string = vim.iter(dels)
            :map(function(line)
                -- super important to add back the _IMPLICIT NEWLINE_ \n suffix on histogram lines
                -- AND, need trailing \n for every line, not just between lines
                return line .. "\n"
            end)
            :join("")
        -- * histogram "+" (aka adds) are lines identified as only in the new text
        local after_text_string = vim.iter(adds)
            :map(function(line)
                return line .. "\n"
            end)
            :join("")
        local lcs_diff = weslcs.get_diff_from_text(before_text_string, after_text_string)
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
        local change_to_anchor = current_group["="] and line_type ~= "="
        local change_from_anchor = (not current_group["="]) and line_type == "="
        if change_to_anchor or change_from_anchor then
            process_group()
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

function combined_diff(old_text, new_text)
    local histogram_line_diff = histogram.split_then_diff_lines(old_text, new_text)
    -- TODO test this combined_diff end to end too
    local with_lsc = step2_lcs_diffs(histogram_line_diff)
    -- local lsc_aggregated = step3_aggregate_lscs(with_lsc)
    -- local merged = step4_merge_lsc_and_histogram_sames(lsc_aggregated)
    return histogram_line_diff
end

describe("simple comparison", function()
    local before_text = [[
local M = {}
function M.add(a, b )
    return a + b
end
return M]]

    -- FYI first new line doesn't result in a line in diff
    --  but trailing new line after return N does add a blank line
    local after_text = [[
local M = {}
function M.add(a, b, c, d)
    return a + b
end
return N
]]
    it("validate histogram alone", function()
        local diffs = histogram.split_then_diff_lines(before_text, after_text)

        -- pretty_print(diffs)

        -- FYI I wanted 2+ alternating groups of same/diff lines
        local expected = {
            { "=", "local M = {}" },
            { "-", "function M.add(a, b )" },
            { "+", "function M.add(a, b, c, d)" },
            { "=", "    return a + b" },
            { "=", "end" },
            { "-", "return M" },
            -- two consecutive added lines, should be diff'd with single - above
            { "+", "return N" },
            { "+", "" },
        }

        should.be_same(expected, diffs)
    end)

    it("follows histogram with a 2nd pass, word-level LCS", function()
        local histogram_line_diff = histogram.split_then_diff_lines(before_text, after_text)
        local diffs = step2_lcs_diffs(histogram_line_diff)

        -- pretty_print(diffs)

        -- Notes:
        -- - I wanted 2+ alternating groups of same vs del/add LCS lines
        -- - part of the reason I kept =/+/- is so I can track the implicit vs explicit new lines
        -- - don't forget for LCS, whitesapce is treated as a word too!
        local expected_groups = {

            -- STEP1/2 Histogram Anchors
            -- FYI implicit new lines
            { { "=", "local M = {}" } }, -- implicit \n

            -- STEP2 LCS input:
            -- FYI implicit new lines:
            -- { "-", "function M.add(a, b )" }, -- implicit \n
            -- { "+", "function M.add(a, b, c, d)" }, -- implicit \n
            --
            -- STEP2 LCS output:
            -- FYI explicit new lines
            { { "same", "function M.add(a, " },
                { "del",  "b )\n" },
                { "add",  "b, c, d)\n" }, },

            -- STEP1/2 Histogram Anchors
            -- FYI implicit new lines
            { { "=", "    return a + b" }, -- implicit \n
                { "=", "end" }, }, -- implicit \n

            -- STEP2 LCS input:
            -- FYI implicit new lines:
            -- { "-", "return M" },
            -- { "+", "return N" },
            -- { "+", "" },
            --
            -- STEP2 LCS output:
            -- FYI explicit new lines
            { { "same", "return " },
                { "del",  "M\n" },
                { "add",  "N\n" }, },
        }

        should.be_same(expected_groups, diffs)
    end)
end)

describe("simple comparison", function()
    local before_text = [[
function M.add(a, b )
    return a + b
end]]

    local after_text = [[
function M.add(a, b, c, d)
    return a + b
end]]

    it("validate histogram alone", function()
        local diffs = histogram.split_then_diff_lines(before_text, after_text)

        -- pretty_print(diffs)

        local expected = {
            { "-", "function M.add(a, b )" },
            { "+", "function M.add(a, b, c, d)" },
            { "=", "    return a + b" },
            { "=", "end" },
        }

        should.be_same(expected, diffs)
    end)
end)

describe("test using combined_diff", function()
    local old_text = files.read_example_editable_only("01_request.json")
    local new_text = files.read_example_editable_only("03_response.json")

    it("test histogram alone", function()
        local diffs = histogram.split_then_diff_lines(old_text, new_text)

        local expected = {
            { "=", "" }, -- empty line after editable region parsed, should that be removed?
            { "=", "local M = {}" },
            { "=", "" },
            { "-", "function M.add(a, b)" },
            { "-", "    return a + b" },
            { "+", "function M.adder(a, b, c)" },
            { "+", "    return a + b + c" },
            { "=", "end" },
            { "=", "" },
            { "-", "<|user_cursor_is_here|>" },
            { "+", "function M.subtract(a, b)" },
            { "+", "    return a - b" },
            { "+", "end" },
            { "=", "" },
            { "+", "function M.multiply(a, b)" },
            { "+", "    return a * b" },
            { "+", "end" },
            { "=", "" },
            { "+", "function M.divide(a, b)" },
            { "+", "    if b == 0 then" },
            { "+", "        error(\"Division by zero\")" },
            { "+", "    end" },
            { "+", "    return a / b" },
            { "+", "end" },
            { "=", "" },
            { "+", "" },
            { "+", "" },
            { "=", "return M" },
            { "=", "" },
            { "=", "" },
        }

        should.be_same(expected, diffs)
    end)

    -- it("with lines", function()
    --     local diffs = combined_diff(old_text, new_text)
    --     TODO!!! might be good to do one more... but, feed the LCS lines into LCS and capture output on each group... don't compute this by hand Wes!
    -- end)
end)
