local messages = require('devtools.messages')
local WindowController0Indexed = require('zeta.predicts.WindowController')
local WindowWatcher = require('zeta.predicts.WindowWatcher')
local PredictionRequest = require('zeta.predicts.PredictionRequest')
local Displayer = require('zeta.predicts.Displayer')
local ExcerptHighlighter = require('zeta.predicts.ExcerptHighlighter')
local tags = require('zeta.helpers.tags')
local logs = require('zeta.helpers.logs')

local M = {}

--- Manage watcher PER buffer
--- now that all events are per buffer, it won't be a problem to have multiple watchers
--- they won't fire except in the current buffer b/c all events are tied to a buffer local autocmd
---@type table<number, WindowWatcher> # map buffer_number -> watcher
local watchers_by_buffer_number = {}
local toggle_highlighting = false

function keymap_fake_prediction()
    local window = WindowController0Indexed:new_from_current_window()

    local row = window:get_cursor_row()
    -- take 10 lines after cursor
    local lines = window:buffer():get_lines(row, row + 10)

    -- * setup prediction to delete 5th line
    -- skip 5th line
    local modifed_lines = vim.iter(lines):enumerate():map(function(i, line)
        return i == 5 and {} or line
    end):flatten():totable()
    -- messages.append("modifed_lines: ")
    -- messages.append(inspect.inspect(modifed_lines, { pretty = true }))

    -- wrap editable region in both
    -- FYI not inserting cursor position b/c no model is involved (so its just stripped out)
    tags.wrap_editable_tags(lines)
    tags.wrap_editable_tags(modifed_lines)

    -- FYI practice here
    -- 1
    -- 2
    -- 3
    -- 4
    -- 5
    -- 6
    -- 7
    -- 8
    -- 9
    -- 10
    -- 11
    -- 12
    -- 13
    -- 14
    -- 15

    local fake_response_body_raw = vim.json.encode({
        output_excerpt = table.concat(modifed_lines, '\n'),
        -- request_id = "foo",
    })
    -- messages.header("fake_response")
    -- messages.append(fake_response_body_raw)

    local fake_request_body      = {
        input_excerpt = table.concat(lines, '\n'),
    }
    -- messages.header("fake_request")
    -- messages.append(fake_request_body)

    -- FYI previuos seam for two different fake examples

    local fake_details           = {
        body = fake_request_body,

        -- make up a position for now using cursor in current file, doesn't matter what that file has in it
        editable_start_line = row,
        editable_end_line = row + 10, -- right now this is not used
    }
    local fake_request           = PredictionRequest:new_fake_request(window, fake_details)

    -- TODO do I need this fake watcher? if I keep reworking, I bet this falls away
    local _watcher_fake          = {
        paused = false,
        window = window,
        unwatch = function() end
    }
    Displayer:new(_watcher_fake)
        :on_response(fake_request, fake_response_body_raw)
end


---@param window WindowController0Indexed
local function trigger_prediction(window)
    -- messages.append("requesting...")

    local current_request = PredictionRequest:new(window)

    current_request:send(function(_request, stdout)
        local watcher = watchers_by_buffer_number[window:buffer().buffer_number]
        assert(watcher ~= nil, 'watcher should not be nil')

        Displayer:new(watcher)
            :on_response(_request, stdout)
    end)
end

local function immediate_on_cursor_moved(window)
    local highlighter = ExcerptHighlighter:new(window:buffer().buffer_number)
    if not toggle_highlighting then
        highlighter:clear()
        return
    end

    -- FYI this is not for real predictions so do not set it as prediction request
    local request = PredictionRequest:new(window)
    local details = request.details

    highlighter:highlight_lines(details)
end

function M.ensure_watcher_stopped(buffer_number)
    logs.trace('stopping watcher for buffer: ' .. tostring(buffer_number))
    local watcher = watchers_by_buffer_number[buffer_number]
    if watcher then
        watcher:unwatch()
        watchers_by_buffer_number[buffer_number] = nil
    end
end

function M.start_watcher(buffer_number)
    if WindowWatcher.not_supported_buffer(buffer_number) then
        M.ensure_watcher_stopped(buffer_number)
        return
    end
    -- use this to check if any buffers are monitored that I don't want to support
    -- logs.trace('starting watcher for buffer: ' .. tostring(buffer_number) .. ' for filetype: ' .. vim.bo[buffer_number].filetype)

    local watcher = watchers_by_buffer_number[buffer_number]
    if watcher ~= nil then
        -- don't re-register, could cause dropped events
        -- logs.trace("already watching")
        return
    end

    local window_id = vim.api.nvim_get_current_win()
    -- detect treesitter upfront (once)
    watcher = WindowWatcher:new(window_id, buffer_number)
    watchers_by_buffer_number[buffer_number] = watcher
    -- messages.append("starting watcher: " .. tostring(watcher.window:buffer():file_name()))
    watcher:watch(
        trigger_prediction,
        immediate_on_cursor_moved
    )

    M.register_buffer_keymaps_always_available(buffer_number)
end

function M.setup_events()
    local augroup_name = 'zeta-buffer-monitors'
    vim.api.nvim_create_augroup(augroup_name, { clear = true })

    vim.api.nvim_create_autocmd('FileType', {
        group = augroup_name,
        callback = function(args)
            -- logs.trace("file type changed: " .. vim.inspect(args))
            M.start_watcher(args.buf)
        end,
    })

    -- PRN use WinEnter (change window event), plus when first loading should trigger for current window (since that's not a change window event)
    vim.api.nvim_create_autocmd({ 'BufEnter' }, {
        group = augroup_name,
        callback = function(args)
            logs.trace('buffer enter: ' .. tostring(args.buf) .. ' - filename: ' .. vim.api.nvim_buf_get_name(args.buf))
            M.start_watcher(args.buf)
        end
    })

    vim.api.nvim_create_autocmd({ 'BufLeave' }, {
        group = augroup_name,
        callback = function(args)
            logs.trace('buffer leave: ' .. tostring(args.buf) .. ' - filename: ' .. vim.api.nvim_buf_get_name(args.buf))
            M.ensure_watcher_stopped(args.buf)
            M.unregister_buffer_keymaps_always_available()
        end,
    })
end

function M.register_buffer_keymaps_always_available(buffer_number)
    local function keymap_trigger_prediction()
        -- FYI could take args.bufnr too for buffer_number
        local watcher = watchers_by_buffer_number[buffer_number]
        if not watcher or not watcher.window then
            logs.trace('No watcher for current window')
            return
        end
        -- FYI this is real deal so you have to have full watcher
        trigger_prediction(watcher.window)
    end
    vim.keymap.set('n', '<leader>p', keymap_trigger_prediction, { buffer = true })

    vim.keymap.set('n', '<leader>pf', keymap_fake_prediction, { buffer = true })

    local function keymap_toggle_highlight_excerpt_under_cursor()
        -- FYI could take args.bufnr too for buffer_number
        local watcher = watchers_by_buffer_number[buffer_number]
        if not watcher or not watcher.window then
            messages.append('Cannot toggle highlighting, no watcher.window')
            return
        end
        toggle_highlighting = not toggle_highlighting
        immediate_on_cursor_moved(watcher.window)
    end
    vim.keymap.set('n', '<leader>ph', keymap_toggle_highlight_excerpt_under_cursor, { buffer = true })
end

function M.unregister_buffer_keymaps_always_available()
    -- silent! shuts up the BS about keymap not found... since there is no good way to check if it exists
    --    no vim.keymap.get()... no arg to vim.keymap.del() that tells it to STFU if not found
    --    vim.api.nvim_buf_get_keymap() returns leader as ' ' (not the <leader> slug).. HOT MESS
    --    so just delete and don't care
    --
    -- for vimscript use silent!
    --
    -- OR, in lua, use pcall


    -- I like the compressed nature of vimscript here...
    -- FYI if this is alot of overhead, go back to a few global keymaps (p/pf/ph), then the rest are only when prediction is displayed
    vim.cmd([[
      silent! nunmap <buffer> <leader>p
      silent! nunmap <buffer> <leader>pf
      silent! nunmap <buffer> <leader>ph
    ]])
    -- by the way can test with:
    --   =vim.fn.bufnr() -- get bufnr if wanna test when in another buffer
    --   =vim.api.nvim_buf_get_keymap(2, "i") -- or use 0 for current buffer
end

function M.setup()
    M.setup_events()
end

return M
