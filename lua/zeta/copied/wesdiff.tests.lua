local assert = require("luassert")
local wesdiff = require("lua.zeta.copied.wesdiff")

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
    local before_text = "C F A D Z O H Z C"
    local after_text = "F A C F H G D C O Z"
    local before_tokens = wesdiff.split(before_text, " ", true)
    local after_tokens = wesdiff.split(after_text, " ", true)

    it("splits words w/o separator", function()
        ---@format disable -- disables rest of lines in block
        -- true as last arg says to discard separator (I didn't do my paper example with space separators)
        should_be_same({ "C", "F", "A",    "D", "Z", "O",    "H", "Z", "C" }, before_tokens)
        should_be_same({ "F", "A", "C",    "F", "H", "G",    "D", "C", "O",    "Z" }, after_tokens)
    end)

    it("gets longest sequence", function()
        -- FUCK YEAH WORKED THE FIRST TIME MOTHER FUCKER!
        local longest_sequence = wesdiff.get_longest_sequence(before_tokens, after_tokens)
        print(inspect(longest_sequence))
    end)

    it("gets diff", function()
        -- get_diff(before_text, after_text, separator, keep_separator)
    end)

    it("computes lcs matrix", function()
        local lcs_matrix = wesdiff.get_longest_common_subsequence_matrix(before_tokens, after_tokens)
        print("lcs_matrix", inspect(lcs_matrix, true))
        local match_matrix = wesdiff.get_match_matrix(before_tokens, after_tokens)
        print("match_matrix: ", inspect(match_matrix, true))

        ---@format disable -- disables rest of lines in block (so I can have 5 per split)
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
        --   FYI added _ to see cols/rows, b/c of sparsity


        -- longest sequences (just need one of these):
        --   depending on how I recursively reverse scan for longest match, I could get either:
        local seq_cf5 = { "C", "F", "D", "O", "Z" }
        local seq_fa5 = { "F", "A", "D", "O", "Z" }
        -- * just like doing a maze in reverse is easy, likewise with finding a longest sequence
        -- sequence comes from token matches only (aka "same" tokens, unchanged)
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
        --     5 first => then 4th token in the matrix w/o the row/col that had 5th match
        --     then 3rd token
        --     then 2nd
        --     then 1st
        --  yes there can be multiple matches, for the longest, doesn't matter as long as you find one!

    end)
end)


describe("diff with AA in before text, and only one A in after text", function()
    local before_text = "D F A A H"
    local after_text = "F A R F H"
    local before_tokens = wesdiff.split(before_text, " ", true)
    local after_tokens = wesdiff.split(after_text, " ", true)
    -- FTR, do not need to test split again

    it("should have LCS FAH, and not FAAH", function()
        local lcs_matrix = wesdiff.get_longest_common_subsequence_matrix(before_tokens, after_tokens)

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

    end)
end)
