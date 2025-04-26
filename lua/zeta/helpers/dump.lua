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

---@param object any
---@return string description
function inspect(object)
    if type(object) == 'table' then
        -- PRN check if all keys/indicies are integer and consecutive => if so, don't print indicies
        local is_list = tbl_is_list(object)
        local items = {}
        for key, value in pairs(object) do
            if is_list then
                table.insert(items, inspect(value))
            else
                if type(key) ~= 'number' then key = '"' .. key .. '"' end
                local item = '[' .. key .. '] = ' .. inspect(value)
                table.insert(items, item)
            end
        end
        if #items == 0 then
            -- special case, also don't check this on object itself as it won't work on non-list tables
            return "{}"
        end
        return "{ " .. table.concat(items, ", ") .. " }"
    else
        -- PRN udf?
        return tostring(object)
    end
end

--%%

-- function tests()
--     -- lists:
--     assert(tbl_is_list({ 1, 2, 3 }))
--     assert(tbl_is_list({}))
--     -- not lists:
--     assert(tbl_is_list({ a = 1, b = 2, [3] = 4 }) == false)
--
--     my_inspect({}) -- "{ }"
--     my_inspect({ 1, 2, 3 }) --  == "{ 1, 2, 3, }"
--     my_inspect({ a = 1, b = 2, [3] = 4 })
-- end
-- tests()
