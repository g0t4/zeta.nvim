local files = require("zeta.helpers.files")
local messages = require("devtools.messages")
local inspect = require("devtools.inspect")
local WindowController0Indexed = require("zeta.predicts.WindowController")
local WindowWatcher = require("zeta.predicts.WindowWatcher")
local PredictionRequest = require("zeta.predicts.PredictionRequest")
local Displayer = require("zeta.predicts.Displayer")

local M = {}

local function display_fake_response()
    local window       = WindowController0Indexed:new(1)
    local displayer    = Displayer:new(window)

    local fake_stdout  = files.read_example("01_response.json")
    local fake_request = {
        body = files.read_example_json("01_request.json"),
        -- PRN params?
    }
    displayer:on_response(fake_request, fake_stdout)
end


local current_request = nil
---@param window WindowController0Indexed
local function cancel_current_request(window)
    messages.append("cancelling...")
    local displayer = Displayer:new(window)
    displayer:clear()

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
    local request = PredictionRequest:new(window)
    local displayer = Displayer:new(window)

    -- save yourself the hassle of forgetting to encode/decode when loading test files
    assert(type(request.details.body) == "table", "body must be a table")

    request:send(function(_request, stdout)
        displayer:on_response(_request, stdout)
        -- clear request once it's done:
        current_request = nil
    end)
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

    vim.keymap.set("n", "<leader>pf", display_fake_response, { desc = "bypass request to test prediction response handling" })

    -- TODO! activate on typing once fake is working!
    -- M.setup_events()
end

return M
