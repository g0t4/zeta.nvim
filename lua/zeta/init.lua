local luadiff = require("zeta.copied.diff")
local parser = require("zeta.helpers.response-parser")
local M = {}

function M.show_diff_extmarks()
    BufferDumpClear()


    local zed_request =
    '{"outline":"```lua/ask-openai/prediction/tests/calc/calc.lua\nfunction M.add\n```\n","input_events":"User edited \\"lua/ask-openai/prediction/tests/calc/calc.lua\\":\n```diff\n@@ -7,4 +7,5 @@\n \n \n \n+\n return M\n\n```\n\nUser edited \\"lua/ask-openai/prediction/tests/calc/calc.lua\\":\n```diff\n@@ -8,4 +8,5 @@\n \n \n \n+\n return M\n\n```\n\nUser edited \\"lua/ask-openai/prediction/tests/calc/calc.lua\\":\n```diff\n@@ -8,5 +8,4 @@\n \n \n \n-\n return M\n\n```","input_excerpt":"```ask-openai.nvim/lua/ask-openai/prediction/tests/calc/calc.lua\n<|start_of_file|>\n<|editable_region_start|>\nlocal M = {}\n\nfunction M.add(a, b)\n    return a + b\nend\n\n<|user_cursor_is_here|>\n\n\n\nreturn M\n\n<|editable_region_end|>\n```","speculated_output":"<|editable_region_start|>\nlocal M = {}\n\nfunction M.add(a, b)\n    return a + b\nend\n\n<|user_cursor_is_here|>\n\n\n\nreturn M\n\n<|editable_region_end|>","can_collect_data":false,"diagnostic_groups":[]}'
    local zed_response =
    '{"output_excerpt":"<|editable_region_start|>\nlocal M = {}\n\nfunction M.add(a, b)\n    return a + b\nend\n\nfunction M.subtract(a, b)\n    return a - b\nend\n\nfunction M.multiply(a, b)\n    return a * b\nend\n\nfunction M.divide(a, b)\n    if b == 0 then\n        error(\\"Division by zero\\")\n    end\n    return a / b\nend\n\n\n\nreturn M\n\n<|editable_region_end|>\n```\n","request_id":"8319778f2ac147f7b1fbe1b0d5424132"}'

    local request_decoded = vim.json.decode(zed_request)
    local response_decoded = vim.json.decode(zed_response)
    local input_excerpt = request_decoded.input_excerpt
    local output_excerpt = response_decoded.output_excerpt

    local input_editable = parser.get_editable(input_excerpt)
    local output_editable = parser.get_editable(output_excerpt)
    assert(input_editable ~= nil)
    assert(output_editable ~= nil)

    input_editable = input_editable:gsub(parser.tag_cursor_here, "")

    local ldiff = luadiff.diff(input_editable, output_editable)
    BufferDumpAppend(ldiff)
    -- "same", "out", "in"
    vim.iter(ldiff):take(10):each(function(k, chunk)
        BufferDumpAppend(chunk)
    end)
end

function M.setup()
    vim.keymap.set("n", "<leader>z", function()
        M.show_diff_extmarks()
    end, {})
    vim.keymap.set("n", "<leader>zl", function()
        require("zeta.learn.find-diff-tool").test_zeta()
    end, {})
end

return M
