require("zeta.helpers.inspect")

-- lists:
assert(tbl_is_list({ 1, 2, 3 }))
assert(tbl_is_list({}))
-- not lists:
assert(tbl_is_list({ a = 1, b = 2, [3] = 4 }) == false)

inspect({}) -- "{ }"
inspect({ 1, 2, 3 }) --  == "{ 1, 2, 3, }"
inspect({ a = 1, b = 2, [3] = 4 })
inspect({ a = 'foo" the bar' })
