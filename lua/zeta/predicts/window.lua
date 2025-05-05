---This entire class operates on 0-based row and column positions
---   or if that seems wrong I'll go to all 1-based
---Also intended to hide away complexities in nvim_ apis
---  esp the need to track window ids, buffer #s, etc
---@class Window
---@field window_id integer
local WindowController0Based = {}
WindowController0Based.__index = WindowController0Based

--- @param window_id integer
function WindowController0Based:new(window_id)
    self = setmetatable(self, WindowController0Based)
    self.window_id = window_id
    return self
end

--- Looks up window id for current window
--- uses that to create a new WindowController
function WindowController0Based:new_from_current_window()
    -- PRN add a caching mechanism to avoid recreating the controller? if perf issues
    return WindowController0Based:new(vim.api.nvim_get_current_win())
end

---@return integer row, integer column # both 0-based
function WindowController0Based:get_cursor_position()
    -- keep in mind different windows w/ same buffer have their own cursor positions
    -- that's why this is window specific
    -- get_cursor returns 1-based row, 0-based column
    local pos = vim.api.nvim_win_get_cursor(self.window_id)
    -- ? do I prefer to use a table or two return values?
    return pos[1] - 1, pos[2]
end

---@return integer row 0-based
function WindowController0Based:get_cursor_row()
    local row, _ = self:get_cursor_position()
    return row
end

---@return integer column 0-based
function WindowController0Based:get_cursor_column()
    local _, column = self:get_cursor_position()
    return column
end

---@param row integer 0-based
---@param column integer 0-based
function WindowController0Based:set_cursor_position(row, column)
    vim.api.nvim_win_set_cursor(self.window_id, { row + 1, column })
end

return WindowController0Based
