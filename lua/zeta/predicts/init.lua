local parser = require("zeta.helpers.tags")
local files = require("zeta.helpers.files")
local combined = require("zeta.diff.combined")
local extmarks = require("zeta.diff.extmarks")
local messages = require("devtools.messages")
local inspect = require("devtools.inspect")
local WindowController0Indexed = require("zeta.predicts.WindowController")
local ExcerptSelector = require("zeta.predicts.ExcerptSelector")
local WindowWatcher = require("zeta.predicts.WindowWatcher")
local ExtmarksSet = require("zeta.predicts.ExtmarksSet")
local PredictionRequest = require("zeta.predicts.PredictionRequest")

local M = {}

local select_excerpt_mark = 11
local prediction_namespace = vim.api.nvim_create_namespace("zeta-prediction")
local function on_response(prediction_request, response_body_stdout)
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
    -- TODO this is more about the displayer side of the equation
    local fake_stdout  = files.read_example("01_response.json")
    local fake_request = {
        bufnr = 0,
        body = files.read_example_json("01_request.json"),
        -- TODO others
    }
    on_response(fake_request, fake_stdout)
end


local current_request = nil
---@param window WindowController0Indexed
local function cancel_current_request(window)
    messages.append("cancelling...")
    local prediction_marks = ExtmarksSet:new(window:buffer().buffer_number, prediction_namespace)
    prediction_marks:clear_all()
    if current_request == nil then
        return
    end
    current_request:cancel()
    current_request = nil
end

---@param window WindowController0Indexed
local function trigger_prediction(window)
    local prediction_marks = ExtmarksSet:new(window:buffer().buffer_number, prediction_namespace)
    -- FYI only reason I am doing this here is to keep one instance of prediction_marks which is NOT AT ALL NECESSARY
    -- this is bleeding concerns, but it's fine

    -- -- save yourself the hassle of forgetting to enode/decode when loading test files
    local request = PredictionRequest:new(window)
    assert(type(request.details.body) == "table", "body must be a table")
    request:send(on_response)


    -- FYI even the time here to query the node structures,
    -- if you run that in parallel with your debounce
    -- will never be consequential
    -- but, might lock access to the buffer?

    messages.append("requesting...")

    local row_0b = window:get_cursor_row()

    -- PRN for marks, profile timing to optimize caching vs get vs set always
    -- PRN likewise for excerpt selection, find out if caching matters or if its fast enough
    -- - IIAC if the node is the same as the last request, that at least would be a good optimization
    --   - assuming nothing has changed in the doc? could invalidate any cache on text changed event

    local excerpt = window:get_excerpt_text_at_cursor()

    -- local row_0b = window:get_cursor_row()
    -- prediction_marks:set(gutter_mark_id, {
    --     start_line = row_0b,
    --     start_col = 0,
    --
    --     id = gutter_mark_id,
    --     -- virt_text = { { "prediction", "Comment" } },
    --     -- virt_text_pos = "overlay",
    --     sign_text = which and "*" or "-",
    --     sign_hl_group = "DiffDelete",
    --     -- hl_mode = "combine",
    --     -- hl_group = "DiffRemove",
    --     -- hl_eol = true,
    -- })
end

function M.setup_events()
    -- FYI for now the code is all designed to have ONE watcher at a time
    --   only modify this if I truly need multiple watchers (across windows)
    --   but that's not the current design
    --   would have to have autocmd group that is segmented by window id too
    local watcher = nil

    -- PRN use WinEnter (change window event), plus when first loading should trigger for current window (since that's not a change window event)
    vim.api.nvim_create_autocmd({ "BufEnter" }, {
        callback = function(args)
            local window_id = vim.api.nvim_get_current_win()
            local has_ts = pcall(vim.treesitter.get_parser, args.buf)
            if has_ts then
                messages.append("Tree-sitter is available in buffer " .. args.buf)
                watcher = WindowWatcher:new(window_id, args.buf, "zeta-prediction")
                watcher:watch(trigger_prediction, cancel_current_request)
            else
                messages.append("No Tree-sitter parser for buffer " .. args.buf)
            end
        end,
    })

    vim.api.nvim_create_autocmd({ "BufLeave" }, {
        callback = function(args)
            if watcher then
                watcher:unwatch()
                watcher = nil
            end
        end,
    })
end

function M.setup()
    vim.keymap.set("n", "<leader>p", function()
        local window = WindowController0Indexed:new_from_current_window()
        trigger_prediction(window)
    end, { desc = "show prediction" })

    vim.keymap.set("n", "<leader>pf", fake_response, { desc = "bypass request to test prediction response handling" })

    M.setup_events()
end

return M
