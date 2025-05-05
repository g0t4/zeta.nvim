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

return BufferController0Based
