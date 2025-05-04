require("zeta.helpers.testing")
local parser = require("zeta.helpers.tags")
local files = require("zeta.helpers.files")
local should = require("zeta.helpers.should")
local messages = require("devtools.messages")

_describe("vim.diff", function()
    it("tests vim.diff", function()
        local zed_request = files.read_example("01_request.json")
        local zed_response = files.read_example("01_response.json")

        local request_decoded = vim.json.decode(zed_request)
        local response_decoded = vim.json.decode(zed_response)

        local input_excerpt = request_decoded.input_excerpt
        local output_excerpt = response_decoded.output_excerpt

        local input_editable = parser.get_editable_region(input_excerpt) or ""
        local output_editable = parser.get_editable_region(output_excerpt) or ""

        -- hey, any value in retrieving cursor position?
        input_editable = input_editable:gsub(parser.tag_cursor_here, "")

        vdiff = vim.diff(input_editable, output_editable)
        messages.header("vdiff")
        messages.append(vdiff)

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

        should.be_same(ref_vdiff, vdiff)
    end)
end)
