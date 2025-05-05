---This entire class operates on 0-based row and column positions
---   or if that seems wrong I'll go to all 1-based
---Also intended to hide away complexities in nvim_ apis
---  esp the need to track window ids, buffer #s, etc
---@class BufferController0Based
---@field buffer_number integer
---@field
local BufferController0Based = {}
BufferController0Based.__index = BufferController0Based

--- @param buffer_number integer
function BufferController0Based:new(buffer_number)
    self = setmetatable(self, BufferController0Based)
    self.buffer_number = buffer_number
    return self
end

function BufferController0Based:new_for_current_buffer()
    -- PRN add a caching mechanism to avoid recreating the controller? if perf issues
    return BufferController0Based:new(vim.api.nvim_get_current_win())
end

function BufferController0Based:get_all_lines()
    -- FYI add/reshape the line access method to new scenarios that you actually use
    -- i.e. maybe add
    --    get_lines_after()
    --    get_lines_before()
    --    get_lines_in_range()

    return vim.api.nvim_buf_get_lines(self.buffer_number, 0, -1, true)
end

--- instead of leaving it ambiguous as to what node, lets by clear:
--- - tied to a specific buffer (buffer_number)
--- - tied to a specific position (row, column) - args
---@param row integer 0-based
---@param column integer 0-based
function BufferController0Based:get_node_at_position(row, column)
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

return BufferController0Based
