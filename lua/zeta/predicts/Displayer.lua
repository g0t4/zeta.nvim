local tags = require('zeta.helpers.tags')
local combined = require('zeta.diff.combined')
local messages = require('devtools.messages')
local inspect = require('devtools.inspect')
local ExtmarksSet = require('zeta.predicts.ExtmarksSet')

---@class Displayer
---@field window WindowController0Indexed
---@field marks ExtmarksSet
---@field rewritten_editable string
---@field current_request PredictionRequest
---@field current_response_body_stdout string
local Displayer = {}
Displayer.__index = Displayer

local prediction_namespace = vim.api.nvim_create_namespace('zeta-prediction')
---@param watcher WindowWatcher
function Displayer:new(watcher)
    self = setmetatable({}, Displayer)
    self.window = watcher.window
    watcher.displayer = self
    self.watcher = watcher
    self.marks = ExtmarksSet:new(self.window:buffer().buffer_number, prediction_namespace)
    self.rewritten_editable = nil
    return self
end

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

local select_excerpt_mark_id = 11

function Displayer:reject()
    self:pause_watcher()

    -- undo works for now! lets try this
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>u', true, false, true), 'n', false)
    -- undo works for now! lets try this
    -- vim.api.nvim_feedkeys("u", "n", false)

    -- -- put back original lines (somehow off by one on the last line, see below when I capture original lines, if I need to take this approach to undo)
    -- self.window:buffer():replace_lines(
    --     self.current_request.details.editable_start_line,
    --     self.current_request.details.editable_start_line,
    --     self.original_lines)

    self.marks:clear_all()

    self.watcher.displayer = nil
    self:remove_keymaps()
    self:resume_watcher()
end

function Displayer:accept()
    self:pause_watcher()

    local request = self.current_request

    local lines = vim.fn.split(self.rewritten_editable, '\n')

    -- TODO think through why I need an empty last line here?
    --   without one empty last line...
    --   the last line of the rewritten text is inserted
    --   infront of the next line (just ater the editable region)
    table.insert(lines, '')

    self.window:buffer():replace_lines(
        request.details.editable_start_line,
        request.details.editable_start_line,
        lines)

    self.marks:clear_all()

    self.watcher.displayer = nil
    self:remove_keymaps()
    self:resume_watcher()
end

function Displayer:pause_watcher()
    self.watcher.paused = true
end

function Displayer:resume_watcher()
    -- is a delay really necessary here? I noticed a new request fire when I synchronously reset paused here
    --   TODO confirm the firing was b/c of unpausing too early
    --   I suspect modifying the lines had a slight lag and so I unpaused before the CursorMovement event fired
    --   ideally I could do something more precise to disable the CursorMoved event
    --     IIRC ask-openai had this same issue and I had to suppress the next event instance in that case!
    --     and that actually worked well
    --     I could compare buffer state after my changes to show the diff vs any incoming change events to see if its just my changes triggering the event?
    --
    -- TODO dial in the appropriate delay, can I just use schedule w/o delay amount?
    vim.defer_fn(function()
        self.watcher.paused = false
    end, 1000)
end

-- * highlight groups (for now use builtin styles)
-- local hl_same = "zeta-same"
-- local hl_added = "zeta-added"
-- local hl_deleted = "zeta-deleted"
-- -- 0 == global namespace (otherwise have to activate them if not global ns on hlgroup)
-- vim.api.nvim_set_hl(0, hl_same, {}) -- for now just keep it as is
-- -- vim.api.nvim_set_hl(0, hl_added, { fg = "#a6e3a1", }) -- ctermfg = "green"
-- -- vim.api.nvim_set_hl(0, hl_added, { fg = "#b5f4cb", }) -- ctermfg = "green"
-- vim.api.nvim_set_hl(0, hl_added, { fg = "#81c8be", }) -- ctermfg = "green"
-- -- vim.api.nvim_set_hl(0, hl_deleted, { fg = "#f28b82", }) -- ctermfg = "red"
-- vim.api.nvim_set_hl(0, hl_deleted, { fg = "#ff6b6b", }) -- ctermfg = "red"
-- -- vim.api.nvim_set_hl(0, hl_deleted, { fg = "#e06c75", }) -- ctermfg = "red"

---@param request PredictionRequest
---@param response_body_stdout string
function Displayer:on_response(request, response_body_stdout)
    self.current_request = request
    self.current_response_body_stdout = response_body_stdout

    local decoded = vim.fn.json_decode(response_body_stdout)
    messages.header('response_body_stdout:')
    messages.append(inspect(decoded))
    assert(decoded ~= nil, 'decoded reponse body should not be nil')
    local rewritten = decoded.output_excerpt
    if rewritten == nil then
        messages.header('output_excerpt is nil, aborting...')
        return
    end

    local original = request.details.body.input_excerpt or ''
    messages.header('input_excerpt:')
    messages.append(original)
    messages.header('output_excerpt:')
    messages.append(rewritten)

    original_editable = tags.get_editable_region(original) or ''
    -- PRN use cursor position? i.e. check if cursor has moved since prediction requested (might not need this actually)
    -- cursor_position = parser.get_position_of_user_cursor(original) or 0
    -- messages.header("cursor_position:", cursor_position)
    original_editable = tags.strip_user_cursor_tag(original_editable)

    self.rewritten_editable = tags.get_editable_region(rewritten) or ''
    messages.header('original_editable:')
    messages.append(original_editable)
    messages.header('rewritten_editable:')
    messages.append(self.rewritten_editable)

    local diff = combined.combined_diff(original_editable, self.rewritten_editable)
    -- messages.header("diff:")
    -- messages.append(inspect(diff))

    local extmark_lines = vim.iter(diff):fold({ {} }, function(accum, chunk)
        if chunk == nil then
            messages.append('nil chunk: ' .. tostring(chunk))
        else
            -- each chunk has has two strings: { "text\nfoo\nbar", "type" }
            --   type == "same", "add", "del"
            -- text must be split on new line into an array
            --  when \n is encountered, start a new line in the accum
            local current_line = accum[#accum]
            local type = chunk[1]
            local text = chunk[2]

            local type_hlgroup = nil -- nil = TODO don't change it right?
            if type == '+' then
                -- type_hlgroup = hl_added -- mine (above)
                -- FYI nvim and plugins have a bunch of options already registerd too (color/highlight wise)
                -- type_hlgroup = "Added" -- light green
                type_hlgroup = 'diffAdded' -- darker green/cyan - *** FAVORITE
            elseif type == '-' then
                -- type_hlgroup = hl_deleted -- mine (above)
                -- type_hlgroup = "Removed" -- very light red (almost brown/gray)
                type_hlgroup = 'diffRemoved' -- dark red - *** FAVORITE
                -- return accum
                -- actually, based on how I aggregate between sames... there should only be one delete and one add between any two sames... so, I could just show both and it would appaer like remove / add (probably often lines removed then lines added, my diff processor puts the delete first which makes sense for that to be on top)
            end
            if not text:find('\n') then
                -- no new lines, so we just tack on to end of current line
                local len_text = #text
                if len_text > 0 then
                    table.insert(current_line, { text, type_hlgroup })
                end
            else
                local splits = vim.split(text, '\n')
                messages.header('splits:')
                messages.append(inspect(splits))
                for i, piece in ipairs(splits) do
                    -- FYI often v will be empty (i.e. a series of newlines)... do not exclude these empty lines!
                    local len_text = #piece
                    if len_text > 0 then
                        -- don't add empty pieces, just make sure we add the lines (even if empty)
                        table.insert(current_line, { piece, type_hlgroup })
                    end
                    if i < #splits then
                        -- start a new, empty line (even if last piece was empty)
                        current_line = {}
                        accum[#accum + 1] = current_line
                        -- next piece will be first, which could be next in splits OR a subsequent chunk
                    end
                end
            end
        end
        return accum
    end)

    -- TODO! double check logic that this is ok to do,
    -- this fixes extra line issue... and it seems right to remove this
    -- review fold logic above, meticulously
    -- TODO even better, write a unit test for this:
    --
    -- check if last group is empty, remove if so
    local last_line = extmark_lines[#extmark_lines]
    if #last_line < 1 then
        table.remove(extmark_lines, #extmark_lines)
    end

    -- messages.header("extmark_lines")
    -- for _, v in ipairs(extmark_lines) do
    --     messages.append(vim.inspect(v))
    -- end

    if #extmark_lines < 1 then
        messages.append('no lines')
        return
    end

    -- hide the original edtiable lines?
    -- show the diff where they were?
    -- or do like I do on AskRewrite, just show it all at the top of the selection as extmarks
    --   and then accept / reject accordingly... thats a good start point...
    --   then later can decide if I wanna hide the original
    --   I kinda like how that approach pushes the original down for easy reference too
    --   OR, popup window w/ diff?

    local start_line = request.details.editable_start_line
    local end_line = request.details.editable_end_line

    self:pause_watcher()

    -- ?? switch to incremental diff presentation (not AIO), and with it partial accept/reject?!
    -- self.marks:diff_strike_lines(start_line, end_line)

    messages.header('extmark_lines')
    for _, v in ipairs(extmark_lines) do
        messages.append(vim.inspect(v))
    end


    self.marks:set(select_excerpt_mark_id, {
        start_line = start_line - 1, -- that way first virt_line is in line below == start_line
        start_col = 0,
        -- virt_text = first_extmark_line, -- leave first line unchanged (its the line before the changes)
        id = select_excerpt_mark_id,
        virt_lines = extmark_lines, -- all changes appear under the line above the diff
        virt_text_pos = 'overlay',
    })

    -- delete original lines (that way only diff shows in extmarks)
    self.original_lines = self.window:buffer():get_lines(start_line, end_line)
    table.insert(self.original_lines, '') -- add empty line (why?)
    self.window:buffer():replace_lines(start_line, end_line, {})

    -- PRN... register event handler that fires once ... on user typing, to undo and put stuff back
    --    this works-ish... feels wrong direction but...
    --    revisit how zed does the diff display/interaction...
    --    does it feel right to show it and then type to say no? it probably does
    --       as long as its not constantly lagging the typing for you
    if false then
        vim.api.nvim_create_autocmd({ 'InsertCharPre' }, {
            buffer = self.window:buffer().buffer_number,
            callback = function(args)
                -- TODO! this conflicts with accepting on Tab.. or w/e keymap
                local char = vim.v.char
                vim.schedule(function()
                    -- Btw to trigger this if you are  in normal moded for fake prediction:
                    --   type i to go into insert mode
                    --   then type a new char to trigger this
                    --   TODO better yet setup a trigger in insert mode again for fake testing so not wait on real deal
                    messages.header('InsertCharPre')
                    messages.append(args)
                    messages.append(char)

                    -- * inlined reject so I can control timing better
                    -- self:reject()
                    self:pause_watcher()

                    -- * undo or put lines back:
                    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>u', true, false, true), 'n', false)
                    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>u', true, false, true), 'n', false)
                    -- why am I needing two undos? that part is confusing me... used to work with just one?
                    -- -- put back manually (have to add back below capturing this and fix off by one line issue):
                    -- self.window:buffer():replace_lines(
                    --     self.current_request.details.editable_start_line,
                    --     self.current_request.details.editable_start_line,
                    --     self.original_lines)

                    -- * clear marks
                    self.marks:clear_all()

                    -- * back to insert mode
                    -- vim.api.nvim_feedkeys("i", 'n', true) -- back to insert standalone
                    -- WORKS!!!
                    vim.api.nvim_feedkeys('i' .. char, 'n', true) -- back to insert mode and type key.. not working
                    -- STILL VERY ROUGH AROUND THE EDGES BUT THIS IS WORKING!


                    -- TODO RESUME LATER... test w/ insert mode real predictions!
                    -- FYI disable other copilots (llama.vim) seems to cause some sort of fighting here

                    -- * put back cursor (so far seems like it goes back to where it was)

                    self:resume_watcher() -- FYI the delay here just means user has to maybe type a few more chars to trigger next prediction, that's fine for now
                end)
            end,
            once = true
        })
    end

    self:resume_watcher()

    self:set_keymaps()
end

function Displayer:set_keymaps()
    function accept()
        vim.schedule(function()
            messages.append('Accepting')
            self:accept()
        end)
    end
    vim.keymap.set({ 'i', 'n' }, '<Tab>', accept, { expr = true, buffer = true })
    vim.keymap.set({ 'i', 'n' }, '<M-Tab>', accept, { expr = true, buffer = true })

    function reject()
        vim.schedule(function()
            messages.append('Rejecting')
            self:reject()
        end)
    end
    vim.keymap.set({ 'i', 'n' }, '<Esc>', reject, { expr = true, buffer = true })
    vim.keymap.set({ 'i', 'n' }, '<M-Esc>', reject, { expr = true, buffer = true })
end

function Displayer:remove_keymaps()
    -- TODO get rid of fallbacks? Alt-Tab/Esc shouldn't be needed
    vim.cmd([[
      silent! iunmap <buffer> <Tab>
      silent! iunmap <buffer> <Esc>
      silent! iunmap <buffer> <M-Tab>
      silent! iunmap <buffer> <M-Esc>

      silent! nunmap <buffer> <Tab>
      silent! nunmap <buffer> <Esc>
      silent! nunmap <buffer> <M-Tab>
      silent! nunmap <buffer> <M-Esc>
    ]])
end

return Displayer
