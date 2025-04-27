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

local lazy_zeros_row_metatable = {
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
        table[key] = 0
        return 0
    end
}
function lazy_zeros_row_metatable:new()
    return setmetatable({}, lazy_zeros_row_metatable)
end

local lazy_zeros_matrix_metatable = {
    __index = function(table, row_index)
        -- named with only 2D in mind (row per old_token, col per new_token)
        -- __index only called on first use of table[row_index]
        -- or if table[row_index] was set to nil previously
        -- print("new row " .. row_index)

        local new_row = lazy_zeros_row_metatable:new()
        table[row_index] = new_row
        return new_row
    end
}
function lazy_zeros_matrix_metatable:new()
    return setmetatable({}, lazy_zeros_matrix_metatable)
end

function M.get_longest_common_subsequence_matrix(before_tokens, after_tokens)
    local cum_matrix = lazy_zeros_matrix_metatable:new()
    for i, old_token in ipairs(before_tokens) do
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
                cum_matrix[i][j] = math.max(left_cum, up_cum)
            end
        end
    end
end

function M.visualize_longest_common_subsequence_matrix(before_tokens, after_tokens)
    -- FYI test drive "cumulative" as a way to describe the matrix
    --   as more than just a "binary" true/false match matrix (intersection of tokens)
    local cumulative_matrix = lazy_zeros_matrix_metatable:new()
    local match_matrix = lazy_zeros_matrix_metatable:new() -- just for fun, to illustrate naming differences
    for i, old_token in ipairs(before_tokens) do
        for j, new_token in ipairs(after_tokens) do
            cumulative_matrix[i][j] = tostring(old_token) .. " | " .. tostring(new_token)
            if old_token == new_token then
                match_matrix[i][j] = old_token
            else
                -- JUST set a value for inspect purposes only:
                -- set to space so inspect aligns with "set" tokens... would need length actually of new_token (for col align)
                local spaces = string.rep(" ", #new_token)
                match_matrix[i][j] = spaces
            end
        end
    end
    print(inspect(cumulative_matrix, true))
    print(inspect(match_matrix, true))
end

return M
