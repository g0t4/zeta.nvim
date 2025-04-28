local assert = require("luassert")
local wesdiff = require("lua.zeta.copied.wesdiff")

-- -- FYI if I wanted to use vim.iter w/o plenary test runner...
-- -- it has no dependencies, so I can import it by path with loadfile
-- local iter = vim.iter or (loadfile("/opt/homebrew/Cellar/neovim/0.11.0/share/nvim/runtime/lua/vim/iter.lua")())
-- print(inspect(iter({ "foo", "bar", "bam" }):map(function(i) return i:reverse() end):totable()))

local SPLIT_ON_WHITESPACE = "%s+"
local STRIP_WHITESPACE = true

local function should_be_equal(expected, actual)
    assert.are.equal(expected, actual)
end

local function should_be_same(expected, actual)
    assert.are.same(expected, actual)
end

local function should_be_nil(actual)
    -- FYI you can join with _ instead of dot (.)
    --   must use this for keywords like nil, function, etc
    assert.is_nil(actual)
end

describe("tiny comparison with no leading/trailing comonality", function()
    local before_text = [[b )]]

    local after_text = [[b, c, d)]]

    it("splits words", function()
        -- FYI this is testing the inner details, but I wanna lock those in as the split matters
        -- leaving separator as whitespace default AND keeping separator
        -- IOTW no need to pass anything but first arg
        local before_tokens = wesdiff.split(before_text)
        should_be_same({ "b", " ", ")" }, before_tokens)

        local after_tokens = wesdiff.split(after_text)
        should_be_same({ "b,", " ", "c,", " ", "d)" }, after_tokens)
    end)

    it("computes lcs_matrix", function()
        local before_tokens = wesdiff.split(before_text)
        local after_tokens = wesdiff.split(after_text)

        local lcs_matrix = wesdiff.get_longest_common_subsequence_matrix(before_tokens, after_tokens)
    end)
end)

-- TODO! when done, would it be worth combining sequential tokens that are remove(out)/add(in)/same?
-- that would really help building extmarks to not have an extmark update per token (word)

describe("simple comparison", function()
    local before_text = [[
function M.add(a, b )
    return a + b
end
]]

    local after_text = [[
function M.add(a, b, c, d)
    return a + b
end
]]
end)

describe("my paper example", function()
    ---@format disablenext
    -- FYI whitespace is stripped out, so its only here to make this easier to read the before/after text
    local before_text = "C F A    D Z O    H Z C"
    local after_text = "F A C    F H G    D C O    Z"
    local before_tokens = wesdiff.split(before_text, SPLIT_ON_WHITESPACE, STRIP_WHITESPACE)
    local after_tokens = wesdiff.split(after_text, SPLIT_ON_WHITESPACE, STRIP_WHITESPACE)
    local longest_seq_if_prefer_match_up = { "C", "F", "D", "O", "Z" }
    local _longest_seq_if_prefer_match_left = { "F", "A", "D", "O", "Z" }

    it("splits words w/o separator", function()
        ---@format disable -- disables rest of lines in block
        -- true as last arg says to discard separator (I didn't do my paper example with space separators)
        should_be_same({ "C", "F", "A",    "D", "Z", "O",    "H", "Z", "C" }, before_tokens)
        should_be_same({ "F", "A", "C",    "F", "H", "G",    "D", "C", "O",    "Z" }, after_tokens)
    end)

    it("gets longest sequence", function()
        local longest_sequence = wesdiff.get_longest_sequence(before_tokens, after_tokens)
        should_be_same(longest_seq_if_prefer_match_up, longest_sequence)
    end)

    it("get token diff", function()
        -- * notes manually building expected result:
        -- start at lower right, 5 => not a match => move up implies `del C`
        -- now, on match (Z) => `same Z` => move up and left
        -- (4, not a match) => move up implies `del H`
        -- match(O) => `same O` => move up and left
        -- row5_Z/col8 => (3, not match) => prefer move up => implies `delZ`
        -- row4_D/col8 => (3, not match) => move left => implies `add C`
        -- row4_D/col7 => match(D) => `same D` => move up and left
        -- row3_A/col6 => (2, not match) => move up => implies `del A`
        -- row2_F/col6 => (2, not match) => move left => implies `add G`
        -- row2_F/col5 => (2, not match) => move left => implies `add H`
        -- row2_F/col4 => match(F) => `same F` => move up and left
        -- row1_C/col3 => match(C) => `same C` => move up and left
        -- row0/col2 => not a match, can't go up => move left => `add A`
        -- row0/col1 => not a match, can't go up => move left => `add F`
        -- row0/col0 => base case, done!
        local expected_token_diff_reversed = {
            { "del",  "C" }, -- move up
            { "same", "Z" }, -- match (move up and left)
            { "del",  "H" }, -- move up
            { "same", "O" }, -- match (move up and left)
            { "del",  "Z" }, -- move up
            { "add",  "C" }, -- move left
            { "same", "D" }, -- match (move up and left)
            { "del",  "A" }, -- move up
            { "add",  "G" }, -- move left
            { "add",  "H" }, -- move left
            { "same", "F" }, -- match (move up and left)
            { "same", "C" }, -- last match (move up and left)
            -- these are left moves (adds) after last match (row == 0, column > 0)
            { "add",  "A" }, -- move left
            { "add",  "F" }, -- move left
        }
        local expected_token_diff = vim.iter(expected_token_diff_reversed):rev():totable()

        local actual_token_diff = wesdiff.get_token_diff(before_tokens, after_tokens)

        should_be_same(expected_token_diff, actual_token_diff)
    end)

    it("get consolidated diff", function()
        local actual_diff = wesdiff.get_diff(before_tokens, after_tokens)
        -- TODO! expected vs actual diff
        --    consolidate consecutive changes that are same type, i.e. two adds between sames... or two deletes between sames
        --      sames are your checkpoint where you stop looking for consecutive changes to coalesce
    end)

    -- TODO! add a new test of actual_diff that has common prefix/suffix

    it("computes lcs matrix", function()
        local actual_lcs_matrix = wesdiff.get_longest_common_subsequence_matrix(before_tokens, after_tokens)

        ---@format disable -- disables rest of lines in block (so I can have 5 per split)
        -- columns:      1  2  3    4  5  6    7  8  9   10
        -- matches:            C                  C
        local row1_C = { 0, 0, 1,   1, 1, 1,   1, 1, 1,   1 }
        --               F          F
        local row2_F = { 1, 1, 1,   2, 2, 2,   2, 2, 2,   2 }
        --                  A
        local row3_A = { 1, 2, 2,   2, 2, 2,   2, 2, 2,   2 }


        --                                     D
        local row4_D = { 1, 2, 2,   2, 2, 2,   3, 3, 3,   3 }
        --                                                Z
        local row5_Z = { 1, 2, 2,   2, 2, 2,   3, 3, 3,   4 }
        --                                           O
        local row6_O = { 1, 2, 2,   2, 2, 2,   3, 3, 4,   4 }


        --                             H
        local row7_H = { 1, 2, 2,   2, 3, 3,   3, 3, 4,   4 }
        --                                                Z
        local row8_Z = { 1, 2, 2,   2, 3, 3,   3, 3, 4,   5 }
        --                     C                  C
        local row9_C = { 1, 2, 3,   3, 3, 3,   3, 4, 4,   5 }

        local expected_lcs_matrix = { row1_C, row2_F, row3_A, row4_D, row5_Z, row6_O, row7_H, row8_Z, row9_C }
        should_be_same(expected_lcs_matrix, actual_lcs_matrix)

        -- matches matrix:
        --   before[i] == after[j]
        --
        --             { _  _  C    _  _  _    _  C  _    _ }
        --             { F  _  _    F  _  _    _  _  _    _ }
        --             { _  A  _    _  _  _    _  _  _    _ }
        --             { _  _  _    _  _  _    D  _  _    _ }
        --             { _  _  _    _  _  _    _  _  _    Z }
        --             { _  _  _    _  _  _    _  _  O    _ }
        --             { _  _  _    _  H  _    _  _  _    _ }
        --             { _  _  _    _  _  _    _  _  _    Z }
        --             { _  _  C    _  _  _    _  C  _    _ }
        --
        --  added _ to see cols/rows, b/c of sparsity
        --
        -- only dumping match_matrix to compare to my manually created versions above
        -- local _match_matrix = wesdiff.get_match_matrix(before_tokens, after_tokens)
        -- print("match_matrix: ", inspect(match_matrix, true))
        -- FYI I can delete match matrix method in diff code.. that would be fine

        -- * just like doing a maze in reverse is easy, likewise with finding a longest sequence
        -- sequence comes from token matches only (match matrix, aka "same" tokens)
        --   matches are literally where before and after have the same token
        --     and is either the start of a sequence
        --     OR, a continuation of a prior sequence
        --   matches correspond to the letter comments I placed above each row
        --     imagine a separate matrix only with the letter comments, that's your "match matrix"
        --     in code, you check old_tokens[i] == new_tokens[j] to find these
        --     could've stored a tuple in each table cell but that just gets messy too!
        --       cheap to recompute, and you need to lookup the token on a match anyways!
        -- keep in mind, the incrementing #s indicate the order of the sequences...
        --   and, ONLY the longest sequences end in the max value 5
        --   whereas all sequences start with 1
        --   that's why we scan reverse (lower right to upper left)
        --   on a diagonal-ish pattern
        --   recursive seach where you are always looking for the last token in the longest sequence
        --     5 first => then 4th token in the matrix w/o the row&col that had 5th match
        --     then 3rd token
        --     then 2nd
        --     then 1st
        --  yes there can be multiple matches, for the longest, doesn't matter as long as you find one!
        --    difference is, when on a non-match cell, do you prefer moving up or left? either work
        --    move up == prefer to find an LCS closer to start of before_text
        --    move left = prefer to find an LCS closer to start of after_text
        --    can flip a coin, non-deterministic

    end)
end)


describe("diff with AA in before text, and only one A in after text", function()
    local before_text = "D F A A H"
    local after_text = "F A R F H"
    local before_tokens = wesdiff.split(before_text, SPLIT_ON_WHITESPACE, STRIP_WHITESPACE)
    local after_tokens = wesdiff.split(after_text, SPLIT_ON_WHITESPACE, STRIP_WHITESPACE)
    -- FTR, do not need to test split again

    it("should have LCS FAH, and not FAAH", function()
        local actual_lcs_matrix = wesdiff.get_longest_common_subsequence_matrix(before_tokens, after_tokens)

        ---@format disable -- disables rest of lines in block (so I can have 5 per split)
        -- matches:
        local row1_D = { 0, 0, 0,   0, 0 }
        --               F          F
        local row2_F = { 1, 1, 1,   1, 1 }
        --                  A
        local row3_A = { 1, 2, 2,   2, 2 }


        --                  A
        local row4_A = { 1, 2, 2,   2, 2 }
        --                             H
        local row5_H = { 1, 2, 2,   2, 3 }

        -- row4_A is where the AA back to back shows why the formula for a match is:
        --     row[j] = prev_row[j - 1] + 1
        --     and NOT: row[j] = prev_row[j] + 1
        --     otherwise you'd get FAAH
        --       and that's not in the after_text!

        local expected_lcs_matrix = { row1_D, row2_F, row3_A, row4_A, row5_H }
        should_be_same(expected_lcs_matrix, actual_lcs_matrix)

        -- * also check LCS
        local actual = wesdiff.get_longest_sequence(before_tokens, after_tokens)
        should_be_same({ "F", "A", "H" }, actual)
    end)
end)
