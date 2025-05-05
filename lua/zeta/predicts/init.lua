local files = require("zeta.helpers.files")
local messages = require("devtools.messages")
local inspect = require("devtools.inspect")
local WindowController0Indexed = require("zeta.predicts.WindowController")
local WindowWatcher = require("zeta.predicts.WindowWatcher")
local PredictionRequest = require("zeta.predicts.PredictionRequest")
local Displayer = require("zeta.predicts.Displayer")
local Accepter = require("zeta.predicts.Accepter")
local ExtmarksSet = require("zeta.predicts.ExtmarksSet")


local M = {}

---@param window WindowController0Indexed
---@param displayer Displayer
local function display_fake_response(window, displayer)
    -- FYI not using watcher.window b/c I want this to work even when I disabled the watcher event handlers

    local fake_stdout  = files.read_example("01_response.json")
    local fake_body    = files.read_example_json("01_request.json")
    local row          = window:get_cursor_row()
    local fake_details = {
        body = fake_body,

        -- make up a position for now using cursor in current file, doesn't matter what that file has in it
        editable_start_line = row,
        editable_end_line = row + 10, -- right now this is not used
    }
    local fake_request = PredictionRequest:new_fake_request(window, fake_details)
    displayer:on_response(fake_request, fake_stdout)
end

-- FYI for now the code is all designed to have ONE watcher at a time
--   only modify this if I truly need multiple watchers (across windows)
--   but that's not the current design
--   would have to have autocmd group that is segmented by window id too
---@type WindowWatcher|nil
local watcher = nil
---@type Displayer|nil
local displayer = nil
---@type PredictionRequest|nil
local current_request = nil

---@param window WindowController0Indexed
local function cancel_current_request(window)
    messages.append("cancelling...")

    if displayer ~= nil then
        displayer:clear()
    end

    if current_request == nil then
        return
    end
    current_request:cancel()
    current_request = nil
end

---@param window WindowController0Indexed
local function trigger_prediction(window, select_only)
    select_only = select_only or false
    messages.append("requesting...")

    -- PRN... a displayer is tied to a request... hrm...
    local request = PredictionRequest:new(window)

    if select_only then
        local hl_editable = "zeta-excerpt-editable"
        local hl_context = "zeta-excerpt-context"
        vim.api.nvim_set_hl(0, hl_editable, { bg = "green" })
        vim.api.nvim_set_hl(0, hl_context, { bg = "blue" })
        local zeta_excerpts_ns_id = vim.api.nvim_create_namespace("zeta-excerpts")
        local editable_mark_id = 20
        local ctx_before_mark_id = 21
        local ctx_after_mark_id = 22
        local excerpt_marks = ExtmarksSet:new(window:buffer().buffer_number, zeta_excerpts_ns_id)
        excerpt_marks:highlight_lines({
            id = editable_mark_id,
            hl_group = hl_editable,
            start_line = request.details.editable_start_line,
            end_line = request.details.editable_end_line,
        })
        -- * highlight the context before/after
        local context_before_start_line = request.details.editable_start_line - 3
        excerpt_marks:highlight_lines({
            id = ctx_before_mark_id,
            hl_group = hl_context,
            start_line = context_before_start_line,
            end_line = request.details.editable_start_line,
        })
        local context_after_end_line = request.details.editable_end_line + 3
        excerpt_marks:highlight_lines({
            id = ctx_after_mark_id,
            hl_group = hl_context,
            start_line = request.details.editable_end_line,
            end_line = context_after_end_line,
        })
        -- TODO what if I had a keymap that would allow me to select one off context for next predictions?
        -- or that allowed setting to go one more level past current func ... to somehoww conditionally expand or contract the selected func/block?
        -- can I have a keycombo that enables showing the context as I type! (not selecting cuz that would mess up the context)
        --   but toggle context on/off! and then controls to alter the selection with live feedback!
        return
    end

    request:send(function(_request, stdout)
        displayer:on_response(_request, stdout)
        -- clear request once it's done:
        current_request = nil
    end)
end

function M.setup_events()
    -- PRN use WinEnter (change window event), plus when first loading should trigger for current window (since that's not a change window event)
    vim.api.nvim_create_autocmd({ "BufEnter" }, {
        callback = function(args)
            local window_id = vim.api.nvim_get_current_win()
            local has_ts = pcall(vim.treesitter.get_parser, args.buf)
            if has_ts then
                watcher = WindowWatcher:new(window_id, args.buf, "zeta-prediction")
                watcher:watch(trigger_prediction, cancel_current_request)
                displayer = Displayer:new(watcher.window)
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
        if not watcher then
            messages.append("No watcher for current window")
            return
        end
        -- FYI requires tree-sitter even when manually triggered, so use the watcher.window
        trigger_prediction(watcher.window)
    end, { desc = "show prediction" })

    vim.keymap.set("n", "<leader>pf", function()
        -- this should always work, using the current window/buffer (regardless of type) b/c its a fake request/response
        local window = WindowController0Indexed:new_from_current_window()
        -- set here so we can use with accepter
        displayer    = Displayer:new(window)
        display_fake_response(window, displayer)
    end, { desc = "demo fake request/response" })
    vim.keymap.set("n", "<leader>ps", function()
        -- visually display the current excerpt
        if not watcher then
            messages.append("No watcher for current window")
            return
        end
        trigger_prediction(watcher.window, true)
    end)

    vim.keymap.set("n", "<leader>pa", function()
        if not displayer then
            messages.append("No displayer for current window")
            return
        end
        local accepter = Accepter:new(watcher.window)
        accepter:accept(displayer)
    end, { desc = "accept prediction" })

    vim.keymap.set("n", "<leader>pc", function()
        if not watcher then
            messages.append("No watcher for current window")
            return
        end
        cancel_current_request(watcher.window)
    end, { desc = "reject prediction" })

    M.setup_events()
end

return M
