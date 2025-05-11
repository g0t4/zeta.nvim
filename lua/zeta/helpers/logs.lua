local messages = require('devtools.messages')

local M = {
    -- verbose = true,
    verbose = false,
}

-- PRN disable by default, add user command/func to enable
-- all my logs that I wanna keep around are useful but can really add overhead
function M.trace(...)
    if not M.verbose then return end
    messages.append(...)
end

-- register a command to do the tracing
function M.setup()
    vim.api.nvim_create_user_command('MessagesBufferToggleVerboseLogs', function()
        M.verbose = not M.verbose
        messages.append('Verbose logging ' .. (M.verbose and 'enabled' or 'disabled'))
    end, { nargs = 0 })
end

return M
