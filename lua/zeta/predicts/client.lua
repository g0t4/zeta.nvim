local files = require("zeta.helpers.files")
local M = {}
function M.get_prediction_request()
    local bufnr = vim.api.nvim_get_current_buf()
    print("## bufnr:", bufnr)

    -- TODO get real file content, and the rest is ready to go!
    -- use treesitter (if available), otherwise fallback to line ranges
    -- input_excerpt
    -- mark editable region (select this first, then expand to gather all of input_excerpt)

    local body_request_01 = files.read_example("01_request.json")
    -- BufferDumpAppend(body_request_01)

    return {
        bufnr = bufnr,
        body = body_request_01
        -- body = {
        --     input_excerpt = "",
        --     -- input_events
        --     -- outline
        -- }
    }
end

function M.show_prediction()
    local url = "http://localhost:9000/predict_edits"
    local prediction_request = M.get_prediction_request()

    -- PRN how can I handle errors? pcall?
    function make_request()
        local result = vim.fn.system({
            "curl",
            "-H", "Content-Type: application/json",
            "-X", "POST",
            "-s", url,
            "-d", vim.fn.json_encode(prediction_request.body)
        })
        return result
    end

    local result = make_request()
    print("## result:")
    print(result)
    do return end

    local decoded = vim.fn.json_decode(result)
    local output_excerpt = decoded.output_excerpt
    assert(output_excerpt ~= nil, "output_excerpt should not be nil")

    -- print("## output_excerpt:")
    -- print(output_excerpt)

    -- TODO diff
    -- TODO show extmarks in buffer where request originated
end

function M.setup()
    vim.keymap.set("n", "<leader>p", M.show_prediction, { desc = "show prediction" })
end

return M
