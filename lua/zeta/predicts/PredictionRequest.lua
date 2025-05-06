local messages = require("devtools.messages")
local inspect = require("devtools.inspect")
local ExcerptSelector = require("zeta.predicts.ExcerptSelector")

---@alias PredictionDetails {
---   body: Body,
---   editable_start_line: integer,
---   editable_end_line: integer,
---   context_before_start_line: integer,
---   context_after_end_line: integer
---   cursor_line: integer,
---   cursor_col: integer,
---} | nil

---@class PredictionRequest
---@field window WindowController0Indexed
---@field details PredictionDetails
local PredictionRequest = {}
PredictionRequest.__index = PredictionRequest

---@class Body
---@field input_excerpt string
---@field input_events string
---@field outline string
-- TODO more fields

---@param request PredictionRequest
---@return PredictionDetails
local function build_request(request)
    local window = request.window
    local buffer = window:buffer()

    if not request.has_treesitter then
        -- use a line range "selector"
        -- local all_lines = buffer:get_all_lines()
        -- TODO take up to X lines initially... later measure chars as you expand out
        error("TODO finish selecting lines w/o treesitter, using line range")
    end

    local selector = ExcerptSelector:new(buffer)
    local row, col = window:get_cursor_position()
    local excerpt = selector:excerpt_at_position(row, col)
    if excerpt == nil then
        messages.append("excerpt not found, aborting...")
        return nil
    end
    messages.append("excerpt:")
    messages.append(excerpt)

    local num_lines         = buffer:num_lines()
    local end_after_line    = math.min(row + 3, num_lines)
    local start_before_line = math.max(excerpt.editable_start_line - 3, 0)

    -- TODO! TAGS now
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
    -- TODO prune large, initial editable region (func)
    -- TODO get surrounding context
    -- TODO handle start of file tag

    local body              = {
        input_excerpt = excerpt.text,
        input_events = "",
        outline = "",
    }
    return {
        body = body,
        context_before_start_line = start_before_line,
        editable_start_line = excerpt.editable_start_line,
        editable_end_line = excerpt.editable_end_line,
        context_after_end_line = end_after_line,
        cursor_line = row,
        cursor_col = col,
    }
end

function PredictionRequest:cancel()
    if self.task == nil then
        messages.append("no task to cancel")
        return
    end

    messages.append("sigterm'ing task...")
    -- PRN could use task:is_closing() to check if it's already closing?
    self.task:kill("sigterm")
    self.task = nil
end

---@param window WindowController0Indexed
function PredictionRequest:new(window, has_treesitter)
    self = setmetatable({}, PredictionRequest)
    self.has_treesitter = has_treesitter
    -- TODO rename details and/or re-org it
    self.window = window
    self.details = build_request(self)
    self.task = nil
    -- PRN if need be, track what is status:
    -- self.done = false
    -- self.canceled = false
    return self
end

--- a container to pass data when faking a request/response
---@param window WindowController0Indexed
---@param details PredictionDetails
function PredictionRequest:new_fake_request(window, details)
    self = setmetatable({}, PredictionRequest)
    self.window = window
    self.details = details
    return self
end

---@param on_response function
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
