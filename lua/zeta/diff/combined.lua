local histogram = require("zeta.diff.histogram")
local weslcs = require("zeta.diff.weslcs")
local should = require("zeta.helpers.should")
local files = require("zeta.helpers.files")
require("zeta.helpers.dump")

function combined_diff(old, new)
end

describe("simple comparison", function()
    local before_text = [[
function M.add(a, b )
    return a + b
end]]

    local after_text = [[
function M.add(a, b, c, d)
    return a + b
end]]
    it("validate histogram alone", function()
        local diffs = histogram.split_then_diff_lines(before_text, after_text)

        print(inspect(diffs, true))

        local expected = {
            { "-", "function M.add(a, b )" },
            { "+", "function M.add(a, b, c, d)" },
            { " ", "    return a + b" },
            { " ", "end" },
        }

        should.be_same(expected, diffs)
    end)
end)

--
-- describe("test using combined_diff", function()
--     local before = files.read_example_json_excerpt("01_request.json")
--     local after = files.read_example_json_excerpt("01_response.json")
--     it("test histogram alone", function()
--         local diffs = histogram.split_then_diff_lines(before, after)
--
--         print(diffs)
--         local expected = {
--             { "+", "" }
--
--         }
--     end)
--     it("with lines", function()
--         local diffs = combined_diff(before, after)
--     end)
-- end)
