local luadiff = require("lua.zeta.copied.diff")

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
