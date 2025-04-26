local luadiff = require("lua.zeta.copied.diff")

--%%

-- FYI do not use local when sending to iron.nvim lua repl (only lines directly sent, funcs call can have nested locals)
--   issue is, each local is scoped to the cell/line executing in the repl and not avail after the "cell"/line is done running

-- initializes every key to have a value of 0
--   on the first use of that key
--   subsequent uses will retrieve the stored value (not use __index)
mt_tbl = {
    __index = function(t, k)
        print("setting t[" .. k .. "] = 0")
        t[k] = 0
        return k
    end
}
grid = setmetatable({}, mt_tbl)
print(grid[3]) -- 0
print(grid[3]) -- 0

other = {}
print(other[3]) -- nil

--%%



local before = [[
function M.add(a, b)
    return a + b
end
]]

local after = [[
function M.add(a, b, c)
    return a + b
end
]]

local _diff = luadiff.diff(before, after)

local _after2 = [[
function M.add(a, b, c)
    return a + b + c
end
]]
