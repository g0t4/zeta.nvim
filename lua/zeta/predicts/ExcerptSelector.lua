local messages = require("devtools.messages")
local inspect = require("devtools.inspect")

---@class ExcerptSelector
---@field buffer BufferController0Indexed
local ExcerptSelector = {}
ExcerptSelector.__index = ExcerptSelector

---@param buffer BufferController0Indexed
function ExcerptSelector:new(buffer)
    self = setmetatable(self, ExcerptSelector)
    self.buffer = buffer
    return self
end

---@param node TSNode
---@return TSNode|nil
local function get_enclosing_function_node(node)
    -- FYI right now I am desinging this for lua:
    --  function_definition - named function
    --  function_declaration - anonymous function
    --  both have a body, that's the first scope I want to try

    -- FYI node:root() works but isn't in the lua type hints
    -- local root = node:root()
    -- messages.append("root:")
    -- messages.append(inspect(root))

    while true do
        local parent = node:parent()
        if parent == nil then
            -- assume at the root
            return node
        end
        if parent == node then
            -- does this ever happen? or would it be nil when reach root?
            return node
        end
        local parent_type = parent:type()
        if parent_type == "function_declaration"
            or parent_type == "function_definition"
            or parent_type == "arrow_function"
            or parent_type == "lambda"
            or parent_type == "function_expression"
        then
            return parent
        end
        node = parent
    end
end

---@param row integer 0-indexed
---@param column integer 0-indexed
---@return integer, integer # start_line, end_line 0-indexed (end exclusive?)
function ExcerptSelector:line_range_at_position(row, column)
    local node = self.buffer:get_node_at_position(row, column)
    if node == nil then
        error("no node found at position: " .. row .. ", " .. column)
    end

    -- find closest enclosing node (to start search for excerpt range)
    local enclosing = get_enclosing_function_node(node)

    -- TODO is :range() inclusive or exclusive?
    local start_row, start_column, end_row, end_column = enclosing:range()
    messages.header("enclosing: " .. tostring(enclosing:type()))
    messages.append({
        _start_row = start_row,
        _start_column = start_column,
        end_row = end_row,
        end_column = end_column,
    })

    -- TODO look at size of it to expand or contract it:
    -- local text = vim.treesitter.get_node_text(node, self.buffer.buffer_number)
    -- for now lets just use the first enclosing node
    return start_row, end_row
end

---@param row integer 0-indexed
---@param column integer 0-indexed
---@return string|nil
function ExcerptSelector:text_at_position(row, column)
    local start_line, end_line = self:line_range_at_position(row, column)
    if start_line == nil or end_line == nil then
        return nil
    end
    -- TODO get line range
    local text = self.buffer:get_lines(start_line, end_line)
    messages.header("text:")
    return text
end

return ExcerptSelector
