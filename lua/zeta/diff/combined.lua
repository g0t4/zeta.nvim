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

        pretty_print(diffs)

        local expected = {
            { "-", "function M.add(a, b )" },
            { "+", "function M.add(a, b, c, d)" },
            { " ", "    return a + b" },
            { " ", "end" },
        }

        should.be_same(expected, diffs)
    end)
end)

describe("test using combined_diff", function()
    local old_text = files.read_example_editable_only("01_request.json")
    local new_text = files.read_example_editable_only("03_response.json")

    it("test histogram alone", function()
        local diffs = histogram.split_then_diff_lines(old_text, new_text)

        local expected = {
            { " ", "" }, -- empty line after editable region parsed, should that be removed?
            { " ", "local M = {}" },
            { " ", "" },
            { "-", "function M.add(a, b)" },
            { "-", "    return a + b" },
            { "+", "function M.adder(a, b, c)" },
            { "+", "    return a + b + c" },
            { " ", "end" },
            { " ", "" },
            { "-", "<|user_cursor_is_here|>" },
            { "+", "function M.subtract(a, b)" },
            { "+", "    return a - b" },
            { "+", "end" },
            { " ", "" },
            { "+", "function M.multiply(a, b)" },
            { "+", "    return a * b" },
            { "+", "end" },
            { " ", "" },
            { "+", "function M.divide(a, b)" },
            { "+", "    if b == 0 then" },
            { "+", "        error(\"Division by zero\")" },
            { "+", "    end" },
            { "+", "    return a / b" },
            { "+", "end" },
            { " ", "" },
            { "+", "" },
            { "+", "" },
            { " ", "return M" },
            { " ", "" },
            { " ", "" },
        }

        should.be_same(expected, diffs)
    end)

    it("with lines", function()
        local diffs = combined_diff(old_text, new_text)
    end)
end)
