local parser = require("zeta.helpers.tags")
local files = require("zeta.helpers.files")
local combined = require("zeta.diff.combined")
local tags = require("zeta.helpers.tags")
local extmarks = require("zeta.diff.extmarks")
local dump = require("devtools.messages")
local inspect = require("devtools.inspect")

local M = {}
function M.get_prediction_request()
    local bufnr = vim.api.nvim_get_current_buf()


    -- step one, take the whole enchilada!
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    local cursor_pos = vim.api.nvim_win_get_cursor(0)
    dump.header("cursor_pos:")
    dump.append(cursor_pos)

    -- insert cursor position tag
    local editable = tags.adorn_editable_region(lines, cursor_pos[1], cursor_pos[2])
    dump.header("editable:")
    dump.append(inspect(editable))

    local editable_text = table.concat(editable, "\n")
    dump.header("editable_text:")
    dump.append(editable_text)

    -- TODO get real file content, and the rest is ready to go!
    -- TODO later, get editable vs surrounding context
    -- TODO handle start of file tag
    -- TODO track position of start of region so you can align it when the response comes back
    --   put into the request object (not the body) so you can use it in response handler
    --
    -- use treesitter (if available), otherwise fallback to line ranges

    -- local body = files.read_example_json("01_request.json")
    local body = {
        input_excerpt = editable_text,
        -- input_events
        -- outline
    }
    dump.header("body:")
    dump.append(inspect(body))

    return {
        bufnr = bufnr,
        body = body,
        -- body = {
        --     input_excerpt = "",
        --     -- input_events
        --     -- outline
        -- }
        excerpt_start_line_0based = 0,
        excerpt_start_column_0based = 0,
        -- excerpt_end_line = #lines,
        -- ...
        -- editable start/end too, whatever is needed...
        -- ...save it so you don't to reverse engineer it
    }
end

local function try_use_prediction(prediction_request, response_body_stdout)
    dump.ensure_open()

    local decoded = vim.fn.json_decode(response_body_stdout)
    dump.header("response_body_stdout:")
    dump.append(inspect(decoded))
    assert(decoded ~= nil, "decoded reponse body should not be nil")
    local rewritten = decoded.output_excerpt
    if rewritten == nil then
        dump.header("output_excerpt is nil, aborting...")
        return
    end

    local original = prediction_request.body.input_excerpt
    -- dump.header("input_excerpt:")
    -- dump.append(original)
    -- dump.header("output_excerpt:")
    -- dump.append(rewritten)

    original_editable = parser.get_editable_region(original) or ""
    -- PRN use cursor position? i.e. check if cursor has moved since prediction requested (might not need this actually)
    -- cursor_position = parser.get_position_of_user_cursor(original) or 0
    -- dump.header("cursor_position:", cursor_position)
    original_editable = parser.strip_user_cursor_tag(original_editable)

    rewritten_editable = parser.get_editable_region(rewritten) or ""

    local diff = combined.combined_diff(original_editable, rewritten_editable)
    -- dump.header("diff:")
    -- dump.append(inspect(diff))

    local bufnr, _window_id = dump.get_ids()
    extmarks.extmarks_for(diff, bufnr, _window_id)
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
    dump.ensure_open()

    -- dump.header("prediction_request:")
    -- dump.append(prediction_request.body.input_excerpt)
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

        dump.header("curl command")
        dump.append(inspect(command, { pretty = true }))

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
                --             dump.header("STDOUT error:" .. err)
                --         end
                --         dump.header("STDOUT data:" .. (data or ""))
                --     end)
                -- end,
                -- stderr = function(err, data)
                --     vim.schedule(function()
                --         if err ~= nil then
                --             dump.header("STDERR error:" .. err)
                --         end
                --         dump.header("STDERR data:" .. (data or ""))
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
                dump.header("curl on_exit:  " .. inspect(result))
            end
            -- if result.stderr ~= "" then
            --     dump.header("STDERR:", result.stderr)
            -- end
            if result.stdout ~= "" then
                dump.header("STDOUT:", result.stdout)
                try_use_prediction(prediction_request, result.stdout)
            end
        end)
    end

    local ok, err = pcall(make_request)
    if not ok then
        -- this happens when command (curl) is not found
        dump.header("prediction request failed immediately:")
        dump.append(inspect(err))
    end
end

function M.setup()
    vim.keymap.set("n", "<leader>p", M.show_prediction, { desc = "show prediction" })
    vim.keymap.set("n", "<leader>pf", fake_response, { desc = "bypass request to test prediction response handling" })
end

return M
