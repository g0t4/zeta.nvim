local M = {}

-- tmp type hints for my dump func (so I can avoid using :messages)
---@type fun(...)
_G.BufferDump = _G.BufferDump
---@type fun(...)
_G.BufferDumpAppend = _G.BufferDumpAppend




local tag_edit_start = "<|editable_region_start|>"
local tag_edit_end = "<|editable_region_end|>"
local tag_cursor_here = "<|user_cursor_is_here|>"
local tag_start_of_file = "<|start_of_file|>"



---@param text string
local function get_editable(text)
    local start_index = text:find(tag_edit_start)
    local end_index = text:find(tag_edit_end)
    if start_index == nil
        or end_index == nil
        or start_index < 0
        or end_index < start_index then
        return nil
    end
    start_index = start_index + #tag_edit_start
    end_index = end_index - 1
    return text:sub(start_index, end_index)
end

function M.test_zeta()
    local zed_request =
    '{"outline":"```lua/ask-openai/prediction/tests/calc/calc.lua\nfunction M.add\n```\n","input_events":"User edited \\"lua/ask-openai/prediction/tests/calc/calc.lua\\":\n```diff\n@@ -7,4 +7,5 @@\n \n \n \n+\n return M\n\n```\n\nUser edited \\"lua/ask-openai/prediction/tests/calc/calc.lua\\":\n```diff\n@@ -8,4 +8,5 @@\n \n \n \n+\n return M\n\n```\n\nUser edited \\"lua/ask-openai/prediction/tests/calc/calc.lua\\":\n```diff\n@@ -8,5 +8,4 @@\n \n \n \n-\n return M\n\n```","input_excerpt":"```ask-openai.nvim/lua/ask-openai/prediction/tests/calc/calc.lua\n<|start_of_file|>\n<|editable_region_start|>\nlocal M = {}\n\nfunction M.add(a, b)\n    return a + b\nend\n\n<|user_cursor_is_here|>\n\n\n\nreturn M\n\n<|editable_region_end|>\n```","speculated_output":"<|editable_region_start|>\nlocal M = {}\n\nfunction M.add(a, b)\n    return a + b\nend\n\n<|user_cursor_is_here|>\n\n\n\nreturn M\n\n<|editable_region_end|>","can_collect_data":false,"diagnostic_groups":[]}'
    local zed_response =
    '{"output_excerpt":"<|editable_region_start|>\nlocal M = {}\n\nfunction M.add(a, b)\n    return a + b\nend\n\nfunction M.subtract(a, b)\n    return a - b\nend\n\nfunction M.multiply(a, b)\n    return a * b\nend\n\nfunction M.divide(a, b)\n    if b == 0 then\n        error(\\"Division by zero\\")\n    end\n    return a / b\nend\n\n\n\nreturn M\n\n<|editable_region_end|>\n```\n","request_id":"8319778f2ac147f7b1fbe1b0d5424132"}'

    local request_decoded = vim.json.decode(zed_request)
    local response_decoded = vim.json.decode(zed_response)
    -- BufferDumpAppend(request_decoded)
    -- BufferDumpAppend(response_decoded)
    local input_excerpt = request_decoded.input_excerpt
    local output_excerpt = response_decoded.output_excerpt
    -- BufferDumpAppend("## INPUT_EXCERPT")
    -- BufferDumpAppend(input_excerpt)
    -- BufferDumpAppend("\n\n\n## OUTPUT_EXCERPT")
    -- BufferDumpAppend(output_excerpt)

    local input_editable = get_editable(input_excerpt)
    local output_editable = get_editable(output_excerpt)
    assert(input_editable ~= nil)
    assert(output_editable ~= nil)

    BufferDumpAppend("## INPUT_EDITABLE")
    BufferDumpAppend(input_editable)
    -- hey, any value in retrieving cursor position?
    input_editable = input_editable:gsub(tag_cursor_here, "")
    BufferDumpAppend("## INPUT_EDITABLE (sans <|user_cursor_is_here|>)")
    BufferDumpAppend(input_editable)
    BufferDumpAppend("\n\n## OUTPUT_EDITABLE")
    BufferDumpAppend(output_editable)

end

function M.setup()
    vim.keymap.set("n", "<leader>z", M.test_zeta, {})
end

return M
