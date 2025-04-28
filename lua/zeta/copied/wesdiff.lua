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
    function diff_walker(before_tokens, after_tokens, num_remaining_before_tokens, num_remaining_after_tokens, visitor)
        local lcs_matrix = M.get_longest_common_subsequence_matrix(before_tokens, after_tokens)
        -- TODO remove when done refactoring.. can also look into expand plenary's test output runner max lines so its not truncated in a SOF (then this isn't needed)
        local max_iterations = #before_tokens + #after_tokens
        local iteration_counter = 0

        while num_remaining_before_tokens > 0 or num_remaining_after_tokens > 0 do
            if iteration_counter > max_iterations then
                error("exceeded max possible iterations: " .. max_iterations)
            end
            iteration_counter = iteration_counter + 1

            -- * match?
            local old_token = before_tokens[num_remaining_before_tokens]
            local new_token = after_tokens[num_remaining_after_tokens]
            print("old_token: '" .. tostring(old_token) .. "' - " .. num_remaining_before_tokens)
            print("new_token: '" .. tostring(new_token) .. "' - " .. num_remaining_after_tokens)
            if old_token == new_token then
                visitor:on_match(old_token)
                -- this is part of longest sequence (the last token)!
                -- move to previous token in both old/new sets, hence - 1 on both
                num_remaining_before_tokens = num_remaining_before_tokens - 1
                num_remaining_after_tokens = num_remaining_after_tokens - 1
                -- FYI lua has no continue, so short of nesting an else block, I am using goto to simulate continue
                --   chill it... continue is implicitly a goto anyways
                goto continue_while
            end

            -- btw up/left first doesn't matter, best to be deterministic
            -- if you land on a non-matching (token) cell with longest_length == longest_above == longest_to_left,
            --    then you've got at least two longest sequences with a shared suffix
            --    pick either is fine, unless you have additional constraints beyond longest

            local current_longest_sequence_position = lcs_matrix[num_remaining_before_tokens][num_remaining_after_tokens]
            local longest_sequence_above = lcs_matrix[num_remaining_before_tokens - 1][num_remaining_after_tokens]
            local longest_sequence_left = lcs_matrix[num_remaining_before_tokens][num_remaining_after_tokens - 1]
            print("  longests:  " .. longest_sequence_above)
            print("           " .. longest_sequence_left .. "<" .. current_longest_sequence_position)

            -- TODO drop comparing current_longest_sequence_position to longest_above/below?? or not?
            -- - pick whichever is bigger (assuming it matches current/outstanding sequence length)
            -- - AND that has tokens left for that direction (i.e. toward upper left you can run into 0 for above/below and current when just have all adds or deletes remaining at start of sequence
            -- - and if they match, then pick up

            -- * move up?
            local any_before_tokens_remain = num_remaining_before_tokens > 0
            if any_before_tokens_remain and longest_sequence_above == current_longest_sequence_position then
                -- this means there's a match token somewhere above that is part of a longest sequence

                -- TODO setup tests for these (comment out again and test before/after adding):
                local deleted_token = before_tokens[num_remaining_before_tokens]
                visitor:on_delete(deleted_token)

                num_remaining_before_tokens = num_remaining_before_tokens - 1
                goto continue_while
            end

            -- * else, move left
            -- this means there's a match token somewhere to the left that is part of a longest sequence
            -- optional assertions (mirror the check for move up case)
            if longest_sequence_left ~= current_longest_sequence_position then
                error("UNEXPECTED... this suggests a bug in building/traversing LCS matrix... longest_to_left (" .. longest_sequence_left .. ")"
                    .. " should match logest_length (" .. current_longest_sequence_position .. ")"
                    .. ", when longest_above (" .. longest_sequence_above .. ") does not!")
            end
            local any_after_tokens_remain = num_remaining_after_tokens > 0
            if not any_after_tokens_remain then
                -- this is only possible due to a bug, b/c base case happens when both longest_sequence_(above and left) are < 1
                error("UNEXPECTED... both before and after tokens appear fully traveresed and yet the base condition wasn't hit")
            end

            -- TODO setup tests for these (comment out again and test before/after adding):
            local added_token = after_tokens[num_remaining_after_tokens]
            visitor:on_add(added_token)

            num_remaining_after_tokens = num_remaining_after_tokens - 1

            ::continue_while::
        end
    end

    local lcs_builder = {
        longest_sequence = {},
    }
    function lcs_builder:on_match(token)
        -- traverses in reverse, so insert token at start of list to ensure we get left to right sequence
        table.insert(self.longest_sequence, 1, token)
        print("  same", token)
    end

    function lcs_builder:on_add(token)
        print("  move left / add", token)
    end

    function lcs_builder:on_delete(token)
        print("  move up / del", token)
    end

    diff_walker(before_tokens, after_tokens, #before_tokens, #after_tokens, lcs_builder)
    return lcs_builder.longest_sequence
end

function M.get_token_diff(before_tokens, after_tokens)
    -- TODO strip out common prefix and suffix token to avoid overhead in LCS?
    --   measure impact on timing

    -- FYI this is gonna be done using a visitor for getting LCS? Or just inline it?
    --  basically you visit each token as you build the LCS (matches and non-matches)
    --  I don't really need to get just the LCS but I like having it alone (esp for tesing)...
    --  so I could reimpl it with a cell visitor (func) arg
end

function M.get_diff(before_tokens, after_tokens)
    -- aggregate across token diff
    local token_diff = M.get_token_diff(before_tokens, after_tokens)
    -- TODO (combine consecutive tokens with same diff type (same/del/add)
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
