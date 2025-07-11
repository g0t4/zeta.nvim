local messages = require('devtools.messages')
local inspect = require('devtools.inspect')
local Excerpt = require('zeta.predicts.Excerpt')
local tags = require('zeta.helpers.tags')
local logs = require('zeta.helpers.logs')

---@class ExcerptSelector
---@field buffer BufferController0Indexed
local ExcerptSelector = {}
ExcerptSelector.__index = ExcerptSelector

---@param buffer BufferController0Indexed
function ExcerptSelector:new(buffer)
    self = setmetatable(self, ExcerptSelector)
    self.buffer = buffer
    self.has_treesitter = has_treesitter(buffer.buffer_number)
    return self
end

function has_treesitter(buffer_number)
    return pcall(vim.treesitter.get_parser, buffer_number)
end

-- local all_lines = buffer:get_all_lines()
-- error("TODO finish selecting lines w/o treesitter, using line range")

---@param node TSNode
---@param filetype string
local function is_section_node(node, filetype)
    local node_type = node:type()
    if node_type == 'function_declaration'
        or node_type == 'function_definition'
        or node_type == 'arrow_function' -- js
        or node_type == 'lambda' -- python?
        or node_type == 'function_expression' --js
    then
        return true
    end

    if filetype == 'markdown' then
        return node_type == 'section'
    end
    return false
end

---@param node TSNode
---@param filetype string
---@return TSNode|nil
local function get_enclosing_function_node(node, filetype)
    -- FYI right now I am desinging this for lua:
    --  function_definition - named function
    --  function_declaration - anonymous function
    --  both have a body, that's the first scope I want to try

    -- FYI node:root() works but isn't in the lua type hints
    -- local root = node:root()
    -- messages.append("root:")
    -- messages.append(inspect(root))

    while true do
        if is_section_node(node, filetype) then
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

---@param row_0i integer 0-indexed
---@param column_0i integer 0-indexed
---@return integer|nil, integer|nil # start_line, end_line 0-indexed (end exclusive?)
function ExcerptSelector:line_range_with_treesitter(row_0i, column_0i)
    local node = self.buffer:get_node_at_position(row_0i, column_0i)
    if node == nil then
        -- FYI can happen when first enter a buffer (IIAC treesitter is not ready?)
        logs.trace('no node found at position: ' .. row_0i .. ', ' .. column_0i)
        return nil, nil
    end

    -- find closest enclosing node (to start search for excerpt range)
    local enclosing = get_enclosing_function_node(node, self.buffer:filetype())
    if enclosing == nil then
        logs.trace('no enclosing node found at position: ' .. row_0i .. ', ' .. column_0i)
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
---@param cursor_row_0i integer 0-indexed
---@param cursor_column_0i integer 0-indexed
---@return Excerpt|nil
function ExcerptSelector:excerpt_at_position(cursor_row_0i, cursor_column_0i)
    local editable_start_line_0i, editable_end_line_0i
    if self.has_treesitter then
        local ts_editable_start_line_0i, ts_editable_end_line_exclusive_0i = self:line_range_with_treesitter(cursor_row_0i, cursor_column_0i)
        editable_start_line_0i = ts_editable_start_line_0i
        editable_end_line_0i = ts_editable_end_line_exclusive_0i - 1
        -- TODO verify that editable_end_line_0i is END EXCLUSIVE and 0i...
        --   it appears to be... and so it will be a line # in 0i that does not exist
        messages.append('editable_start_line_0i: ' .. editable_start_line_0i ..
            ', editable_end_line_0i: ' .. editable_end_line_0i)
    else
        -- not treesitter, just take up to 10 lines back / forward for now
        local ten_lines_back_0i = cursor_row_0i - 10
        local ten_lines_forward_0i = cursor_row_0i + 10
        editable_start_line_0i = math.max(0, ten_lines_back_0i)
        local num_lines_0i = self.buffer:num_lines() - 1
        editable_end_line_0i = math.min(num_lines_0i, ten_lines_forward_0i)
        -- FYI test w/ zsh and txt files
        -- TODO add better logic to expand editable range / context range
    end

    if editable_start_line_0i == nil or editable_end_line_0i == nil then
        return nil
    end

    local editable_end_line_exclusive_0i = editable_end_line_0i + 1
    local text_lines = self.buffer:get_lines(editable_start_line_0i, editable_end_line_exclusive_0i)

    -- * mark cursor position
    local cursor_offset_row = cursor_row_0i - editable_start_line_0i
    local cursor_offset_row_1indexed = cursor_offset_row + 1
    local original_cursor_line = text_lines[cursor_offset_row_1indexed] -- 1-indexed arrays
    -- cursor is literally between cursor_column and cursor_column + 1 => visually it sits on cursor_column + 1
    --   cursor_column is left of cursor position
    --   cursor_column + 1 is right of cursor position
    --   physically, the cursor shows on top of the cursor_column + 1 char

    local tagged_cursor_line = tags.insert_cursor_tag(original_cursor_line, cursor_column_0i)

    text_lines[cursor_offset_row_1indexed] = tagged_cursor_line

    tags.wrap_editable_tags(text_lines)

    -- TODO make sure lines are joined correctly...
    --   that w/ serialization we get \n as appropriate (vs new lines)... not sure just check what is needed for model's template and what I have here (for fake and real requests)
    text = table.concat(text_lines, '\n')
    return Excerpt:new(text, editable_start_line_0i, editable_end_line_0i)
end

return ExcerptSelector
