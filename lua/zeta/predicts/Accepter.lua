local inspect = require("devtools.inspect")
local messages = require("devtools.messages")

---@class Accepter
local Accepter = {}
Accepter.__index = Accepter

--- accepts all (or part) of a prediction
---@param window WindowController0Indexed
function Accepter:new(window)
    self = setmetatable({}, Accepter)
    self.window = window
    return self
end

---@param displayer Displayer
function Accepter:accept(displayer)
    displayer:pause_watcher()

    local request = displayer.current_request
    local lines = vim.fn.split(displayer.rewritten_editable, "\n")

    self.window:buffer():replace_lines(
        request.details.editable_start_line,
        request.details.editable_end_line,
        lines)

    displayer.marks:clear_all()

    displayer:resume_watcher()
end

return Accepter
