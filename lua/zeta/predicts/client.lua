local files = require("zeta.helpers.files")

local body_json_serialized = files.read_example("01_request.json")
-- print(body_json_serialized)


-- local request_body = {
--
--     input_excerpt = ""
--
--     -- FYI on the backend I am only using input_excerpt and input_events, I need to find the template to use for outline/diagnostic_groups and speculated_output would be a vllm param to pass
--     -- PRN add other inputs:
--     -- outline = "",
--     -- input_events = "",
--     -- speculated_output = "",
--     -- diagnostic_groups = {}
--
--     -- DO NOT NEED:
--     -- can_collect_data = false,
-- }

local url = "http://build21:9000/predict_edits"
local result = vim.fn.system({
    "curl",
    "-H", "Content-Type: application/json",
    "-X", "POST",
    "-s", url,
    -- "-d", vim.fn.json_encode(request_body)
    "-d", body_json_serialized
})
print(result)

-- TODO

-- * server:
-- vllm serve zed-industries/zeta --max-model-len 4096 --max-num-seqs 1
--   FYI model is 15.5GB so yeah! that's full precision
--   https://huggingface.co/zed-industries/zeta
--   TODO try running a quantized version
--      https://huggingface.co/models?other=base_model:quantized:zed-industries/zeta
--   TODO try on mac:
--      mlx fp16: https://huggingface.co/mlx-community/zed-industries-zeta-fp16
