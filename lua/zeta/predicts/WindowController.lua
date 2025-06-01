local BufferController0Indexed = require('zeta.predicts.BufferController')

---This entire class operates on 0-indexed row and column positions
---   or if that seems wrong I'll go to all 1-indexed
---Also intended to hide away complexities in nvim_ apis
---  esp the need to track window ids, buffer #s, etc
---@class WindowController0Indexed
---@field window_id integer
local WindowController0Indexed = {}
WindowController0Indexed.__index = WindowController0Indexed

--- @param window_id integer
function WindowController0Indexed:new(window_id)
    self = setmetatable(self, WindowController0Indexed)
    self.window_id = window_id
    return self
end

--- Looks up window id for current window
--- uses that to create a new WindowController
function WindowController0Indexed:new_from_current_window()
    return WindowController0Indexed:new(vim.api.nvim_get_current_win())
end

---@return integer row, integer column # both 0-indexed
function WindowController0Indexed:get_cursor_position()
    -- keep in mind different windows w/ same buffer have their own cursor positions
    -- that's why this is window specific
    -- get_cursor returns 1-indexed row, 0-indexed column
    local pos = vim.api.nvim_win_get_cursor(self.window_id)
    -- ? do I prefer to use a table or two return values?
    return pos[1] - 1, pos[2]
end

---@return integer row 0-indexed
function WindowController0Indexed:get_cursor_row()
    local row, _ = self:get_cursor_position()
    return row
end

---@return integer column 0-indexed
function WindowController0Indexed:get_cursor_column()
    local _, column = self:get_cursor_position()
    return column
end

---@param row integer 0-indexed
---@param column integer 0-indexed
function WindowController0Indexed:set_cursor_position(row, column)
    vim.api.nvim_win_set_cursor(self.window_id, { row + 1, column })
end

function WindowController0Indexed:buffer()
    -- old troubleshooting code for some issues around invalid window_ids
    -- logs.trace('getting buffer for window ' .. self.window_id)
    -- messages.append('windows: ' .. vim.inspect(vim.api.nvim_list_wins()))
    -- nvim_helpers.dump_windows()
    -- nvim_helpers.dump_buffers()
    local buffer_number = vim.api.nvim_win_get_buf(self.window_id)
    return BufferController0Indexed:new(buffer_number)
end

function WindowController0Indexed:get_node_at_cursor()
    local row, column = self:get_cursor_position()
    return self:buffer():get_node_at_position(row, column)
end

return WindowController0Indexed
