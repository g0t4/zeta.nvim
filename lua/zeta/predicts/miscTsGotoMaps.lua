local ts = vim.treesitter

local function is_function_node(node)
    local node_type = node:type()
    return node_type == "function_declaration"
        or node_type == "function_definition"
        or node_type == "arrow_function"
        or node_type == "lambda"
        or node_type == "function_expression"
end


local function find_next_function_node()
    local bufnr = 0
    local parser = ts.get_parser(bufnr)
    local tree = parser:parse()[1]
    local root = tree:root()

    local cursor_row, cursor_col = unpack(vim.api.nvim_win_get_cursor(0))
    cursor_row = cursor_row - 1

    local target_node = nil

    -- Walk the tree in order using an iterator
    local function iter(node)
        if not node then return end
        for child in node:iter_children() do
            iter(child)
        end
        -- Post-order visit
        local start_row, start_col = node:start()
        if (start_row > cursor_row) or (start_row == cursor_row
                and start_col > cursor_col) then
            if is_function_node(node) then
                if not target_node or node:start() < target_node:start() then
                    print("Found function:", node:type(), node:start())
                    target_node = node
                end
            end
        end
    end

    iter(root)

    if target_node then
        local srow, scol, erow, ecol = target_node:range()
        print("Found function from:", srow, scol, "to", erow, ecol)
        -- optional: jump to it
        vim.api.nvim_win_set_cursor(0, { srow + 1, scol })
    else
        print("No function found after cursor.")
    end
end


local M = {}
M.setup = function()
    -- * gnf - aside, go to next function in file
    vim.keymap.set("n", "<leader>gfn", function()
        find_next_function_node()
    end, { desc = "go to next function" })
    vim.keymap.set("n", "<leader>gfp", function()
        -- TODO find_previous_function_node
    end, { desc = "go to previous function" })
end

return M
