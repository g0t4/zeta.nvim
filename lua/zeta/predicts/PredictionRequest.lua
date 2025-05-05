local messages = require("devtools.messages")
local inspect = require("devtools.inspect")

---@class PredictionRequest
local PredictionRequest = {}
PredictionRequest.__index = PredictionRequest

---@param window WindowController0Indexed
local function build_request(window)
    local buffer = window:buffer()

    local bufnr = buffer.buffer_number

    -- step one, take the whole enchilada!
    -- local all_lines = buffer:get_all_lines()

    local excerpt = window:get_excerpt_text_at_cursor()
    messages.header("excerpt:")
    messages.append(inspect(excerpt))
    if excerpt == nil then
        messages.header("excerpt not found, aborting...")
        return
    end

    --
    -- -- insert cursor position tag
    -- local editable = tags.mark_editable_region(excerpt, row, col)
    -- -- TODO
    -- messages.header("editable:")
    -- messages.append(inspect(editable))
    --
    -- local editable_text = table.concat(editable, "\n")
    -- messages.header("editable_text:")
    -- messages.append(editable_text)
    --
    -- TODO get real file content, and the rest is ready to go!
    -- TODO later, get editable vs surrounding context
    -- TODO handle start of file tag
    -- TODO track position of start of region so you can align it when the response comes back
    --   put into the request object (not the body) so you can use it in response handler
    --
    -- use treesitter (if available), otherwise fallback to line ranges

    -- local body = files.read_example_json("01_request.json")
    local body = {
        input_excerpt = excerpt,
        -- input_events
        -- outline
    }

    return {
        bufnr = bufnr,
        body = body,
        -- body = {
        --     input_excerpt = "",
        --     -- input_events
        --     -- outline
        -- }
        excerpt_start_line_0indexed = 0,
        excerpt_start_column_0indexed = 0,
        -- excerpt_end_line = #lines,
        -- ...
        -- editable start/end too, whatever is needed...
        -- ...save it so you don't to reverse engineer it
    }
end

function PredictionRequest:cancel()
    if self.task == nil then
        return
    end

    -- PRN could use task:is_closing() to check if it's already closing?
    self.task:kill("sigterm")
    self.task = nil
end

function PredictionRequest:new(window)
    self = setmetatable({}, PredictionRequest)
    -- TODO rename details and/or re-org it
    self.window = window
    self.details = build_request(window)
    self.task = nil
    -- PRN if need be, track what is status:
    -- self.done = false
    -- self.canceled = false
    return self
end

function PredictionRequest:send(on_response)
    -- PRN how can I handle errors? pcall?
    function make_request()
        local url = "http://localhost:9000/predict_edits"
        local command = {
            "curl",
            "-fsSL", -- -S is key to getting error messages (and not just silent failures! w/ non-zero exit code)
            -- keep in mind, don't want verbose output normally as it will muck up receiving response body
            -- FYI if want stream response, add --no-buffer to curl else it batches output
            "-H", "Content-Type: application/json",
            "-X", "POST",
            "-s", url,
            "-d", vim.fn.json_encode(self.details.body)
        }

        messages.header("curl command")
        messages.append(inspect(command, { pretty = true }))

        self.task = vim.system(command,
            {
                text = true,
                -- since I am not streaming reponse, I will leave defaults such that
                --   stdout/stderr are returned in the on_exit callback
                --   btw stdout/stderr = true by default, can set false to discard
                --
                -- stdout = function(err, data)
                --     vim.schedule(function()
                --         if err ~= nil then
                --             dump.header("STDOUT error:" .. err)
                --         end
                --         dump.header("STDOUT data:" .. (data or ""))
                --     end)
                -- end,
                -- stderr = function(err, data)
                --     vim.schedule(function()
                --         if err ~= nil then
                --             dump.header("STDERR error:" .. err)
                --         end
                --         dump.header("STDERR data:" .. (data or ""))
                --     end)
                -- end,
                -- timeout = ? seconds? ms? default is?
            },
            on_exit_curl
        )
    end

    function on_exit_curl(result)
        self.task = nil -- immediately clear it or leave it?

        -- vim.SystemCompleted (code, signal, stdout, stderr)
        vim.schedule(function()
            if result.code ~= 0 then
                -- test failure with wrong URL
                messages.header("curl on_exit:  " .. inspect(result))
            end
            -- if result.stderr ~= "" then
            --     dump.header("STDERR:", result.stderr)
            -- end
            if result.stdout ~= "" then
                messages.header("STDOUT:", result.stdout)
                on_response(self, result.stdout)
            end
        end)
    end

    local ok, err = pcall(make_request)
    if not ok then
        -- this happens when command (curl) is not found
        messages.header("prediction request failed immediately:")
        messages.append(inspect(err))
    end
end

return PredictionRequest
