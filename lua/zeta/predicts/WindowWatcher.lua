local WindowController0Indexed = require("zeta.predicts.WindowController")
local debounce = require("zeta.predicts.debounce")
local ExtmarksSet = require("zeta.predicts.ExtmarksSet")

--- watches events w.r.t. cursor movements, mode changes, and window changes
--- all the autocmds to support triggering implicit actions
--- this is largely a container to group the event handlers
--- and really this is a PredictionsWindowWatcher so its fine to let that bleed into this abstraction
--- ... though ideally this doesn't contain predictions logic and instead a func is passed in
---@class WindowWatcher
local WindowWatcher = {}
WindowWatcher.__index = WindowWatcher

-- theoretically could make this unique per instance, for now its global
local prediction_augroup = "zeta-prediction"
vim.api.nvim_create_augroup(prediction_augroup, { clear = true })
local prediction_namespace = vim.api.nvim_create_namespace("zeta-prediction")

function WindowWatcher:new(window_id, buffer_number)
    self = setmetatable(self, WindowWatcher)
    self.window_id = window_id
    self.buffer_number = buffer_number
    return self
end

--- @param trigger_prediction function
function WindowWatcher:watch(trigger_prediction)
    local prediction_marks = ExtmarksSet:new(self.buffer_number, prediction_namespace)
    local window = WindowController0Indexed:new(self.window_id)
    if not window:buffer().buffer_number == self.buffer_number then
        -- sanity check, should never happen
        -- the event BufEnter fires for a buffer which can be in multiple windows
        -- so, get current window right away (happens in event handler)
        -- and then here I make sure that matches
        -- FYI could use WinEnter too to get around this
        error("unexpected buffer number on current window, expected bufnr: " .. self.buffer_number
            .. " but got bufnr: " .. window:buffer().buffer_number
            .. " (window: " .. window.window_id .. ")")
        return
    end

    -- this way, when typing it's not trying to show a prediction
    -- PRN fire off the request in the background (cancel it on every key stroke)
    -- - but, DO NOT SHOW IT until the delay has elapsed...
    -- - that way you don't wait both the debounce delay + service r/t
    -- - instead these two happen in parallel
    -- - completions backends have no trouble keeping up and canceling previous requests
    local debounced_trigger = debounce(function()
        -- FYI only reason I am doing this here is to keep one instance of prediction_marks which is NOT AT ALL NECESSARY
        -- this is bleeding concerns, but it's fine
        -- TODO rename this to PredictionsWindowWatcher is fine!
        trigger_prediction(window, prediction_marks)
    end, 500)

    vim.api.nvim_create_autocmd("InsertEnter", {
        group = prediction_augroup,
        -- buffer = self.buffer_number,
        callback = debounced_trigger.call,
    })

    vim.api.nvim_create_autocmd("InsertLeave", {
        -- FYI nothing says I have to cancel it on leave... the prediction can be left visible after exit to normal mode
        --   then on re-entry to insert mode you trigger a new prediction
        -- one benefit to stop on exit is you can prevent the prediction by hitting escape as last key when typing

        group = prediction_augroup,
        -- buffer = self.buffer_number,
        callback = debounced_trigger.cancel,
    })

    vim.api.nvim_create_autocmd("CursorMovedI", {
        -- PRN also trigger on TextChangedI? => merge signals into one stream>?
        group = prediction_augroup,
        -- buffer = self.buffer_number,
        callback = debounced_trigger.call,
    })
end

function WindowWatcher:unwatch()
    -- TODO this is a hot mess... it should be tied to window not the buffer
    -- for now there's only ever one instance so w/e it works
    vim.api.nvim_clear_autocmds({
        -- buffer = self.buffer_number,
        group = prediction_augroup
    })
end

return WindowWatcher
