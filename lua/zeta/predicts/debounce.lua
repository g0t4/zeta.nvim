local function debounce(fn, delay_ms)
    local timer = nil

    local function cancel()
        if timer then
            timer:stop()
            timer:close()
            timer = nil
        end
    end

    local function wrapped(...)
        cancel() -- cancel any previous timer
        local args = { ... }
        timer = vim.loop.new_timer()
        timer:start(delay_ms, 0, function()
            vim.schedule(function()
                fn(unpack(args))
            end)
        end)
    end

    return {
        call = wrapped,
        cancel = cancel,
    }
end

-- PRN return more than just function?
-- if so, can return table wtih __call set to debounce()
return debounce
