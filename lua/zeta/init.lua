local client = require("zeta.predicts.client")
local poc = require("zeta.learn.diff.poc")
local M = {}

function M.setup()
    poc.setup()
    client.setup()
end

return M
