local messages = require("devtools.messages")
local inspect = require("devtools.inspect")

---@class ExcerptSelector
---@field buffer BufferController0Indexed
local ExcerptSelector = {}
ExcerptSelector.__index = ExcerptSelector

---@param buffer BufferController0Indexed
function ExcerptSelector.new(buffer)
    local self = setmetatable({}, ExcerptSelector)
    self.buffer = buffer
    return self
end

local function get_enclosing_function_node(node)
    -- FYI right now I am desinging this for lua:
    --  function_definition - named function
    --  function_declaration - anonymous function
    --  both have a body, that's the first scope I want to try

    local root = node:root()
    while node ~= root do
        local parent = node:parent()
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
    return nil
end

---@param row integer 0-indexed
---@param column integer 0-indexed
---@return string|nil
function ExcerptSelector:select_at_position(row, column)
    local node = self.buffer:get_node_at_position(row, column)
    if node == nil then
        return nil
    end

    -- find closest parent function node
    get_enclosing_function_node(node)

    local start_row, start_column, end_row, end_column = node:range()
    messages.header("range:")
    messages.append({
        _start_row = start_row,
        _start_column = start_column,
        end_row = end_row,
        end_column = end_column,
    })
    local text = vim.treesitter.get_node_text(node, self.buffer.buffer_number)
    -- TODO get from buffer directly using line range

    return
end

return ExcerptSelector
