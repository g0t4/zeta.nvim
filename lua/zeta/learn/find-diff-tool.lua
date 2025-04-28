local luadiff = require("zeta.diff.luadiff")
local parser = require("zeta.helpers.response-parser")
local M = {}

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

    local input_editable = parser.get_editable(input_excerpt)
    local output_editable = parser.get_editable(output_excerpt)
    assert(input_editable ~= nil)
    assert(output_editable ~= nil)

    BufferDumpAppend("## INPUT_EDITABLE")
    BufferDumpAppend(input_editable)
    -- hey, any value in retrieving cursor position?
    input_editable = input_editable:gsub(parser.tag_cursor_here, "")
    BufferDumpAppend("## INPUT_EDITABLE (sans <|user_cursor_is_here|>)")
    BufferDumpAppend(input_editable)
    BufferDumpAppend("\n\n## OUTPUT_EDITABLE")
    BufferDumpAppend(output_editable)

    vdiff = vim.diff(input_editable, output_editable)
    BufferDumpAppend("\n\n## vim diff")
    BufferDumpAppend(vdiff)

    ref_vdiff = [[
@@ -7,0 +8,7 @@
+function M.subtract(a, b)
+    return a - b
+end
+
+function M.multiply(a, b)
+    return a * b
+end
@@ -8,0 +16,6 @@
+function M.divide(a, b)
+    if b == 0 then
+        error("Division by zero")
+    end
+    return a / b
+end
]]

    local ldiff = luadiff.diff(input_editable, output_editable)
    BufferDumpAppend(ldiff)
    BufferDumpAppend(ldiff:to_html())
    -- woa cool... splits into chunks: "same", "out", "in"
    --    where out = delete, in = insert
    --    also chunks appear to be word level for ins/del (multiword for same)?
    vim.iter(ldiff):each(function(k, chunk)
        -- show each chunk on its own line:
        BufferDumpAppend(chunk)
    end)

    local chunks_dump_sample = [[
{ "\nlocal M = {}\n\nfunction M.add(a, b)\n    return a + b\nend", "same" }
{ "\n\n\n\n\n\n", "out" }
{ "\n\n", "in" }
{ "function", "in" }
{ " ", "in" }
{ "M.subtract(a,", "in" }
{ " ", "in" }
{ "b)", "in" }
{ "\n    ", "in" }
{ "return", "in" }
]]



    -- and can map to html too (good to visualize):
    --  no tags around text == same, otherwise tags <del></del> and <ins></ins> wrap each chunk
    local html_sample = [[
local M = {}

function M.add(a, b)
    return a + b
end<del>





</del><ins>

</ins><ins>function</ins><ins> </ins><ins>M.subtract(a,</ins><ins> </ins><ins>b)</ins><ins>
    </ins><ins>return</ins><ins> </ins><ins>a</ins><ins> </ins><ins>-</ins><ins> </ins><ins>b</ins><ins>
</ins><ins>end</ins><ins>
]]
end

return M
