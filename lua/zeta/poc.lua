local weslcs = require("zeta.diff.weslcs")
local combined = require("zeta.diff.combined")
local parser = require("zeta.helpers.tags")
local files = require("zeta.helpers.files")
local windows = require("zeta.helpers.vimz.windows")
local gather = require("zeta.gather")
local extmarks = require("zeta.diff.extmarks")
local dump = require("helpers.dump")

local M = {}

-- !!! right now this just shows a diff using extmarks, the basis of showing the prediction from the zeta model / predictions API server
function M.show_diff_extmarks()
    dump.ensure_open()
    dump.clear()

    -- local before, after = files.files_difftastic_ada()
    local before, after = files.request1_response2()

    -- * PICK WHICH DIFF (combined (histogram line level => weslcs word level) or just lcs (weslcs))
    -- local diff = combined.combined_diff(before, after)
    local diff = weslcs.lcs_diff_with_sign_types_from_text(before, after)
    dump.append(diff)
    -- weslcs:   "same", "del", "add"
    -- combined: "=",    "-",   "+"
    local bufnr, _window_id = dump.get_ids()
    extmarks.extmarks_for(diff, bufnr, _window_id)
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
