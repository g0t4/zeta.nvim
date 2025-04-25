local M = {}

M.tag_edit_start = "<|editable_region_start|>"
M.tag_edit_end = "<|editable_region_end|>"
M.tag_cursor_here = "<|user_cursor_is_here|>"
M.tag_start_of_file = "<|start_of_file|>"

---@param text string
function M.get_editable(text)
    local start_index = text:find(M.tag_edit_start)
    local end_index = text:find(M.tag_edit_end)
    if start_index == nil
        or end_index == nil
        or start_index < 0
        or end_index < start_index then
        return nil
    end
    start_index = start_index + #M.tag_edit_start
    end_index = end_index - 1
    return text:sub(start_index, end_index)
end

return M
