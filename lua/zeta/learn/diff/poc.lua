local weslcs = require("zeta.diff.weslcs")
local combined = require("zeta.diff.combined")
local files = require("zeta.helpers.files")
local extmarks = require("zeta.diff.extmarks")
local messages = require("devtools.messages")

local M = {}

function M.show_diff_extmarks()
    -- this was an early prototype to test showing a diff with extmarks
    -- FYI this can be removed

    messages.ensure_open()
    -- dump.clear()

    -- local before, after = files.files_difftastic_ada()
    local before, after = files.request1_response2()

    -- * PICK WHICH DIFF (combined (histogram line level => weslcs word level) or just lcs (weslcs))
    -- local diff = combined.combined_diff(before, after)
    local diff = weslcs.lcs_diff_with_sign_types_from_text(before, after)
    messages.append(diff)
    -- weslcs:   "same", "del", "add"
    -- combined: "=",    "-",   "+"
    local bufnr, _window_id = messages.get_ids()
    extmarks.extmarks_for(diff, bufnr, _window_id)
end

function M.setup()
    vim.keymap.set("n", "<leader>z", function()
        M.show_diff_extmarks()
    end, {})
end

return M
