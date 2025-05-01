local should = require("zeta.helpers.should")
local histogram = require("zeta.diff.histogram")

describe("test using histogram diff", function()
    it("with lines", function()
        local A = {
            "foo",
            "the cow",
            "the cow",
            "baz",
        }
        local B = {
            "the cow",
            "qux the flux",
            "the cow",
            "baz",
        }

        local expected = {
            { "-", "foo" },
            { " ", "the cow" },
            { "+", "qux the flux" },
            { " ", "the cow" },
            { " ", "baz" },
        }
        local diff = histogram.diff(A, B)
        for _, line in ipairs(diff) do
            print(line[1] .. " " .. line[2])
        end

        should.be_same(expected, diff)
    end)
end)
