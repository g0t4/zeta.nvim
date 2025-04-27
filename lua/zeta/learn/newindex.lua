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
