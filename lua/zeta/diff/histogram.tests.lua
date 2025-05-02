local should = require("zeta.helpers.should")
local histogram = require("zeta.diff.histogram")
require("zeta.helpers.dump")
require("zeta.helpers.testing")

_describe("test using histogram diff", function()
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
            { "=", "the cow" },
            { "+", "qux the flux" },
            { "=", "the cow" },
            { "=", "baz" },
        }
        local diff = histogram.diff(A, B)

        pretty_print(diff)

        should.be_same(expected, diff)
    end)
end)
