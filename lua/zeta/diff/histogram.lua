local should = require("zeta.helpers.should")

local M = {}

local function build_histogram(seq)
    local hist = {}
    for _, token in ipairs(seq) do
        hist[token] = (hist[token] or 0) + 1
    end
    return hist
end

local function find_rarest_common_token(a, hist_a, hist_b)
    local min_count, rare_token = math.huge, nil
    local already_seen = {}
    for _, token in ipairs(a) do
        if hist_b[token] and not already_seen[token] then
            local count = hist_a[token] + hist_b[token]
            if count < min_count then
                min_count, rare_token = count, token
            end
            already_seen[token] = true
        end
    end
    return rare_token
end

function M.diff(a, b, diffs)
    diffs = diffs or {}

    -- nothing to compare on at least one side
    if #a == 0 then
        for _, token in ipairs(b) do
            table.insert(diffs, { "+", token })
        end
        return diffs
    elseif #b == 0 then
        for _, token in ipairs(a) do
            table.insert(diffs, { "-", token })
        end
        return diffs
    end

    local hist_a = build_histogram(a)
    local hist_b = build_histogram(b)

    local rarest_token = find_rarest_common_token(a, hist_a, hist_b)
    if not rarest_token then
        -- fallback: all tokens changed
        for _, tokens in ipairs(a) do table.insert(diffs, { "-", tokens }) end
        for _, tokens in ipairs(b) do table.insert(diffs, { "+", tokens }) end
        return diffs
    end

    -- find first match of token in both a and b
    local index_first_match_a, index_first_match_b
    for index, token in ipairs(a) do
        if token == rarest_token then
            index_first_match_a = index
            break
        end
    end
    for index, token in ipairs(b) do
        if token == rarest_token then
            index_first_match_b = index
            break
        end
    end

    -- recursively diff before and after
    M.diff({ unpack(a, 1, index_first_match_a - 1) }, { unpack(b, 1, index_first_match_b - 1) }, diffs)
    table.insert(diffs, { " ", rarest_token })
    M.diff({ unpack(a, index_first_match_a + 1) }, { unpack(b, index_first_match_b + 1) }, diffs)
    -- TODO recursive is likely a problem here

    return diffs
end

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
        local diff = M.diff(A, B)
        for _, line in ipairs(diff) do
            print(line[1] .. " " .. line[2])
        end

        should.be_same(expected, diff)
    end)
end)

return M
