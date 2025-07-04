local M = {}

local config = nil

local config_path = vim.fn.stdpath('data') .. '/zeta.nvim/config.json'

local function file_exists(path)
    local file = io.open(path, 'r')
    if file then
        file:close()
        return true
    end
    return false
end

local function mkdir_p(path)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ':h'), 'p')
end

local function load_config()
    local default = { predictions_enabled = true }

    if file_exists(config_path) then
        local content = io.open(config_path, 'r'):read('*a')
        local ok, parsed = pcall(vim.json.decode, content)
        if ok and type(parsed) == 'table' then
            return vim.tbl_deep_extend('force', default, parsed)
        end
    else
        mkdir_p(config_path)
    end

    return default
end

local function save_config(data)
    local file = io.open(config_path, 'w')
    if file then
        file:write(vim.json.encode(data))
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
    -- FYI this is an example, copy and modify it to your liking!
    return {
        function()
            return 'ζ'
        end,
        color = function()
            local fg_color = ''
            if not M.is_enabled() then
                fg_color = '#333333'
            end
            return { fg = fg_color }
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
    vim.api.nvim_create_user_command('ZetaTogglePredictions', function()
        local state = M.toggle()
        print('Predictions ' .. (state and 'enabled' or 'disabled') .. ', please restart nvim to take effect')
    end, {})

    vim.api.nvim_create_user_command('ZetaStatus', function()
        if M.is_enabled() then
            print('Zeta predictions enabled')
        else
            print('Zeta predictions disabled')
        end
    end, {})
end

return M
