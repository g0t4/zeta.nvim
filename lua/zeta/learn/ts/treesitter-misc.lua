require("devtools.inspect")
local messages = require("devtools.messages")

local M = {}

function M.learn_treesitter_node_APIs()
    -- :h treesitter-node
    messages.ensure_open()

    -- local node = vim.treesitter.get_node({ bufnr = 0, pos = vim.api.nvim_win_get_cursor(0) })
    local success, node = pcall(vim.treesitter.get_node, { bufnr = 0, pos = vim.api.nvim_win_get_cursor(0) })
    if not success then
        -- FYI node is error if status (ok) is false
        print("No node at cursor, pcall failed with error: " .. node)
        return
    end
    if node == nil then
        print("No node at cursor, node is nil")
        return
    end

    -- TODO! use this to get excerpt w/ a limited amount of words/tokens

    -- FYI vim.treesitter is avail in plenary tests OOB
    --   whereas ts_utils is not (can add package.path to get it working)
    --   USE vim.treesitter (it seems to be the suggested way, in the docs)
    --   docs mention:
    --     vim.treesitter.get_node_at_cursor()
    --       Use |vim.treesitter.get_node()|
    --       and |TSNode:type()| instead.

    -- dump.append("\nrange:", node:range()) -- not in a table
    messages.append("\nrange:", vim.treesitter.get_range(node)) -- table w/ start row/col/bytes, end row/col/bytes
    messages.append("\nid:", node:id())
    messages.append("\nhas_error (syntax):", node:has_error()) -- if node has syntax error, would be useful to pass!
    messages.append("\nhas_changes:", node:has_changes())
    messages.append("\nroot:", node:root())
    -- TODO node:root seems to be missing :type() and others?



    messages.append("\ntype:", node:type())
    --  identifier, escape_sequence, string_content, return_statement
    --  function_declaration (function/end), variable_declaration (local)
    --  block (inside function)
    messages.append("\nsymbol:", node:symbol())
    messages.append("\nchild_count:", node:child_count())

    -- dump.append("\nparent symbol:", node:parent():symbol())

    messages.append("\ntext:", vim.treesitter.get_node_text(node, 0))
    -- dump.append("\nparent text:", vim.treesitter.get_node_text(node:parent(), 0))
end

-- describe("gathering", function()
--     -- AFAICT cursor isn't positioned in plenary tests? in a buffer? how can I do real integration testing within nvim?
--     it("should get node at cursor", function()
--         get_excerpt_around_cursor()
--     end)
-- end)

return M
