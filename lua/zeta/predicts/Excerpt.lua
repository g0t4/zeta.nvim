---@class Excerpt
---@field text string
---@field start_line integer 0-indexed
---@field end_line integer 0-indexed
local Excerpt = {}
Excerpt.__index = Excerpt

---@param text string - single string, not lines
---@param start_line integer 0-indexed
---@param end_line integer 0-indexed
function Excerpt:new(text, start_line, end_line)
    self.text = text
    self.start_line = start_line
    self.end_line = end_line
    return self
end

return Excerpt
