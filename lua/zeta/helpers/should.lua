local assert = require('luassert')

local M = {}

function M.be_equal(expected, actual)
    assert.are.equal(expected, actual)
end

function M.be_same(expected, actual)
    assert.are.same(expected, actual)
end

function M.be_nil(actual)
    -- FYI you can join with _ instead of dot (.)
    --   must use this for keywords like nil, function, etc
    assert.is_nil(actual)
end

return M
