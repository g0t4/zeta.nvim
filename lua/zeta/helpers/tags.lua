local M = {}

local tag_edit_start = "<|editable_region_start|>"
local tag_edit_end = "<|editable_region_end|>"
local tag_cursor_here = "<|user_cursor_is_here|>"
-- TODO use start of file tag!
local tag_start_of_file = "<|start_of_file|>"

---@param text string
function M.get_editable_region(text)
    local start_search_for = tag_edit_start .. "\n"
    local start_index = text:find(start_search_for)

    local end_search_for = "\n" .. tag_edit_end
    local end_index = text:find(end_search_for)

    if start_index == nil
        or end_index == nil
        or start_index < 0
        or end_index < start_index then
        return nil
    end

    start_index = start_index + #start_search_for
    end_index = end_index - 1
    return text:sub(start_index, end_index)
end

---FYI this edits the original table, IN PLACE
---@param lines string[]
function M.wrap_editable_tags(lines)
    table.insert(lines, 1, tag_edit_start)
    table.insert(lines, tag_edit_end)
    -- FYI took off returning the list so its clear this is an in-place edit (for now)
end

---@param text string
---@return string
function M.strip_user_cursor_tag(text)
    local cleaned = text:gsub(tag_cursor_here, "")
    return cleaned
end

function M.insert_cursor_tag(original_cursor_line, cursor_column)
    --   cursor_column is left of cursor block (left edge of block)
    --   therefore, cursor_column + 1 is the first character after the cursor
    --     which with block cursor is the one that the block highlights
    --   physically, the cursor shows on top of the cursor_column + 1 char

    -- FYI string:sub() is 1-indexed and END-INCLUSIVE
    local tagged_cursor_line = original_cursor_line:sub(1, cursor_column)
        .. tag_cursor_here
        .. original_cursor_line:sub(cursor_column + 1)
    return tagged_cursor_line
end

return M
