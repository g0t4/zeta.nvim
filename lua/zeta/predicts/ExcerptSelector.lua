local messages = require("devtools.messages")
local inspect = require("devtools.inspect")
local Excerpt = require("zeta.predicts.Excerpt")
local tags = require("zeta.helpers.tags")

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
        local node_type = node:type()
        if node_type == "function_declaration"
            or node_type == "function_definition"
            or node_type == "arrow_function"
            or node_type == "lambda"
            or node_type == "function_expression"
        then
            return node
        end

        -- move up to parent
        local parent = node:parent()
        if parent == nil or parent == node then
            -- nil => assume == root
            -- same node, assume root most too
            return node
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
    local editable_start_line, _, editable_end_line, _ = enclosing:range()

    -- TODO look at size of it to expand or contract it:
    -- local text = vim.treesitter.get_node_text(node, self.buffer.buffer_number)
    -- for now lets just use the first enclosing node
    return editable_start_line, editable_end_line
end

--- the row/col are interpeted as cursor position though they obviously don't have to be
---   this is where the cursor tag is inserted
---@param cursor_row integer 0-indexed
---@param cursor_column integer 0-indexed
---@return Excerpt|nil
function ExcerptSelector:excerpt_at_position(cursor_row, cursor_column)
    local editable_start_line, editable_end_line = self:line_range_at_position(cursor_row, cursor_column)
    if editable_start_line == nil or editable_end_line == nil then
        return nil
    end

    local text_lines = self.buffer:get_lines(editable_start_line, editable_end_line)

    -- * mark cursor position
    local cursor_offset_row = cursor_row - editable_start_line
    local cursor_offset_row_1indexed = cursor_offset_row + 1
    local original_cursor_line = text_lines[cursor_offset_row_1indexed] -- 1-indexed arrays
    -- cursor is literally between cursor_column and cursor_column + 1 => visually it sits on cursor_column + 1
    --   cursor_column is left of cursor position
    --   cursor_column + 1 is right of cursor position
    --   physically, the cursor shows on top of the cursor_column + 1 char

    -- FYI string:sub() is 1-indexed and END-INCLUSIVE
    local tagged_cursor_line = original_cursor_line:sub(1, cursor_column)
        .. tags.tag_cursor_here
        .. original_cursor_line:sub(cursor_column + 1) -- cursor_column is in the prefix before cursor tag, wouldn't want it to repeat here!
    -- tag doesn't replace any content in the line, effectively sits between chars
    text_lines[cursor_offset_row_1indexed] = tagged_cursor_line

    -- TODO confirm if supposed to insert on separate line or right at start of the editable region
    table.insert(text_lines, 1, tags.tag_edit_start)
    table.insert(text_lines, tags.tag_edit_end)

    -- TODO make sure lines are joined correctly...
    --   that w/ serialization we get \n as appropriate (vs new lines)... not sure just check what is needed for model's template and what I have here (for fake and real requests)
    text = table.concat(text_lines, "\n")
    return Excerpt:new(text, editable_start_line, editable_end_line)
end

return ExcerptSelector
