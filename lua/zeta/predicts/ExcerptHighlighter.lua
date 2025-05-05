local ExtmarksSet = require("zeta.predicts.ExtmarksSet")

---@class ExcerptHighlighter
local ExcerptHighlighter = {}
ExcerptHighlighter.__index = ExcerptHighlighter

function ExcerptHighlighter:new(buffer_number)
    self               = setmetatable({}, ExcerptHighlighter)
    self.buffer_number = buffer_number

    -- TODO let extmarksset create the namespace (pass string for it)...
    local ns_id        = vim.api.nvim_create_namespace("zeta-excerpts")
    self.marks         = ExtmarksSet:new(self.buffer_number, ns_id)
    return self
end

function ExcerptHighlighter:clear()
    self.marks:clear_all()
end

function ExcerptHighlighter:highlight_lines(details)
    local hl_editable = "zeta-excerpt-editable"
    local hl_context = "zeta-excerpt-context"
    vim.api.nvim_set_hl(0, hl_editable, { bg = "green" })
    vim.api.nvim_set_hl(0, hl_context, { bg = "blue" })
    local editable_mark_id = 20
    local ctx_before_mark_id = 21
    local ctx_after_mark_id = 22
    self.marks:highlight_lines({
        id = editable_mark_id,
        hl_group = hl_editable,
        start_line = details.editable_start_line,
        end_line = details.editable_end_line,
    })
    -- * highlight the context before/after
    if details.context_before_start_line < details.editable_start_line then
        self.marks:highlight_lines({
            id = ctx_before_mark_id,
            hl_group = hl_context,
            start_line = details.context_before_start_line,
            end_line = details.editable_start_line,
        })
    end
    if details.context_after_end_line > details.editable_end_line then
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
