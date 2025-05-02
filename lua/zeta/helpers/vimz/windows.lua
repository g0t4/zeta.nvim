local M = {}

-- FYI cannot scroll such that there are no buffer lines visible
-- scroll stops when last buffer line is visible at the top of the window
function M.set_topline(new_topline, _window_id)
    -- switch to window
    local current_window_id = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(_window_id)

    -- change topline
    local view = vim.fn.winsaveview()
    view.topline = new_topline
    vim.fn.winrestview(view)

    -- switch back
    vim.api.nvim_set_current_win(current_window_id)
end

return M
