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
        displayer = nil
    end

    if current_request == nil then
        return
    end
    current_request:cancel()
    current_request = nil
end

---@param window WindowController0Indexed
local function trigger_prediction(window)
    -- messages.append("requesting...")

    -- PRN... a displayer is tied to a request... hrm...
    current_request = PredictionRequest:new(window, has_treesitter)

    current_request:send(function(_request, stdout)
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

    -- FYI this is not for real predictions so do not set it as prediction request
    local request = PredictionRequest:new(window, has_treesitter)
    local details = request.details

    highlighter:highlight_lines(details)
end

function M.ensure_watcher_stopped()
    if watcher then
        watcher:unwatch()
        watcher = nil
    end
end

function M.start_watcher(buffer_number)
    if WindowWatcher.not_supported_buffer(buffer_number) then
        M.ensure_watcher_stopped()
        return
    end
    if watcher ~= nil then
        -- don't re-register, could cause dropped events
        -- messages.append("already watching")
        return
    end

    local window_id = vim.api.nvim_get_current_win()
    -- detect treesitter upfront (once)
    has_treesitter = pcall(vim.treesitter.get_parser, buffer_number)
    watcher = WindowWatcher:new(window_id, buffer_number, "zeta-prediction")
    -- messages.append("starting watcher: " .. tostring(watcher.window:buffer():file_name()))
    watcher:watch(
        trigger_prediction,
        cancel_current_request,
        immediate_on_cursor_moved
    )
    displayer = Displayer:new(watcher.window)
end

function M.setup_events()
    local augroup_name = "zeta-buffer-monitors"
    vim.api.nvim_create_augroup(augroup_name, { clear = true })

    vim.api.nvim_create_autocmd("FileType", {
        group = augroup_name,
        callback = function(args)
            -- messages.append("file type changed: " .. vim.inspect(args))
            M.start_watcher(args.buf)
        end,
    })

    -- PRN use WinEnter (change window event), plus when first loading should trigger for current window (since that's not a change window event)
    vim.api.nvim_create_autocmd({ "BufEnter" }, {
        group = augroup_name,
        callback = function(args)
            -- messages.append("buffer enter: " .. args.buf)
            M.start_watcher(args.buf)
        end
    })

    vim.api.nvim_create_autocmd({ "BufLeave" }, {
        group = augroup_name,
        callback = M.ensure_watcher_stopped,
    })
end

function M.setup()
    -- * real prediction, on-demand
    vim.keymap.set("n", "<leader>p", function()
        if not watcher or not watcher.window then
            messages.append("No watcher for current window")
            return
        end
        -- FYI this is real deal so you have to have full watcher
        trigger_prediction(watcher.window)
    end, { desc = "show prediction" })

    -- * fake prediction
    vim.keymap.set("n", "<leader>pf", function()
        -- this should always work, using the current window/buffer (regardless of type) b/c its a fake request/response
        -- FYI once this is activated, I can use other keymaps to accept/cancel/highlight/etc
        watcher   = {
            window = WindowController0Indexed:new_from_current_window()
        }
        -- set here so we can use with accepter
        displayer = Displayer:new(watcher.window)
        display_fake_response(watcher.window, displayer)
    end, { desc = "demo fake request/response" })

    -- * toggle [h]ighlighting excerpt as cursor moves
    vim.keymap.set("n", "<leader>ph", function()
        if not watcher or not watcher.window then
            messages.append("Cannot toggle highlighting, no watcher.window")
            return
        end
        toggle_highlighting = not toggle_highlighting
        immediate_on_cursor_moved(watcher.window)
    end)

    -- * accept prediction
    function accept()
        if not displayer or not watcher or not watcher.window then
            messages.append("No predictions to accept... no displayer, watcher.window")
            return
        end
        local accepter = Accepter:new(watcher.window)
        accepter:accept(displayer)
    end

    -- in insert mode - alt+tab to accept, or <C-o><leader>pa
    vim.keymap.set("n", "<leader>pa", accept, { desc = "accept prediction" })
    vim.keymap.set({ "i", "n" }, "<M-Tab>", accept, { desc = "accept prediction" })

    -- * cancel prediction
    function reject()
        if not watcher or not watcher.window then
            messages.append("No predictions to cancel, no watcher.window")
            return
        end
        cancel_current_request(watcher.window)
    end

    -- in insert mode - alt+esc to cancel, or <C-o><leader>pc
    vim.keymap.set("n", "<leader>pc", reject, { desc = "reject prediction" })
    vim.keymap.set({ "i", "n" }, "<M-Esc>", reject, { desc = "reject prediction" })

    -- require("zeta.predicts.miscTsGotoMaps").setup()

    M.setup_events()
end

return M
