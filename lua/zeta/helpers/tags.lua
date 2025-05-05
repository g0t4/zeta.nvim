local M = {}

M.tag_edit_start = "<|editable_region_start|>"
M.tag_edit_end = "<|editable_region_end|>"
M.tag_cursor_here = "<|user_cursor_is_here|>"
M.tag_start_of_file = "<|start_of_file|>"

---@param text string
function M.get_editable_region(text)
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

-- function M.get_position_of_user_cursor(text)
--     -- TODO what format do I need this to be in?
--     local start_index = text:find(M.tag_cursor_here)
--     if start_index == nil then
--         return nil
--     end
--     return start_index - 1
-- end

---@param text string
---@return string
function M.strip_user_cursor_tag(text)
    local cleaned = text:gsub(M.tag_cursor_here, "")
    return cleaned
end

---@param all_lines string[]
---@param cursor_row integer 0-indexed
---@param cursor_column integer 0-indexed
function M.mark_editable_region(all_lines, cursor_row, cursor_column)
    -- TODO this is a temp stopgap solution to using all lines, can discard with treesitter approach coming next
    local cursor_on_row_1based = cursor_row + 1

    -- first insert cursor position tag
    local cursor_line = all_lines[cursor_on_row_1based]
    cursor_line = cursor_line:sub(1, cursor_column) .. M.tag_cursor_here .. cursor_line:sub(cursor_column + 1)
    all_lines[cursor_on_row_1based] = cursor_line

    -- then wrap editable around all lines for now
    table.insert(all_lines, 1, M.tag_edit_start)
    -- table.insert(all_lines, 1, M.tag_start_of_file) -- does this help with repeating responses?
    table.insert(all_lines, M.tag_edit_end)
    return all_lines
end

return M
