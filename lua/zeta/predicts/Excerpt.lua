---@class Excerpt
---@field text string
---@field editable_start_line integer 0-indexed
---@field editable_end_line integer 0-indexed
local Excerpt = {}
Excerpt.__index = Excerpt

---@param text string - single string, not lines
---@param editable_start_line integer 0-indexed
---@param editable_end_line integer 0-indexed
function Excerpt:new(text, editable_start_line, editable_end_line)
    self.text = text
    self.editable_start_line = editable_start_line
    self.editable_end_line = editable_end_line
    return self
end

return Excerpt
