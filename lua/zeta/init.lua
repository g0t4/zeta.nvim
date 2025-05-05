local predictions = require("zeta.predicts.init")
local poc = require("zeta.learn.diff.poc")
local M = {}

function M.setup()
    poc.setup()
    predictions.setup()
end

return M
