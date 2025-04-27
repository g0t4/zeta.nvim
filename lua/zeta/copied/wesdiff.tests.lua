local assert = require("luassert")
local wesdiff = require("lua.zeta.copied.wesdiff")

local function should_be_equal(expected, actual)
    assert.are.equal(expected, actual)
end

local function should_be_same(expected, actual)
    assert.are.same(expected, actual)
end

local function should_be_nil(actual)
    -- FYI you can join with _ instead of dot (.)
    --   must use this for keywords like nil, function, etc
    assert.is_nil(actual)
end

describe("tiny comparison with no leading/trailing comonality", function()
    local before_text = [[b )]]

    local after_text = [[b, c, d)]]
    it("splits words", function()
        -- FYI this is testing the inner details, but I wanna lock those in as the split matters
        -- leaving separator as whitespace default AND keeping separator
        -- IOTW no need to pass anything but first arg
        local before_tokens = wesdiff.split(before_text)
        should_be_same({ "b", " ", ")" }, before_tokens)

        local after_tokens = wesdiff.split(after_text)
        should_be_same({ "b,", " ", "c,", " ", "d)" }, after_tokens)
    end)

    it("computes lcs_matrix", function()
        -- local lcs_matrix = wesdiff.get_lcs_matrix(before_text, after_text)
    end)
end)


describe("simple comparison", function()
    local before_text = [[
function M.add(a, b )
    return a + b
end
]]

    local after_text = [[
function M.add(a, b, c, d)
    return a + b
end
]]
end)
