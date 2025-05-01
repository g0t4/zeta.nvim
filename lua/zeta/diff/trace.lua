local inspect = require("zeta.helpers.dump")

local M = {}

M.lines = {}
function M.pretty(...)
    local args = { ... }
    for i, arg in ipairs(args) do
        args[i] = inspect(arg, true)
    end
    table.insert(M.lines, args)
end

--- == trace.raw(inspect(arg1, false), inspect(arg2, false), ...)
function M.inspet_plain(...)
    local args = { ... }
    for i, arg in ipairs(args) do
        args[i] = inspect(arg, false)
    end
    table.insert(M.lines, args)
end

function M.raw(...)
    table.insert(M.lines, { ... })
end

function M.flush()
    for _, line in ipairs(M.lines) do
        print(unpack(line))
    end
    M.lines = {}
end

return M
