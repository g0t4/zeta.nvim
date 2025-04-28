-- PRN! port to use plenary test:
--
require("zeta.helpers.dump")
t = { x = 1 }
setmetatable(t, {
    __newindex = function(table, key, value)
        print("setting", key, "to", value)
        rawset(table, key, value)
    end,
    __index = function(table, key)
        print("getting", key)
        return rawget(table, key)
    end
})

t.x -- (no print)
t.x = 2 -- (no print)
t.y -- (getting y)
t.y -- (getting y)
t.y = 3 -- (setting y)
t.y -- 3 (no print)
t.y = 4 -- (no print)
t.y -- (no print)

t.z -- (getting z)
t.z -- (getting z)
t.z = nil -- (setting z)
t.z = nil -- (setting z)
-- nil ~= delete
t.z -- (getting z)

t.z = 1 -- (setting z)
t.z -- (no prints)


-- TODO! something is wrong in iron.nvim, with lua repl at least... isf/icf/isu... send file/until... there's repeated code in repl as if its pasted over the top of itself
--   TODO can I change repl to allow scope across cells/calls?
-- FYI, again, not using local b/c that won't work when this is sent to a repl
--   TODO is the isf/icf failure also the issue with local?
lazy_zeros_metatable = {
    __index = function(table, key)
        -- only called if key/index doesn't already exist
        --   or was last set to nil
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
        print("setting key " .. key .. " to zero")
        table[key] = 0
        -- return table[key]
        return 0
    end
}

lazy_zeros_matrix_metatable = {
    __index = function(table, row_index)
        -- yes, I am naming this in accordance with using only 2D in mind
        -- FYI, again, this is only called on first use of table[row_index] (or if table[row_index] was set to nil previously)
        print("setting default row", row_index)
        local new_row = setmetatable({}, lazy_zeros_metatable)
        table[row_index] = new_row
        return new_row
    end
}



test_matrix = setmetatable({}, lazy_zeros_matrix_metatable)
print(inspect(test_matrix[1]))
test_matrix[2] -- setting
test_matrix[2][1] = "foo" -- no print
test_matrix[3][1] = "bar" -- setting

print(test_matrix[3][1]) -- no print
print(test_matrix[3][2]) -- setting key 2 to zero (b/c this is a getter)
print(test_matrix[3][2]) -- no print

