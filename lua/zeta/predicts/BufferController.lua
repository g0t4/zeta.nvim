local messages = require('devtools.messages')
---This entire class operates on 0-indexed row and column positions
---   or if that seems wrong I'll go to all 1-indexed
---Also intended to hide away complexities in nvim_ apis
---  esp the need to track window ids, buffer #s, etc
---@class BufferController0Indexed
---@field buffer_number integer
---@field
local BufferController0Indexed = {}
BufferController0Indexed.__index = BufferController0Indexed

--- @param buffer_number integer
function BufferController0Indexed:new(buffer_number)
    self = setmetatable(self, BufferController0Indexed)
    self.buffer_number = buffer_number
    return self
end

function BufferController0Indexed:new_for_current_buffer()
    -- PRN add a caching mechanism to avoid recreating the controller? if perf issues
    return BufferController0Indexed:new(vim.api.nvim_get_current_win())
end

function BufferController0Indexed:buftype()
    return vim.bo[self.buffer_number].buftype
end

function BufferController0Indexed:filetype()
    return vim.bo[self.buffer_number].filetype
end

function BufferController0Indexed:file_name()
    return vim.api.nvim_buf_get_name(self.buffer_number)
end

function BufferController0Indexed:get_all_lines()
    -- FYI add/reshape the line access method to new scenarios that you actually use
    -- i.e. maybe add
    --    get_lines_after()
    --    get_lines_before()
    --    get_lines_in_range()

    return vim.api.nvim_buf_get_lines(self.buffer_number, 0, -1, true)
end

--- does not include the end line #
--- @param start_row integer 0-indexed
--- @param end_row_exclusive integer 0-indexed
function BufferController0Indexed:get_lines(start_row, end_row_exclusive)
    -- TODO should I decide on end-inclusive or end-exclusive for ALL operations on BufferController?
    --   if so which is more common in nvim APIs?
    --   * end-exclusive used by nvim_buf_get_lines
    -- PRN turn off strict indexing (allow clamp to start/end?)
    return vim.api.nvim_buf_get_lines(self.buffer_number, start_row, end_row_exclusive, true)
end

--- instead of leaving it ambiguous as to what node, lets by clear:
--- - tied to a specific buffer (buffer_number)
--- - tied to a specific position (row, column) - args
---@param row integer 0-indexed
---@param column integer 0-indexed
function BufferController0Indexed:get_node_at_position(row, column)
    return vim.treesitter
        .get_node({
            bufnr = self.buffer_number,
            pos = { row, column },
        })
    -- FTR get_node requires both bufnr and pos
    --   however it will use current buffer
    --   and current window if no bufnr specified
    -- Part of the reason to wrap this interaction is to
    --   make the parameters explicit
    --   and convenient (i.e. class tracks buffer number)
end

---@param start_row integer 0-indexed, set start=end to insert new_lines
---@param end_row integer 0-indexed, end-EXCLUSIV
---@param new_lines string[]
function BufferController0Indexed:replace_lines(start_row, end_row, new_lines)
    if end_row >= self:num_lines() then
        -- FYI this happens when testing fake prediction if you trigger it near the end of the buffer
        --   and the fake prediction is longer than the rest of the buffer
        messages.append('end_row is past end of buffer, clamping to end of buffer')
        end_row = self:num_lines() - 1
    end
    vim.api.nvim_buf_set_text(self.buffer_number,
        start_row, 0,
        end_row, 0,
        new_lines)
end

function BufferController0Indexed:num_lines()
    return vim.api.nvim_buf_line_count(self.buffer_number)
end

return BufferController0Indexed
