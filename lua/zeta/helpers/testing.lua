-- setup select paths for running tests
local plugin_paths = {
    '~/repos/github/g0t4/devtools.nvim'
}
for _, path in ipairs(plugin_paths) do
    vim.opt.rtp:append(path)
end
-- local inspect = require("devtools.inspect")

