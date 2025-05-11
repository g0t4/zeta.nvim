local M = {}
local SPLIT_ON_WHITESPACE = '%s+'
local STRIP_SEPARATORS = true
local KEEP_SEPARATORS = false


-----------------------------------------------------------------------------
-- FYI this came from
--     https://github.com/LuaDist/diff/blob/master/lua/diff.lua#L26
--
-- Split a string into tokens.  (Adapted from Gavin Kistner's split on
-- http://lua-users.org/wiki/SplitJoin.
--
-- @param text           A string to be split.
-- @param separator      [optional] the separator pattern (defaults to any
--                       white space - %s+).
-- @param skip_separator [optional] don't include the sepator in the results.
-- @return               A list of tokens.
-----------------------------------------------------------------------------
local function split_internal(text, separator, skip_separator)
    if separator == nil or separator == '' then
        error('separator cannot be nil or empty string')
    end

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
    if text:sub(start) ~= '' then
        table.insert(parts, text:sub(start))
    end
    return parts
end

function M.split_on_whitespace_then_skip_the_whitespace(text)
    return split_internal(text, SPLIT_ON_WHITESPACE, STRIP_SEPARATORS)
end

function M.split_on_whitespace(text)
    return split_internal(text, SPLIT_ON_WHITESPACE, KEEP_SEPARATORS)
end

return M
