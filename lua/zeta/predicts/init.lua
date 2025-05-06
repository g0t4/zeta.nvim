local files = require("zeta.helpers.files")
local messages = require("devtools.messages")
local inspect = require("devtools.inspect")
local WindowController0Indexed = require("zeta.predicts.WindowController")
local WindowWatcher = require("zeta.predicts.WindowWatcher")
local PredictionRequest = require("zeta.predicts.PredictionRequest")
local Displayer = require("zeta.predicts.Displayer")
local Accepter = require("zeta.predicts.Accepter")
local ExcerptHighlighter = require("zeta.predicts.ExcerptHighlighter")


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
local has_treesitter = false

local toggle_highlighting = false

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
local function trigger_prediction(window)
    messages.append("requesting...")

    -- PRN... a displayer is tied to a request... hrm...
    local request = PredictionRequest:new(window, has_treesitter)

    request:send(function(_request, stdout)
        displayer:on_response(_request, stdout)
        -- clear request once it's done:
        current_request = nil
    end)
end

local function immediate_on_cursor_moved(window)
    local highlighter = ExcerptHighlighter:new(window:buffer().buffer_number)
    if not toggle_highlighting then
        highlighter:clear()
        return
    end

    local request = PredictionRequest:new(window, has_treesitter)
    local details = request.details

    highlighter:highlight_lines(details)
end

function M.setup_events()
    -- PRN use WinEnter (change window event), plus when first loading should trigger for current window (since that's not a change window event)
    vim.api.nvim_create_autocmd({ "BufEnter" }, {
        callback = function(args)
            local window_id = vim.api.nvim_get_current_win()
            -- detect treesitter once time, upfront, when first switch to window/buffer
            has_treesitter = pcall(vim.treesitter.get_parser, args.buf)
            if not has_treesitter then
                messages.append("FYI still need a few fixes for non-treesitter to work, aborting")
                return
            end
            watcher = WindowWatcher:new(window_id, args.buf, "zeta-prediction")
            watcher:watch(trigger_prediction,
                cancel_current_request,
                immediate_on_cursor_moved)
            displayer = Displayer:new(watcher.window)
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
    -- * real prediction, on-demand
    vim.keymap.set("n", "<leader>p", function()
        if not watcher then
            messages.append("No watcher for current window")
            return
        end
        -- FYI requires tree-sitter even when manually triggered, so use the watcher.window
        trigger_prediction(watcher.window)
    end, { desc = "show prediction" })

    -- * fake prediction
    vim.keymap.set("n", "<leader>pf", function()
        -- this should always work, using the current window/buffer (regardless of type) b/c its a fake request/response
        local window = WindowController0Indexed:new_from_current_window()
        -- set here so we can use with accepter
        displayer    = Displayer:new(window)
        display_fake_response(window, displayer)
    end, { desc = "demo fake request/response" })

    -- * toggle [h]ighlighting excerpt as cursor moves
    vim.keymap.set("n", "<leader>ph", function()
        if not watcher then
            messages.append("No watcher for current window")
            return
        end
        toggle_highlighting = not toggle_highlighting
        immediate_on_cursor_moved(watcher.window)
    end)

    -- * accept prediction
    vim.keymap.set("n", "<leader>pa", function()
        if not displayer then
            messages.append("No displayer for current window")
            return
        end
        local accepter = Accepter:new(watcher.window)
        accepter:accept(displayer)
    end, { desc = "accept prediction" })

    -- * cancel prediction
    vim.keymap.set("n", "<leader>pc", function()
        if not watcher then
            messages.append("No watcher for current window")
            return
        end
        cancel_current_request(watcher.window)
    end, { desc = "reject prediction" })

    -- require("zeta.predicts.miscTsGotoMaps").setup()

    -- TODO uncomment to enable again
    -- M.setup_events()
end

return M
