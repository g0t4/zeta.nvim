local files = require('zeta.helpers.files')
local should = require('zeta.helpers.should')

-- FYI run this with plenary!
-- :nmap <leader>u <Plug>PlenaryTestFile

describe('test sending 01_request.json', function()
    local body_json_serialized = files.read_example('01_request.json')
    -- print(body_json_serialized)

    it('should return output_excerpt', function()
        local url = 'http://localhost:9000/predict_edits'
        local result = vim.fn.system({
            'curl',
            '-H', 'Content-Type: application/json',
            '-X', 'POST',
            '-s', url,
            -- "-d", vim.fn.json_encode(request_body)
            '-d', body_json_serialized
        })
        print('## result:')
        print(result)
        print()

        local decoded = vim.fn.json_decode(result)
        local output_excerpt = decoded.output_excerpt
        assert(output_excerpt ~= nil, 'output_excerpt should not be nil')

        print('## output_excerpt:')
        print(output_excerpt)
        print()
    end)
end)



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

-- TODO

-- * server:
-- server.py for /predict_edits endpoint:
--   https://github.com/g0t4/zed-zeta-server
--
-- LMStudio works great too!
--   definitely slower than my 5090, par for the course ;)
--   tried 8bit model
-- vllm serve zed-industries/zeta --max-model-len 4096 --max-num-seqs 1
--   FYI model is 15.5GB so yeah! that's full precision
--   https://huggingface.co/zed-industries/zeta
-- quantized models:
--   https://huggingface.co/models?other=base_model:quantized:zed-industries/zeta
--   * LMSTUDIO has it! Q8_0, Q6_K, Q4_K_M, Q3_K_L
--     https://huggingface.co/lmstudio-community/zeta-GGUF
--   TRY WITH ollama / llama-server
--     https://huggingface.co/mradermacher/zeta-GGUF
--   mlx on mac:
--     mlx int8: https://huggingface.co/mlx-community/zed-industries-zeta-8bit
--     mlx fp16: https://huggingface.co/mlx-community/zed-industries-zeta-fp16
