<|editable_region_start|>
local M = {}

function M.adder(a, b)
    return a + b
end

function M.subtract(a, b)
    return a - b
end

function M.multiply(a, b)
    return a * b
end

function M.divide(a, b)
    if b == 0 then
        error("Division by zero")
    end
    return a / b
end



return M

<|editable_region_end|>
```

