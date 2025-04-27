-- TODO re-implement algo that I devised on paper.. maybe wait until tomorrow to help ideas solidify
--
-- for now I understand how the other one works which is what I initially set out to do
--   even if I don't like how it works, it works and what it produces is all I care about
--   but I would like practice with LCS so I would like to revist it
--     probably will nag at me and make me do it tonight
require("lua.zeta.helpers.dump")


local M = {}


-----------------------------------------------------------------------------
-- Split a string into tokens.  (Adapted from Gavin Kistner's split on
-- http://lua-users.org/wiki/SplitJoin.
--
-- @param text           A string to be split.
-- @param separator      [optional] the separator pattern (defaults to any
--                       white space - %s+).
-- @param skip_separator [optional] don't include the sepator in the results.
-- @return               A list of tokens.
-----------------------------------------------------------------------------
function M.split(text, separator, skip_separator)
    -- copied verbatim from diff.lua (thus far)
    separator = separator or "%s+"
    local parts = {}
    local start = 1
    local split_start, split_end = text:find(separator, start)
    while split_start do
        table.insert(parts, text:sub(start, split_start - 1))
        if not skip_separator then
            table.insert(parts, text:sub(split_start, split_end))
        end
        start = split_end + 1
        split_start, split_end = text:find(separator, start)
    end
    if text:sub(start) ~= "" then
        table.insert(parts, text:sub(start))
    end
    return parts
end

local zeros_until_set_row = {
    __index = function(table, key)
        -- only called if key/index doesn't already exist
        --   or was set to nil
        --
        --  lazy == defaults to zero on first use
        --  don't waste time/resources initializing table of zeros
        --  also useful:
        --    if don't know table size
        --      infinite size
        --    edge cases, when zero is a sufficient/desirable default
        --      instead of extra boundary checks, in code
        --      that said, magic is not free... YMMV
        --      can easily be more confusing, i.e. if you gravitate toward single letter variable names
        --
        -- umm not reason to set zero actually! just return it until someone else sets it to specific value!
        --   b/c setting it was fubaring prints too (added new row with sporadic set values ... yuck)
        -- table[key] = 0
        return 0
    end
}
function zeros_until_set_row:new()
    return setmetatable({}, zeros_until_set_row)
end

local zeros_until_set_matrix = {
    __index = function(table, row_index)
        -- named with only 2D in mind (row per old_token, col per new_token)
        -- __index only called on first use of table[row_index]
        -- or if table[row_index] was set to nil previously
        -- print("new row " .. row_index)

        local new_row = zeros_until_set_row:new()
        -- auto add the row
        table[row_index] = new_row
        return new_row
    end
}
function zeros_until_set_matrix:new()
    return setmetatable({}, zeros_until_set_matrix)
end

function M.get_longest_common_subsequence_matrix(before_tokens, after_tokens)
    local cum_matrix = zeros_until_set_matrix:new()
    for i, old_token in ipairs(before_tokens) do
        -- print(i .. " " .. old_token)
        for j, new_token in ipairs(after_tokens) do
            if old_token == new_token then
                -- increment sequence length (cumulative value) - up 1 row, left 1 column (NW direction)
                cum_matrix[i][j] = cum_matrix[i - 1][j - 1] + 1
            else
                -- max(cell above, cell to left)
                local left_cum = cum_matrix[i][j - 1]
                local up_cum = cum_matrix[i - 1][j]
                -- TODO ok now this feels like the right way to think about the algorithm...
                --  find a better name than left/up cumulative...
                --  what does each represent when taking the max
                --  * something about longest_sequence_so_far_in_[before|after]_tokens
                --     * longest_cum_so_far?
                --     copying that max (thus far) since this isn't a match (and therefore cannot increment it!)
                cum_matrix[i][j] = math.max(left_cum, up_cum)
            end
            -- print("  " .. j .. " - " .. cum_matrix[i][j])
        end
    end
    -- optional:
    cum_matrix[0] = nil -- wipe out first row, it's empty b/c just used to read zeros w/o boundary condition check on i = 1
    return cum_matrix
end

function M.get_longest_sequence(before_tokens, after_tokens)
    local lcs_matrix = M.get_longest_common_subsequence_matrix(before_tokens, after_tokens)

    function _get_longest(num_before_tokens, num_after_tokens)
        if num_before_tokens < 1 or num_after_tokens < 1 then
            -- base case / terminal condition
            return {}
        end
        local longest_length = lcs_matrix[num_before_tokens][num_after_tokens]
        -- now find a match with that length
        local old_token = before_tokens[num_before_tokens]
        local new_token = after_tokens[num_after_tokens]
        if old_token == new_token then
            -- this is part of longest sequence (the last token)!
            -- move to previous token in both old/new sets, hence - 1 on both
            local rest = _get_longest(num_before_tokens - 1, num_after_tokens - 1)
            table.insert(rest, old_token)
            return rest
        end

        -- btw up/left first doesn't matter
        -- can lead to different longest sequence selection (when multiple)
        -- and if you land on a non-matching (tokens) cell with longest_length == longest_above == longest_to_left,
        --    then you've got at least two longest sequences with a suffix that matches (thus far)
        -- anyways, so long as you get one longest sequence, it doesn't matter which way you go
        -- that said, is there any benefit to going up first or left first?
        --   push more of the sequnce into the start of the before_tokens vs after_tokens?
        -- probably wise to be deterministic with multiple runs of the same sequences...
        --   don't flip a coin each time!

        -- look above, if cumulative value is same as longest_length it means there is a token above that is part of a longest length sequence
        local longest_above = lcs_matrix[num_before_tokens - 1][num_after_tokens]
        if longest_above == longest_length then
            -- not on a token so nothing to add to list
            return _get_longest(num_before_tokens - 1, num_after_tokens)
        end

        -- otherwise, there's a match token to the left that is part of a longest length sequence
        -- assertion:
        local longest_to_left = lcs_matrix[num_before_tokens][num_after_tokens - 1]
        if longest_to_left ~= longest_length then
            error("UNEXPECTED... longest_to_left (" .. longest_to_left .. ")"
                .. " should match logest_length (" .. longest_length .. ")"
                .. ", when longest_above (" .. longest_above .. ") does not!")
        end
        return _get_longest(num_before_tokens, num_after_tokens - 1)
    end

    return _get_longest(#before_tokens, #after_tokens)
end

function M.get_match_matrix(before_tokens, after_tokens)
    local match_matrix = zeros_until_set_matrix:new() -- just for fun, to illustrate naming differences
    for i, old_token in ipairs(before_tokens) do
        for j, new_token in ipairs(after_tokens) do
            if old_token == new_token then
                match_matrix[i][j] = old_token
            else
                match_matrix[i][j] = " "
            end
        end
    end
    return match_matrix
end

return M
