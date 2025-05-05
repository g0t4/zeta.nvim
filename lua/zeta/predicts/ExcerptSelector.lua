local messages = require("devtools.messages")
local inspect = require("devtools.inspect")
local Excerpt = require("zeta.predicts.Excerpt")

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

-- PRN disable by default, add user command/func to enable
-- all my logs that I wanna keep around are useful but can really add overhead
local verbose = true
function trace(...)
    if not verbose then return end
    messages.append(...)
end

---@param row integer 0-indexed
---@param column integer 0-indexed
---@return integer|nil, integer|nil # start_line, end_line 0-indexed (end exclusive?)
function ExcerptSelector:line_range_at_position(row, column)
    local node = self.buffer:get_node_at_position(row, column)
    if node == nil then
        -- FYI can happen when first enter a buffer (IIAC treesitter is not ready?)
        trace("no node found at position: " .. row .. ", " .. column)
        return nil, nil
    end

    -- find closest enclosing node (to start search for excerpt range)
    local enclosing = get_enclosing_function_node(node)
    if enclosing == nil then
        trace("no enclosing node found at position: " .. row .. ", " .. column)
        return nil, nil
    end

    -- TODO is :range() inclusive or exclusive?
    -- TODO! capture editable start/end lines... beyond that doesn't matter (just context)
    local editable_start_line, start_column, editable_end_line, end_column = enclosing:range()
    messages.header("enclosing: " .. tostring(enclosing:type()))
    messages.append({
        _start_row = editable_start_line,
        _start_column = start_column,
        end_row = editable_end_line,
        end_column = end_column,
    })

    -- TODO look at size of it to expand or contract it:
    -- local text = vim.treesitter.get_node_text(node, self.buffer.buffer_number)
    -- for now lets just use the first enclosing node
    return editable_start_line, editable_end_line
end

---@param row integer 0-indexed
---@param column integer 0-indexed
---@return Excerpt|nil
function ExcerptSelector:text_at_position(row, column)
    local editable_start_line, editable_end_line = self:line_range_at_position(row, column)
    if editable_start_line == nil or editable_end_line == nil then
        return nil
    end
    local text_lines = self.buffer:get_lines(editable_start_line, editable_end_line)
    -- TODO make sure lines are joined correctly...
    --   that w/ serialization we get \n as appropriate (vs new lines)... not sure just check what is needed for model's template and what I have here (for fake and real requests)
    text = table.concat(text_lines, "\n")
    return Excerpt:new(text, editable_start_line, editable_end_line)
end

return ExcerptSelector
