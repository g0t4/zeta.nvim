local M = {}

local config = nil

local json = vim.fn.json_encode and vim.fn.json_decode and {
    encode = vim.fn.json_encode,
    decode = vim.fn.json_decode,
} or require("vim.json")

local config_path = vim.fn.stdpath("data") .. "/zeta/config.json"

local function file_exists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

local function mkdir_p(path)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
end

local function load_config()
    local default = { predictions_enabled = true }

    if file_exists(config_path) then
        local content = io.open(config_path, "r"):read("*a")
        local ok, parsed = pcall(json.decode, content)
        if ok and type(parsed) == "table" then
            return vim.tbl_deep_extend("force", default, parsed)
        end
    else
        mkdir_p(config_path)
    end

    return default
end

local function save_config(data)
    local file = io.open(config_path, "w")
    if file then
        file:write(json.encode(data))
        file:close()
    end
end

function M.get()
    if not config then
        config = load_config()
    end
    return config
end

function M.save()
    if config then
        save_config(config)
    end
end

function M.lualine()
    return {
        function()
            return "ζ"
        end,
        color = function()
            -- FYI can take section param to know which section this is in
            -- empty == use current component color, that's probably best
            -- #33aa88 is a nice green if I wanna go that route again
            -- PRN do I need to match the inverse default color for when it's disabled?
            return { fg = M.is_enabled() and '' or '#333333' }
        end,
    }
end

function M.is_enabled()
    return M.get().predictions_enabled
end

function M.toggle()
    local cfg = M.get()
    cfg.predictions_enabled = not cfg.predictions_enabled
    M.save()
    return cfg.predictions_enabled
end

function M.setup()
    vim.api.nvim_create_user_command("ZetaTogglePredictions", function()
        local state = M.toggle()
        print("Predictions " .. (state and "enabled" or "disabled") .. ", please restart nvim to take effect")
    end, {})

    vim.api.nvim_create_user_command("ZetaStatus", function()
        if M.is_enabled() then
            print("Zeta predictions enabled")
        else
            print("Zeta predictions disabled")
        end
    end, {})
end

return M
