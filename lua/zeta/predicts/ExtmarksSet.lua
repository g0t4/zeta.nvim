---@class ExtmarksSet
---@field buffer_number number
---@field namespace_id number
local ExtmarksSet = {}
ExtmarksSet.__index = ExtmarksSet

-- * ExtmarksSet - a collection of extmarks, by Namespace!
--  maybe:
--   predition_marks = buffer:extmarks(prediction_ns)
--   prediction_marks:get(mark_id, {})
--   prediction_marks:set(mark_id, {})
--   prediction_marks:clear_all()

---@param buffer_number integer
---@param namespace_id integer
---@return ExtmarksSet
function ExtmarksSet:new(buffer_number, namespace_id)
    self = setmetatable({}, ExtmarksSet)
    self.buffer_number = buffer_number
    self.namespace_id = namespace_id

    -- PRN mark_ids is tentative, not sure it needs stored in a list
    --  instead, might have an Extmark class that encapsulates the mark_id
    --  that consumers can hold a ref to and use to update it
    -- self.mark_ids = {}
    --  OR store Extmark objects in a list?
    --  self.extmarks = {}

    return self
end

function ExtmarksSet:clear_all()
    -- FYI 0 => -1 == all lines
    vim.api.nvim_buf_clear_namespace(self.buffer_number, self.namespace_id, 0, -1)
end

--- get an extmark by id
--- @param mark_id integer
---@return vim.api.keyset.get_extmark_item_by_id # 0-indexed (row, col) tuple or empty list ()
function ExtmarksSet:get(mark_id)
    -- FYI probably it's more useful to cache this in the consumer, unless multiple consumers can change it
    return vim.api.nvim_buf_get_extmark_by_id(self.buffer_number, self.namespace_id, mark_id, {})
end

--- create OR update (i.e. move) an existing mark
--- @param mark_id integer
--- @param opts table
---@return integer mark_id # useful if you didn't provide a mark_id and want the generated id
function ExtmarksSet:set(mark_id, opts)
    -- PRN how about create helpers for different types of marks that I commonly use?
    --   then can make params for required args? and map to opts

    -- PRN pass in opts too?
    opts.id = mark_id

    -- TODO is it useful to pass start line/col in opts?
    local start_line = opts.start_line or 0
    local start_col = opts.start_col or 0
    opts.start_line = nil
    opts.start_col = nil


    return vim.api.nvim_buf_set_extmark(
        self.buffer_number, self.namespace_id,
        start_line, start_col,
        opts)
end

function ExtmarksSet:highlight_lines(opts)
    assert(opts.id, 'must provide an id')
    assert(opts.hl_group, 'must provide an hl_group')
    assert(opts.start_line, 'must provide a start_line')
    -- assert(opts.start_col, "must provide a start_col")
    assert(opts.end_line, 'must provide an end_line')
    -- assert(opts.end_col, "must provide an end_col")

    local start_line = opts.start_line or 0
    local start_col = opts.start_col or 0
    opts.start_line = nil
    opts.start_col = nil


    return vim.api.nvim_buf_set_extmark(
        self.buffer_number, self.namespace_id,
        start_line, start_col,
        opts)
end

-- ok I am headed in direction of breaking the diff out into a series of changes to accept/reject
-- I might even try to color over the existing text (that was preserved and strike out removed/insert green for now.. text)
-- I doubt I will go so far as to hide all but the current "chunk" of the diff... but I might do that too... I suppose that might make it easier to show the diff chunk by chunk?

local hl_strike = 'zeta-strike'
vim.api.nvim_set_hl(0, hl_strike, {
    strikethrough = true,
})

--- this strikes an entire line range, as if removed in a diff
--- @param start_line integer
--- @param end_line integer # end-exclusive
function ExtmarksSet:diff_strike_lines(start_line, end_line)
    return vim.api.nvim_buf_set_extmark(
        self.buffer_number, self.namespace_id,
        start_line, 0,
        {
            hl_group = { 'DiffDelete', hl_strike },
            end_line = end_line,
            end_col = 0,
        })
end

return ExtmarksSet
