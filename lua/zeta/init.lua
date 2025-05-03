local client = require("zeta.predicts.client")
local poc = require("zeta.learn.diff.poc")
local dump = require("helpers.dump")
local M = {}

function M.setup()
    poc.setup()
    client.setup()
end

return M
