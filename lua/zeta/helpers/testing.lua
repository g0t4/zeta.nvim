-- setup select paths for running tests
local plugin_paths = {
    "~/repos/github/g0t4/devtools.nvim"
}
for _, path in ipairs(plugin_paths) do
    vim.opt.rtp:append(path)
end
-- local inspect = require("devtools.inspect")

function _describe(name, fn)
    -- FYI I tried overrding describe, but plenary is resetting the globals
    --   makes sense that each test set would be isolated
    --   so, just use my own "builder" for describing tests
    --   saves me from having to manually delineate each level...
    --     btw other, similar test runners do this automatically

    -- describe(name .. " ▶", fn) -- or whatever transformation you want
    -- describe(name .. " 🔹▫️◾️", fn) -- or whatever transformation you want end
    describe(name .. " -", fn) -- or whatever transformation you want end
    -- for now dash seems fine actually, leaving a few other ideas behind if not
end
