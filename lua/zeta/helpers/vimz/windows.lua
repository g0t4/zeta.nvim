local M = {}

-- FYI cannot scroll such that there are no buffer lines visible
-- scroll stops when last buffer line is visible at the top of the window
function M.set_topline(new_topline)
    local view = vim.fn.winsaveview()
    view.topline = new_topline
    vim.fn.winrestview(view)
end

return M
