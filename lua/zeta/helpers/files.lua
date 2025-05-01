local parser = require("zeta.helpers.response-parser")

local M = {}

--- Returns the absolute path of a file relative to the examples directory.
---@param relative_path string
---@return string absolute_path
local function get_path_relative_to_examples_dir(relative_path)
    local info = debug.getinfo(1, "S")
    -- zeta.nvim/lua/zeta/helpers/files.lua
    -- zeta.nvim/lua/zeta/learn/examples/
    BufferDumpAppend(info)
    local this_module_path = info.source:sub(2) -- remove the @
    BufferDumpAppend("this_module", this_module_path)
    local zeta_dir_path = this_module_path:match("(.*/)helpers/files.lua")
    BufferDumpAppend("dir", zeta_dir_path)
    return zeta_dir_path .. "learn/examples/" .. relative_path
end

--- Reads the content of an example file.
---@param relative_path string
---@return string content
function M.read_example(relative_path)
    local repo_path = get_path_relative_to_examples_dir(relative_path)
    local content, err = M.read_file(repo_path)
    if not content then
        error("Cannot read file: " .. repo_path .. ", error: " .. err)
    end
    return content
end

--- Reads the entire content of a file into a single string.
---@param path string
---@return string content
function M.read_file(path)
    local file, err = io.open(path, "r")
    if not file then
        error("Cannot open file: " .. path .. ", error: " .. err)
    end

    local content = file:read("*a")
    file:close()
    return content
end

--- Reads the entire content of a file into a list of lines
---@param path string
---@return string[] lines
function M.read_lines(path)
    local file, err = io.open(path, "r")
    if not file then
        error("Cannot open file: " .. path .. ", error: " .. err)
    end

    local lines = {}
    for line in file:lines() do
        table.insert(lines, line)
    end
    file:close()
    return lines
end

function M.read_example_json_excerpt(relative_path)
    local repo_path = get_path_relative_to_examples_dir(relative_path)
    local content, err = M.read_file(repo_path)
    if not content then
        error("Cannot read file: " .. repo_path .. ", error: " .. err)
    end

    -- btw the md excerpt files are mostly intended for me to use with diff tools...
    --  consider json files as definitive source of truth
    local body = vim.json.decode(content)
    if body.input_excerpt then
        return body.input_excerpt
    elseif body.output_excerpt then
        return body.output_excerpt
    end

    error("file is missing both input_excerpt and output_excerpt: " .. relative_path)
end

--- extract just the content inside of <|editable_region_start|> tags
function M.read_example_editable_only(relative_path)
    local json_excerpt = M.read_example_json_excerpt(relative_path)
    local editable = parser.get_editable(json_excerpt)
    if not editable then
        error("couldn't find editable in excerpt: " .. relative_path)
    end
    return editable
end

return M
