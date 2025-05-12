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

---@param a string
---@param b string
---@return table<string, table<string, string>>
function M.split_then_diff_lines(a, b)
    -- PRN add split for other token types?
    local a_lines = vim.split(a, '\n')
    local b_lines = vim.split(b, '\n')
    return M.diff(a_lines, b_lines)
end

---@param a string[]
---@param b string[]
---@return table<string, table<string, string>>
function M.diff(a, b, diffs)
    diffs = diffs or {}

    -- nothing to compare on at least one side
    if #a == 0 then
        for _, token in ipairs(b) do
            table.insert(diffs, { '+', token })
        end
        return diffs
    elseif #b == 0 then
        for _, token in ipairs(a) do
            table.insert(diffs, { '-', token })
        end
        return diffs
    end

    local hist_a = build_histogram(a)
    local hist_b = build_histogram(b)
    -- print('hist_a')
    -- vim.print(hist_a)
    -- print('hist_b')
    -- vim.print(hist_b)

    local rarest_token = find_rarest_common_token(a, hist_a, hist_b)
    -- print("rarest_token '" .. tostring(rarest_token) .. "'")

    if not rarest_token then
        -- fallback: all tokens changed
        for _, tokens in ipairs(a) do table.insert(diffs, { '-', tokens }) end
        for _, tokens in ipairs(b) do table.insert(diffs, { '+', tokens }) end
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
    table.insert(diffs, { '=', rarest_token })
    M.diff({ unpack(a, index_first_match_a + 1) }, { unpack(b, index_first_match_b + 1) }, diffs)
    -- TODO recursive is likely a problem here

    return diffs
end

return M
