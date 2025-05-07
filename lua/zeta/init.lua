local predictions = require("zeta.predicts.init")
local poc = require("zeta.learn.diff.poc")
local config = require("zeta.config")
local M = {}

function M.setup()
    poc.setup()
    predictions.setup()
    config.setup()
end

return M
