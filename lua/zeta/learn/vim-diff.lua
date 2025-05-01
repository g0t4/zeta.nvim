local parser = require("zeta.helpers.response-parser")
local files = require("zeta.helpers.files")


describe("vim.diff", function()
    it("tests vim.diff", function()
        local zed_request = files.read_example("01_request.json")
        local zed_response = files.read_example("01_response.json")

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
    end)
end)
