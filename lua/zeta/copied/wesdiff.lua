-- TODO re-implement algo that I devised on paper.. maybe wait until tomorrow to help ideas solidify
--
-- for now I understand how the other one works which is what I initially set out to do
--   even if I don't like how it works, it works and what it produces is all I care about
--   but I would like practice with LCS so I would like to revist it
--     probably will nag at me and make me do it tonight



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

function M.get_longest_common_subsequence_matrix(before_tokens, new_tokens)
    -- local num_before_tokens = #before_tokens
    -- local num_after_tokens = #after_tokens

    for i, old_token in ipairs(before_tokens) do
        for j, new_token in ipairs(new_tokens) do

        end
    end
end

return M
