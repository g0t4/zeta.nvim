local WindowController0Indexed = require('zeta.predicts.WindowController')
local debounce = require('zeta.predicts.debounce')

--- watches events w.r.t. cursor movements, mode changes, and window changes
--- all the autocmds to support triggering implicit actions
--- this is largely a container to group the event handlers
--- and really this is a PredictionsWindowWatcher so its fine to let that bleed into this abstraction
--- ... though ideally this doesn't contain predictions logic and instead a func is passed in
---@class WindowWatcher
---@field window WindowController0Indexed
---@field paused boolean
---@field displayer Displayer
local WindowWatcher = {}
WindowWatcher.__index = WindowWatcher

function WindowWatcher:new(window_id, buffer_number, augroup_name)
    self = setmetatable({}, WindowWatcher)
    self.augroup_name = augroup_name
    self.window = WindowController0Indexed:new(window_id)
    self.buffer_number = buffer_number
    self.paused = false
    self.displayer = nil
    return self
end

function WindowWatcher.not_supported_buffer(buffer_number)
    local filetype = vim.bo[buffer_number].filetype

    -- FYI "" is treated as NOT supported
    --  that way when a file first opens, it won't start predictions until its filetype is set
    --  sometimes filetype is set before first BufEnter
    --  othertimes, not until after first BufEnter
    --  so we want for a filetype to register watcher
    if filetype == ''
        or filetype == 'TelescopePrompt'
        or filetype == 'TelescopeResults'
        or filetype == 'NvimTree'
        or filetype == 'DressingInput'
        or filetype == 'help'
        or filetype == 'cmp_menu'
        or filetype == 'notify'
    -- or filetype == "qf"
    -- or filetype == "lspinfo"
    then
        return true -- NOT supported
    end
    return false -- supported
end

--- @param trigger_prediction function(window: WindowController0Indexed)
--- @param immediate_on_cursor_moved function(window: WindowController0Indexed)
function WindowWatcher:watch(trigger_prediction,
                             immediate_on_cursor_moved)
    -- TODO need group per buffer?
    vim.api.nvim_create_augroup(self.augroup_name, { clear = true })

    local window = self.window
    if not window:buffer().buffer_number == self.buffer_number then
        -- sanity check, should never happen
        -- the event BufEnter fires for a buffer which can be in multiple windows
        -- so, get current window right away (happens in event handler)
        -- and then here I make sure that matches
        -- FYI could use WinEnter too to get around this
        error('unexpected buffer number on current window, expected bufnr: ' .. self.buffer_number
            .. ' but got bufnr: ' .. window:buffer().buffer_number
            .. ' (window: ' .. window.window_id .. ')')
        return
    end

    -- this way, when typing it's not trying to show a prediction
    -- PRN fire off the request in the background (cancel it on every key stroke)
    -- - but, DO NOT SHOW IT until the delay has elapsed...
    -- - that way you don't wait both the debounce delay + service r/t
    -- - instead these two happen in parallel
    -- - completions backends have no trouble keeping up and canceling previous requests
    local debounced_trigger = debounce(function()
        trigger_prediction(window)
    end, 500)

    vim.api.nvim_create_autocmd('InsertEnter', {
        group = self.augroup_name,
        -- FYI technically I don't nee the buffer filter b/c there's only ever one of these active at a time
        buffer = self.buffer_number,
        callback = function()
            -- PRN immediately trigger and don't delay?
            debounced_trigger.call()
        end,
    })
    function cancel_current_request()
        if self.displayer ~= nil then
            self.displayer:reject()
        end
    end

    vim.api.nvim_create_autocmd('InsertLeave', {
        -- FYI nothing says I have to cancel it on leave... the prediction can be left visible after exit to normal mode
        --   then on re-entry to insert mode you trigger a new prediction
        -- one benefit to stop on exit is you can prevent the prediction by hitting escape as last key when typing

        group = self.augroup_name,
        buffer = self.buffer_number,
        callback = function()
            cancel_current_request()
            debounced_trigger.cancel()
        end,
    })

    vim.api.nvim_create_autocmd('CursorMovedI', {
        -- PRN also trigger on TextChangedI? => merge signals into one stream>?
        group = self.augroup_name,
        buffer = self.buffer_number,
        callback = function()
            if self.paused then
                return
            end

            cancel_current_request()
            -- PRN differentiate between sending request and when can show prediction
            --   arguably, only latter (show prediction) needs debounced
            --     to avoid interfering iwth user typing!
            --   that said, the former (send request) could maybe have a shorter debounce intended
            --     to avoid overwhelming the backend with requests
            debounced_trigger.call()
            immediate_on_cursor_moved(window)
        end,
    })

    vim.api.nvim_create_autocmd('CursorMoved', {
        group = self.augroup_name,
        buffer = self.buffer_number,
        callback = function()
            if self.paused then
                return
            end

            -- PRN
            immediate_on_cursor_moved(window)
        end,
    })
end

function WindowWatcher:unwatch()
    -- FYI I don't need to tie event to buffer / window until I need simultaneous predictions
    vim.api.nvim_clear_autocmds({
        -- buffer = self.buffer_number,
        group = self.augroup_name
    })
    -- PRN delete instead of clear?
end

return WindowWatcher
