local parser = require("zeta.helpers.tags")
local combined = require("zeta.diff.combined")
local messages = require("devtools.messages")
local inspect = require("devtools.inspect")
local ExtmarksSet = require("zeta.predicts.ExtmarksSet")

---@class Displayer
---@field window WindowController0Indexed
---@field marks ExtmarksSet
---@field rewritten_editable string
---@field current_request PredictionRequest
---@field current_response_body_stdout string
local Displayer = {}
Displayer.__index = Displayer

local prediction_namespace = vim.api.nvim_create_namespace("zeta-prediction")
---@param watcher WindowWatcher
function Displayer:new(watcher)
    self = setmetatable({}, Displayer)
    self.window = watcher.window
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

function Displayer:clear()
    self:pause_watcher()

    -- reverse physical changes to buffer
    --   put back lines removed
    -- remove extmarks
    self.marks:clear_all()

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
    messages.header("response_body_stdout:")
    messages.append(inspect(decoded))
    assert(decoded ~= nil, "decoded reponse body should not be nil")
    local rewritten = decoded.output_excerpt
    if rewritten == nil then
        messages.header("output_excerpt is nil, aborting...")
        return
    end

    local original = request.details.body.input_excerpt or ""
    -- messages.header("input_excerpt:")
    -- messages.append(original)
    -- messages.header("output_excerpt:")
    -- messages.append(rewritten)

    original_editable = parser.get_editable_region(original) or ""
    -- PRN use cursor position? i.e. check if cursor has moved since prediction requested (might not need this actually)
    -- cursor_position = parser.get_position_of_user_cursor(original) or 0
    -- messages.header("cursor_position:", cursor_position)
    original_editable = parser.strip_user_cursor_tag(original_editable)

    self.rewritten_editable = parser.get_editable_region(rewritten) or ""

    local diff = combined.combined_diff(original_editable, self.rewritten_editable)
    -- messages.header("diff:")
    -- messages.append(inspect(diff))

    local extmark_lines = vim.iter(diff):fold({ {} }, function(accum, chunk)
        if chunk == nil then
            messages.append("nil chunk: " .. tostring(chunk))
        else
            -- each chunk has has two strings: { "text\nfoo\nbar", "type" }
            --   type == "same", "add", "del"
            -- text must be split on new line into an array
            --  when \n is encountered, start a new line in the accum
            local current_line = accum[#accum]
            local type = chunk[1]
            local text = chunk[2]

            local type_hlgroup = nil -- nil = TODO don't change it right?
            if type == "+" then
                -- type_hlgroup = hl_added -- mine (above)
                -- FYI nvim and plugins have a bunch of options already registerd too (color/highlight wise)
                -- type_hlgroup = "Added" -- light green
                type_hlgroup = "diffAdded" -- darker green/cyan - *** FAVORITE
            elseif type == "-" then
                -- type_hlgroup = hl_deleted -- mine (above)
                -- type_hlgroup = "Removed" -- very light red (almost brown/gray)
                type_hlgroup = "diffRemoved" -- dark red - *** FAVORITE
                -- return accum
                -- actually, based on how I aggregate between sames... there should only be one delete and one add between any two sames... so, I could just show both and it would appaer like remove / add (probably often lines removed then lines added, my diff processor puts the delete first which makes sense for that to be on top)
            end
            if not text:find("\n") then
                -- no new lines, so we just tack on to end of current line
                local len_text = #text
                if len_text > 0 then
                    table.insert(current_line, { text, type_hlgroup })
                end
            else
                local splits = vim.split(text, "\n")
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

    -- messages.header("extmark_lines")
    -- for _, v in ipairs(extmark_lines) do
    --     messages.append(vim.inspect(v))
    -- end

    if #extmark_lines < 1 then
        messages.append("no lines")
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

    -- TODO! come back to incremental diff presentation (not AIO)
    -- self.marks:diff_strike_lines(start_line, end_line)

    -- insert extra new line for extmarks at start line
    vim.api.nvim_buf_set_lines(
        self.window:buffer().buffer_number,
        request.details.editable_start_line,
        request.details.editable_start_line,
        false, { "", "" })

    self.marks:set(select_excerpt_mark_id, {
        start_line = request.details.editable_start_line,
        start_col = 0,

        id = select_excerpt_mark_id,
        virt_lines = extmark_lines,
        virt_text_pos = "overlay",
    })

    -- delete original lines (undo on cancel)
    vim.api.nvim_buf_set_lines(
        self.window:buffer().buffer_number,
        request.details.editable_start_line + 1,
        request.details.editable_end_line + 1,
        false, {})

    self:resume_watcher()
end

return Displayer
