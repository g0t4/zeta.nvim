local files = require('zeta.helpers.files')
local messages = require('devtools.messages')
local inspect = require('devtools.inspect')
local WindowController0Indexed = require('zeta.predicts.WindowController')
local WindowWatcher = require('zeta.predicts.WindowWatcher')
local PredictionRequest = require('zeta.predicts.PredictionRequest')
local Displayer = require('zeta.predicts.Displayer')
local Accepter = require('zeta.predicts.Accepter')
local ExcerptHighlighter = require('zeta.predicts.ExcerptHighlighter')
local tags = require('zeta.helpers.tags')

local M = {}

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
local toggle_highlighting = false

---@param window WindowController0Indexed
---@param _displayer Displayer
function display_fake_response(window, _displayer)
    -- FYI not using watcher.window b/c I want this to work even when I disabled the watcher event handlers

    local fake_stdout = files.read_example('01_response.json')
    local fake_body   = files.read_example_json('01_request.json')
    display_fake_response_inner(window, _displayer, fake_body, fake_stdout)
end

---@param window WindowController0Indexed
---@param _displayer Displayer
function display_fake_response_inner(window, _displayer, fake_request_body, fake_response_body)
    local row          = window:get_cursor_row()
    local fake_details = {
        body = fake_request_body,

        -- make up a position for now using cursor in current file, doesn't matter what that file has in it
        editable_start_line = row,
        editable_end_line = row + 10, -- right now this is not used
    }
    local fake_request = PredictionRequest:new_fake_request(window, fake_details)
    _displayer:on_response(fake_request, fake_response_body)
end

---@param window WindowController0Indexed
---@param _displayer Displayer
function display_fake_prediction_del_5th_line_after_cursor(window, _displayer)
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

    local fake_request_body = {
        input_excerpt = table.concat(lines, '\n'),
    }
    -- messages.header("fake_request")
    -- messages.append(fake_request_body)

    display_fake_response_inner(window, _displayer, fake_request_body, fake_response_body_raw)
end

---@param window WindowController0Indexed
local function cancel_current_request(window)
    messages.append('cancelling...')

    if displayer ~= nil then
        displayer:reject()
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
    current_request = PredictionRequest:new(window)

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
    local request = PredictionRequest:new(window)
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
    watcher = WindowWatcher:new(window_id, buffer_number, 'zeta-prediction')
    -- messages.append("starting watcher: " .. tostring(watcher.window:buffer():file_name()))
    watcher:watch(
        trigger_prediction,
        cancel_current_request,
        immediate_on_cursor_moved
    )
    displayer = Displayer:new(watcher)
end
function M.setup_events()
    local augroup_name = 'zeta-buffer-monitors'
    vim.api.nvim_create_augroup(augroup_name, { clear = true })

    vim.api.nvim_create_autocmd('FileType', {
        group = augroup_name,
        callback = function(args)
            -- messages.append("file type changed: " .. vim.inspect(args))
            M.start_watcher(args.buf)
        end,
    })

    -- PRN use WinEnter (change window event), plus when first loading should trigger for current window (since that's not a change window event)
    vim.api.nvim_create_autocmd({ 'BufEnter' }, {
        group = augroup_name,
        callback = function(args)
            -- messages.append("buffer enter: " .. args.buf)
            M.start_watcher(args.buf)
            M.register_keymaps()
        end
    })

    vim.api.nvim_create_autocmd({ 'BufLeave' }, {
        group = augroup_name,
        callback = function()
            M.ensure_watcher_stopped()
            M.unregister_keymaps()
        end,
    })
end

function M.register_keymaps()
    local function keymap_trigger_prediction()
        if not watcher or not watcher.window then
            messages.append('No watcher for current window')
            return
        end
        -- FYI this is real deal so you have to have full watcher
        trigger_prediction(watcher.window)
    end
    vim.keymap.set('n', '<leader>p', keymap_trigger_prediction, { buffer = true })

    local function keymap_fake_prediction()
        -- this should always work, using the current window/buffer (regardless of type) b/c its a fake request/response
        -- FYI once this is activated, I can use other keymaps to accept/cancel/highlight/etc
        watcher   = {
            paused = false,
            window = WindowController0Indexed:new_from_current_window(),
            unwatch = function() end
        }
        -- set here so we can use with accepter
        displayer = Displayer:new(watcher)
        -- display_fake_response(watcher.window, displayer)
        display_fake_prediction_del_5th_line_after_cursor(watcher.window, displayer)
    end
    vim.keymap.set('n', '<leader>pf', keymap_fake_prediction, { buffer = true })

    local function keymap_toggle_highlight_excerpt_under_cursor()
        if not watcher or not watcher.window then
            messages.append('Cannot toggle highlighting, no watcher.window')
            return
        end
        toggle_highlighting = not toggle_highlighting
        immediate_on_cursor_moved(watcher.window)
    end
    vim.keymap.set('n', '<leader>ph', keymap_toggle_highlight_excerpt_under_cursor, { buffer = true })

    -- TODO move accept/reject to add/remove when show/accept/reject prediction only
    function keymap_accept_prediction()
        if not displayer or not watcher or not watcher.window then
            messages.append('No predictions to accept... no displayer, watcher.window')
            return
        end
        local accepter = Accepter:new(watcher.window)
        accepter:accept(displayer)
    end
    -- in insert mode - alt+tab to accept, or <C-o><leader>pa
    -- by the way n mode only has pa/pc for testing the fake prediction (otherwise you'd always be in insert mode, well, theoretically)
    vim.keymap.set('n', '<leader>pa', keymap_accept_prediction, { desc = 'accept prediction' })
    vim.keymap.set({ 'i', 'n' }, '<M-Tab>', keymap_accept_prediction, { buffer = true })

    function keymap_reject_prediction()
        if not watcher or not watcher.window then
            messages.append('No predictions to cancel, no watcher.window')
            return
        end
        cancel_current_request(watcher.window)
    end
    -- in insert mode - alt+esc to cancel, or <C-o><leader>pc
    vim.keymap.set('n', '<leader>pc', keymap_reject_prediction, { desc = 'reject prediction' })
    vim.keymap.set({ 'i', 'n' }, '<M-Esc>', keymap_reject_prediction, { buffer = true })
end

function M.unregister_keymaps()
    -- silent! shuts up the BS about keymap not found... since there is no good way to check if it exists
    --    no vim.keymap.get()... no arg to vim.keymap.del() that tells it to STFU if not found
    --    vim.api.nvim_buf_get_keymap() returns leader as ' ' (not the <leader> slug).. HOT MESS
    --    so just delete and don't care
    --
    -- for vimscript use silent!
    --
    -- OR, in lua, use pcall

    -- I like the compressed nature of vimscript here...
    vim.cmd([[
      silent! nunmap <buffer> <leader>p
      silent! nunmap <buffer> <leader>pf
      silent! nunmap <buffer> <leader>ph
      silent! nunmap <buffer> <leader>pa
      silent! nunmap <buffer> <leader>pc
      silent! nunmap <buffer> <M-Tab>
      silent! nunmap <buffer> <M-Esc>

      silent! iunmap <buffer> <M-Tab>
      silent! iunmap <buffer> <M-Esc>
    ]])
    -- by the way can test with:
    --   =vim.fn.bufnr() -- get bufnr if wanna test when in another buffer
    --   =vim.api.nvim_buf_get_keymap(2, "i") -- or use 0 for current buffer
end

function M.setup()
    M.setup_events()
end

return M
