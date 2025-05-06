local ExtmarksSet = require("zeta.predicts.ExtmarksSet")
local BufferController = require("zeta.predicts.BufferController")
local messages = require("devtools.messages")

---@class ExcerptHighlighter
local ExcerptHighlighter = {}
ExcerptHighlighter.__index = ExcerptHighlighter

function ExcerptHighlighter:new(buffer_number)
    self        = setmetatable({}, ExcerptHighlighter)
    self.buffer = BufferController:new(buffer_number)

    -- TODO let extmarksset create the namespace (pass string for it)...
    local ns_id = vim.api.nvim_create_namespace("zeta-excerpts")
    self.marks  = ExtmarksSet:new(buffer_number, ns_id)
    return self
end

function ExcerptHighlighter:clear()
    self.marks:clear_all()
end

local hl_editable = "zeta-excerpt-editable"
-- Active excerpt (primary highlight)
vim.api.nvim_set_hl(0, hl_editable, {
    bg = "#3c4452", -- dark desaturated bluish tone
    fg = "NONE"
})

local hl_context = "zeta-excerpt-context"
-- Context lines (lighter, less saturated)
vim.api.nvim_set_hl(0, hl_context, {
    bg = "#2f3640", -- subtle contrast from base bg
    fg = "#888888" -- optional if you want to dim text slightly
})

local hl_headsup = "zeta-headsup"
vim.api.nvim_set_hl(0, hl_headsup, {
    -- fg = "#e5c07b",
    -- bold = true
    fg = "#1f1f1f",
    bg = "#ffcc00"
})

---@param details PredictionDetails
function ExcerptHighlighter:highlight_lines(details)
    messages.append("details")
    messages.append(details)
    local editable_mark_id = 20
    local ctx_before_mark_id = 21
    local ctx_after_mark_id = 22
    local headsup_mark_id = 23
    -- * highlight the editable
    self.marks:highlight_lines({
        id = editable_mark_id,
        hl_group = hl_editable,
        start_line = details.editable_start_line,
        end_line = details.editable_end_line,
    })
    -- * headsup extmark shows # chars and tokens
    local chars_excerpt = details.body.input_excerpt:len()
    local estimated_tokens_per_char = 4
    local approx_tokens_excerpt = math.ceil(chars_excerpt / estimated_tokens_per_char)
    local headsup = "c: " .. chars_excerpt .. ", t: " .. approx_tokens_excerpt
    local on_line = details.editable_end_line
    -- display on last line of entire excerpt
    self.marks:highlight_lines({
        id = headsup_mark_id,
        start_line = on_line,
        end_line = on_line,
        hl_group = hl_headsup,
        virt_text_pos = "eol",
        virt_text = { { headsup, hl_headsup } },
    })



    -- * highlight the context before/after
    if details.context_before_start_line < details.editable_start_line then
        if details.context_before_start_line < 0 then
            details.context_before_start_line = 0
        end
        self.marks:highlight_lines({
            id = ctx_before_mark_id,
            hl_group = hl_context,
            start_line = details.context_before_start_line,
            end_line = details.editable_start_line,
        })
    end
    if details.context_after_end_line > details.editable_end_line then
        if details.context_after_end_line > self.buffer:line_count() then
            details.context_after_end_line = self.buffer:line_count()
        end
        self.marks:highlight_lines({
            id = ctx_after_mark_id,
            hl_group = hl_context,
            start_line = details.editable_end_line,
            end_line = details.context_after_end_line,
        })
    end

    -- aside:
    -- TODO what if I had a keymap that would allow me to select one off context for next predictions?
    -- or that allowed setting to go one more level past current func ... to somehoww conditionally expand or contract the selected func/block?
    -- can I have a keycombo that enables showing the context as I type! (not selecting cuz that would mess up the context)
    --   but toggle context on/off! and then controls to alter the selection with live feedback!
end

return ExcerptHighlighter
