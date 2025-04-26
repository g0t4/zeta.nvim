--
-- *** color output
local color_keys = {
    -- reset
    reset     = 0,

    -- misc
    bright    = 1,
    dim       = 2,
    underline = 4,
    blink     = 5,
    reverse   = 7,
    hidden    = 8,

    -- foreground colors
    black     = 30,
    red       = 31,
    green     = 32,
    yellow    = 33,
    blue      = 34,
    magenta   = 35,
    cyan      = 36,
    white     = 37,

    -- background colors
    blackbg   = 40,
    redbg     = 41,
    greenbg   = 42,
    yellowbg  = 43,
    bluebg    = 44,
    magentabg = 45,
    cyanbg    = 46,
    whitebg   = 47
}
-- print("\27[31mThis is red text\27[0m")
function black(text)
    return "\27[" .. color_keys.black .. "m" .. text .. "\27[" .. color_keys.reset .. "m"
end

function red(text)
    return "\27[" .. color_keys.red .. "m" .. text .. "\27[" .. color_keys.reset .. "m"
end

function blue(text)
    return "\27[" .. color_keys.blue .. "m" .. text .. "\27[" .. color_keys.reset .. "m"
end

function magenta(text)
    return "\27[" .. color_keys.magenta .. "m" .. text .. "\27[" .. color_keys.reset .. "m"
end

function green(text)
    return "\27[" .. color_keys.green .. "m" .. text .. "\27[" .. color_keys.reset .. "m"
end

function tbl_is_list(tbl)
    if type(tbl) ~= "table" then
        return false
    end
    local previous_index = 0
    for index, _ in pairs(tbl) do
        if type(index) ~= "number" then
            return false
        end
        if index ~= previous_index + 1 then
            return false
        end
        previous_index = previous_index + 1
    end
    return true
end

--%%

---@param object any
---@return string description
function inspect(object)
    if object == nil then
        return black("nil")
    elseif type(object) == 'table' then
        -- PRN check if all keys/indicies are integer and consecutive => if so, don't print indicies
        local is_list = tbl_is_list(object)
        local items = {}
        for key, value in pairs(object) do
            if is_list then
                table.insert(items, green(inspect(value)))
            else
                if type(key) ~= 'number' then key = '"' .. key .. '"' end
                local item = '[' .. blue(key) .. '] = ' .. green(inspect(value))
                table.insert(items, item)
            end
        end
        if #items == 0 then
            -- special case, also don't check this on object itself as it won't work on non-list tables
            return "{}"
        end
        return "{ " .. table.concat(items, ", ") .. " }"
    elseif type(object) == "number" then
        return magenta(tostring(object))
    elseif type(object) == "string" then
        local escaped = object:gsub('"', '\\"')
        return '"' .. escaped .. '"'
    else
        -- PRN udf?
        return tostring(object)
    end
end

--%%
