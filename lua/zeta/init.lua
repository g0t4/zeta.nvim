local predictions = require('zeta.predicts.init')
local poc = require('zeta.learn.diff.poc')
local config = require('zeta.config')
local logs = require('zeta.helpers.logs')
local M = {}

function M.setup()
    config.setup()
    if config.is_enabled() then
        poc.setup()
        predictions.setup()
        logs.setup()
    end
end

return M
