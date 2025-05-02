local files = require("zeta.helpers.files")
local M = {}
function M.get_prediction_request()
    local bufnr = vim.api.nvim_get_current_buf()
    print("## bufnr:", bufnr)

    -- TODO get real file content, and the rest is ready to go!
    -- use treesitter (if available), otherwise fallback to line ranges
    -- input_excerpt
    -- mark editable region (select this first, then expand to gather all of input_excerpt)

    local body_json_serialized = files.read_example("01_request.json")

    return {
        bufnr = bufnr,
        body = vim.fn.json_decode(body_json_serialized),
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
    local result = vim.fn.system({
        "curl",
        "-H", "Content-Type: application/json",
        "-X", "POST",
        "-s", url,
        "-d", vim.fn.json_encode(prediction_request.body)
    })
    print("## result:")
    print(result)

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
