local parser = require("zeta.helpers.tags")
local files = require("zeta.helpers.files")
local combined = require("zeta.diff.combined")
local tags = require("zeta.helpers.tags")
local extmarks = require("zeta.diff.extmarks")
local messages = require("devtools.messages")
local inspect = require("devtools.inspect")
local WindowController0Based = require("zeta.predicts.window")

local M = {}
function M.get_prediction_request()
    local window = WindowController0Based:new_from_current_window()
    local buffer = window:buffer()

    local bufnr = buffer.buffer_number

    -- step one, take the whole enchilada!
    local all_lines = buffer:get_all_lines()

    local row, col = window:get_cursor_position()

    -- insert cursor position tag
    -- TODOw make adorn 0 based for row too
    local editable = tags.adorn_editable_region(all_lines, row + 1, col)
    messages.header("editable:")
    messages.append(inspect(editable))

    local editable_text = table.concat(editable, "\n")
    messages.header("editable_text:")
    messages.append(editable_text)

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
    messages.header("body:")
    messages.append(inspect(body))

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
    messages.ensure_open()

    local decoded = vim.fn.json_decode(response_body_stdout)
    messages.header("response_body_stdout:")
    messages.append(inspect(decoded))
    assert(decoded ~= nil, "decoded reponse body should not be nil")
    local rewritten = decoded.output_excerpt
    if rewritten == nil then
        messages.header("output_excerpt is nil, aborting...")
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

    local bufnr, _window_id = messages.get_ids()
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
    messages.ensure_open()
    -- TODOw
    do return end

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

        messages.header("curl command")
        messages.append(inspect(command, { pretty = true }))

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
                messages.header("curl on_exit:  " .. inspect(result))
            end
            -- if result.stderr ~= "" then
            --     dump.header("STDERR:", result.stderr)
            -- end
            if result.stdout ~= "" then
                messages.header("STDOUT:", result.stdout)
                try_use_prediction(prediction_request, result.stdout)
            end
        end)
    end

    local ok, err = pcall(make_request)
    if not ok then
        -- this happens when command (curl) is not found
        messages.header("prediction request failed immediately:")
        messages.append(inspect(err))
    end
end

function M.setup_trigger_on_editing_buffer()
    local ns = vim.api.nvim_create_namespace("zeta-prediction")
    local mark_id = 10
    local which = false

    vim.api.nvim_create_autocmd("InsertLeave", {
        pattern = "*",
        callback = function()
            -- vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
        end,
    })

    vim.api.nvim_create_autocmd("CursorMoved", {
        pattern = "*",
        callback = function()
            local window = WindowController0Based:new_from_current_window()

            -- vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)

            local row_0b = window:get_cursor_row()

            local mark = vim.api.nvim_buf_get_extmark_by_id(0, ns, mark_id, {})
            if mark ~= nil then
                local mark_row_0b = mark[1]
                local mark_col_0b = mark[2]
                if mark_row_0b == row_0b then -- and mark_col_0b == col_0b then
                    return
                end
            end

            which = not which
            -- PRN find a way to test how much lag is added by clear/add every time, vs not
            --   when line no change (left/right movement)
            --   OR, when line is changing
            --   TODO also, cache the last position so you don't have to lookup the mark (that's extra overhead)
            --     doubles the operations to change it and I think I can feel some of the difference when typing
            -- add if not there, or if cursor moved to a new line
            vim.api.nvim_buf_set_extmark(0, ns, row_0b, 0, {
                id = mark_id,
                -- virt_text = { { "prediction", "Comment" } },
                -- virt_text_pos = "overlay",
                sign_text = which and "*" or "-",
                sign_hl_group = "DiffAdd",
                -- hl_group = "DiffAdd",
                -- hl_mode = "combine",
            })
        end,
    })

    vim.api.nvim_create_autocmd("CursorMovedI", {
        -- PRN also trigger on TextChangedI? => merge signals into one stream>?
        pattern = "*",
        callback = function()
            local window = WindowController0Based:new_from_current_window()

            -- TODO cancel outstanding request(s)
            -- TODO start new request (might include a slight delay too,
            --   consider that as part of the cancelable request)

            -- vim.api.nvim_buf_clear_namespace(0, ns, 0, -1)
            local row_0b = window:get_cursor_row()

            which = not which
            vim.api.nvim_buf_set_extmark(0, ns, row_0b, 0, {
                id = mark_id,
                -- virt_text = { { "prediction", "Comment" } },
                -- virt_text_pos = "overlay",
                sign_text = which and "*" or "-",
                sign_hl_group = "DiffDelete",
                -- hl_mode = "combine",
                -- hl_group = "DiffRemove",
                -- hl_eol = true,
            })
            --
            -- messages.clear()
            --
            -- messages.header("moved")
            -- local node = vim.treesitter.get_node() -- current buffer
            -- assert(node ~= nil)
            -- -- local text = vim.treesitter.get_node_text(node, 0)
            --
            -- local parent = node:parent()
            -- assert(parent ~= nil)
            -- local text = vim.treesitter.get_node_text(parent, 0)
            -- messages.append(text)
        end
    })
end

function M.setup()
    vim.keymap.set("n", "<leader>p", M.show_prediction, { desc = "show prediction" })
    vim.keymap.set("n", "<leader>pf", fake_response, { desc = "bypass request to test prediction response handling" })

    M.setup_trigger_on_editing_buffer()
end

return M
