local weslcs = require("zeta.diff.weslcs")
local combined = require("zeta.diff.combined")
local parser = require("zeta.helpers.response-parser")
local files = require("zeta.helpers.files")
local window = require("zeta.helpers.vimz.windows")
local gather = require("zeta.gather")


local M = {}

-- !!! right now this just shows a diff using extmarks, the basis of showing the prediction from the zeta model / predictions API server
function M.show_diff_extmarks()
    BufferDumpOpen()
    BufferDumpClear()

    -- local before, after = files.files_difftastic_ada()
    local before, after = files.request1_response2()
    BufferDumpAppend("before: " .. before)
    BufferDumpAppend("after: " .. after)

    -- * PICK WHICH DIFF (combined (histogram line level => weslcs word level) or just lcs (weslcs))
    -- local diff = combined.combined_diff(before, after)
    local diff = weslcs.lcs_diff_with_sign_types_from_text(before, after)
    BufferDumpAppend(diff)
    -- weslcs:   "same", "del", "add"
    -- combined: "=",    "-",   "+"
    M.extmarks_for(diff)
end
function M.setup()
    vim.keymap.set("n", "<leader>z", function()
        M.show_diff_extmarks()
    end, {})
    vim.keymap.set("n", "<leader>zg", function()
        gather.learn_treesitter_node_APIs()
    end, {})
end

return M
