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
    local request = displayer.current_request
    local response_body_stdout = displayer.current_response_body_stdout
    -- TODO get rewritten lines w/o tags
    local lines = vim.fn.split(response_body_stdout, "\n")

    self.window:buffer():replace_lines(
        request.details.editable_start_line,
        request.details.editable_end_line,
        lines)

    displayer:clear()
end

return Accepter
