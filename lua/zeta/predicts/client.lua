local parser = require("zeta.helpers.response-parser")
local files = require("zeta.helpers.files")
local combined = require("zeta.diff.combined")
local extmarks = require("zeta.diff.extmarks")


local M = {}
function M.get_prediction_request()
    local bufnr = vim.api.nvim_get_current_buf()
    print("## bufnr:", bufnr)

    -- TODO get real file content, and the rest is ready to go!
    -- use treesitter (if available), otherwise fallback to line ranges
    -- input_excerpt
    -- mark editable region (select this first, then expand to gather all of input_excerpt)

    local body_request_01 = files.read_example_json("01_request.json")

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

local function try_use_prediction(prediction_request, response_body_stdout)
    local decoded = vim.fn.json_decode(response_body_stdout)
    BufferDumpAppend("## response_body_stdout:\n  ")
    BufferDumpAppend(vim.inspect(decoded))
    assert(decoded ~= nil, "decoded reponse body should not be nil")
    local rewritten = decoded.output_excerpt
    if rewritten == nil then
        BufferDumpAppend("## output_excerpt is nil, aborting...")
        return
    end

    local original = prediction_request.body.input_excerpt
    -- BufferDumpAppend("## input_excerpt:\n  ")
    -- BufferDumpAppend(original)
    -- BufferDumpAppend("## output_excerpt:\n  ")
    -- BufferDumpAppend(rewritten)

    original_editable = parser.get_editable(original) or ""
    rewritten_editable = parser.get_editable(rewritten) or ""

    local diff = combined.combined_diff(original_editable, rewritten_editable)
    -- BufferDumpAppend("## diff:\n  ")
    -- BufferDumpAppend(inspect(diff))

    local bufnr, _window_id = GetBufferDumpNumbers()
    extmarks.extmarks_for(diff, bufnr, _window_id)





    -- TODO diff
    -- TODO show extmarks in buffer where request originated
    -- assert(output_excerpt ~= nil, "output_excerpt should not be nil")
end

local function fake_response()
    local fake_stdout  = files.read_example("01_response.json")
    local fake_request = {
        bufnr = 0,
        body = files.read_example_json("01_request.json"),
        -- TODO others
    }
    try_use_prediction(fake_request, fake_stdout)
end

function M.show_prediction()
    local prediction_request = M.get_prediction_request()
    -- save yourself the hassle of forgetting to encode/decode when loading test files
    assert(type(prediction_request.body) == "table", "body must be a table")

    -- BufferDumpAppend("## prediction_request:\n  ")
    -- BufferDumpAppend(prediction_request.body.input_excerpt)
    -- PRN extra assertions to validate no mistakes in a special troubleshot mode?
    --   i.e. does it include editable region, cursor position, etc...

    -- PRN how can I handle errors? pcall?
    function make_request()
        local url = "http://localhost:9000/predict_edits"
        local command = {
            "curl",
            "-fsSL", -- -S is key to getting error messages (and not just silent failures! w/ non-zero exit code)
            -- keep in mind, don't want verbose output normally as it will muck up receiving response body
            -- FYI if want stream response, add --no-buffer to curl else it batches output
            "-H", "Content-Type: application/json",
            "-X", "POST",
            "-s", url,
            "-d", vim.fn.json_encode(prediction_request.body)
        }

        BufferDumpAppend("## command:\n  ")
        BufferDumpAppend(vim.inspect(command))

        local result = vim.system(command,
            {
                text = true,
                -- since I am not streaming reponse, I will leave defaults such that
                --   stdout/stderr are returned in the on_exit callback
                --   btw stdout/stderr = true by default, can set false to discard
                --
                -- stdout = function(err, data)
                --     vim.schedule(function()
                --         if err ~= nil then
                --             BufferDumpAppend("## STDOUT error:\n  " .. err)
                --         end
                --         BufferDumpAppend("## STDOUT data:\n  " .. (data or ""))
                --     end)
                -- end,
                -- stderr = function(err, data)
                --     vim.schedule(function()
                --         if err ~= nil then
                --             BufferDumpAppend("## STDERR error:\n  " .. err)
                --         end
                --         BufferDumpAppend("## STDERR data:\n  " .. (data or ""))
                --     end)
                -- end,
                -- timeout = ? seconds? ms? default is?
            },
            on_exit_curl
        )
        return result
    end

    function on_exit_curl(result)
        -- vim.SystemCompleted (code, signal, stdout, stderr)
        vim.schedule(function()
            if result.code ~= 0 then
                -- test failure with wrong URL
                BufferDumpAppend("## curl on_exit:  " .. vim.inspect(result))
            end
            -- if result.stderr ~= "" then
            --     BufferDumpAppend("## STDERR:\n  ", result.stderr)
            -- end
            if result.stdout ~= "" then
                BufferDumpAppend("## STDOUT:\n  ", result.stdout)
                try_use_prediction(prediction_request, result.stdout)
            end
        end)
    end

    local ok, err = pcall(make_request)
    if not ok then
        -- this happens when command (curl) is not found
        BufferDumpAppend("## prediction request failed immediately:\n  ")
        BufferDumpAppend(vim.inspect(err))
    end
end

function M.setup()
    vim.keymap.set("n", "<leader>p", M.show_prediction, { desc = "show prediction" })
    vim.keymap.set("n", "<leader>pf", fake_response, { desc = "bypass request to test prediction response handling" })
end

return M
