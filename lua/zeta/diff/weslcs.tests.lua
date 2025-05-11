local _testing = require('zeta.helpers.testing')
local inspect = require('devtools.inspect')
local should = require('zeta.helpers.should')
local weslcs = require('zeta.diff.weslcs')
local splitter = require('zeta.diff.splitter')

_describe('tiny, no shared prefix/suffix words', function()
    local before_text = 'b )'
    local after_text = 'b, c, d)'

    it('splits words, keep whitespace', function()
        local before_tokens = splitter.split_on_whitespace(before_text)
        should.be_same({ 'b', ' ', ')' }, before_tokens)

        local after_tokens = splitter.split_on_whitespace(after_text)
        should.be_same({ 'b,', ' ', 'c,', ' ', 'd)' }, after_tokens)
    end)
end)

_describe('my paper example', function()
    ---@format disablenext
    -- FYI whitespace is stripped out, so its only here to make this easier to read the before/after text
    local before_text = 'C F A    D Z O    H Z C'
    local after_text = 'F A C    F H G    D C O    Z'
    local before_tokens = splitter.split_on_whitespace_then_skip_the_whitespace(before_text)
    local after_tokens = splitter.split_on_whitespace_then_skip_the_whitespace(after_text)
    local longest_seq_if_prefer_match_up = { 'C', 'F', 'D', 'O', 'Z' }
    local _longest_seq_if_prefer_match_left = { 'F', 'A', 'D', 'O', 'Z' }

    it('splits words w/o separator', function()
        ---@format disable -- disables rest of lines in block
        -- true as last arg says to discard separator (I didn't do my paper example with space separators)
        should.be_same({ "C", "F", "A",    "D", "Z", "O",    "H", "Z", "C" }, before_tokens)
        should.be_same({ "F", "A", "C",    "F", "H", "G",    "D", "C", "O",    "Z" }, after_tokens)
    end)

    it('gets longest sequence', function()
        local longest_sequence = weslcs.get_longest_sequence(before_tokens, after_tokens)
        should.be_same(longest_seq_if_prefer_match_up, longest_sequence)
    end)

    it('get token diff', function()
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
        local expected_token_diff = {
            { 'add',  'F' }, -- move left
            { 'add',  'A' }, -- move left
            -- these are left moves (adds) after last match (row == 0, column > 0)
            { 'same', 'C' }, -- last match (move up and left)
            { 'same', 'F' }, -- match (move up and left)
            { 'add',  'H' }, -- move left
            { 'add',  'G' }, -- move left
            { 'del',  'A' }, -- move up
            { 'same', 'D' }, -- match (move up and left)
            { 'add',  'C' }, -- move left
            { 'del',  'Z' }, -- move up
            { 'same', 'O' }, -- match (move up and left)
            { 'del',  'H' }, -- move up
            { 'same', 'Z' }, -- match (move up and left)
            { 'del',  'C' }, -- move up
        }

        local actual_token_diff = weslcs.get_token_diff(before_tokens, after_tokens)

        should.be_same(expected_token_diff, actual_token_diff)
    end)

    it('get aggregated diff', function()
        local actual_diff = weslcs.lcs_diff_from_tokens(before_tokens, after_tokens)
        -- consolidate consecutive sames
        -- and consolidate all adds between sames
        -- and consolidate all dels between sames
        -- PRESERVE ORDER within consecutive tokens of a given type
        local expected_token_diff = {
            { 'add',  'FA' },
            { 'same', 'CF' },
            { 'del',  'A' },
            { 'add',  'HG' },
            { 'same', 'D' },
            { 'del',  'Z' },
            { 'add',  'C' },
            { 'same', 'O' },
            { 'del',  'H' },
            { 'same', 'Z' },
            { 'del',  'C' },
        }

        should.be_same(expected_token_diff, actual_diff)
    end)

    it('computes lcs matrix', function()
        local actual_lcs_matrix = weslcs.get_longest_common_subsequence_matrix(before_tokens, after_tokens)

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
        should.be_same(expected_lcs_matrix, actual_lcs_matrix)

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
        -- local _match_matrix = weslcs.get_match_matrix(before_tokens, after_tokens)
        print("match_matrix: ", inspect(match_matrix, { pretty = true }))
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


_describe('AA in before, only one A in after', function()
    local before_text = 'D F A A H'
    local after_text = 'F A R F H'
    local before_tokens = splitter.split_on_whitespace_then_skip_the_whitespace(before_text)
    local after_tokens = splitter.split_on_whitespace_then_skip_the_whitespace(after_text)

    it('should have LCS FAH, not FAAH', function()
        local actual_lcs_matrix = weslcs.get_longest_common_subsequence_matrix(before_tokens, after_tokens)

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
        should.be_same(expected_lcs_matrix, actual_lcs_matrix)

        -- * also check LCS
        local actual = weslcs.get_longest_sequence(before_tokens, after_tokens)
        should.be_same({ "F", "A", "H" }, actual)
    end)
end)

_describe('strip shared suffix/prefix before LCS diff', function()
    describe('prefix & suffix have overlap', function()
        local before_text = 'F A B C D E F G'
        local after_text = 'F A C D E X F G'

        it('extracts non-overlapping middle tokens', function()
            -- FYI before_tokens/after_tokens are changed in-place during suffix/prefix extraction... so must setup in each test method separatley
            local before_tokens = splitter.split_on_whitespace_then_skip_the_whitespace(before_text)
            local after_tokens = splitter.split_on_whitespace_then_skip_the_whitespace(after_text)

            -- FTR, do not need to test split again
            local expected_middle = {
                before_tokens = { 'B', 'C', 'D', 'E' },
                after_tokens = { 'C', 'D', 'E', 'X' },
            }

            local same_prefix, middle, same_suffix = weslcs.split_common_prefix_and_suffix(before_tokens, after_tokens)

            should.be_same({ 'same', 'FA' }, same_prefix)
            should.be_same({ 'same', 'FG' }, same_suffix)
            should.be_same(expected_middle, middle)
        end)


        it('get_diff includes shared prefix/suffix', function()
            -- FYI! before_tokens/after_tokens are changed in-place during suffix/prefix extraction... so must setup in each test method separatley
            local before_tokens = splitter.split_on_whitespace_then_skip_the_whitespace(before_text)
            local after_tokens = splitter.split_on_whitespace_then_skip_the_whitespace(after_text)

            local actual_diff = weslcs.lcs_diff_from_tokens(before_tokens, after_tokens)
            local expected_diff = {
                -- shared prefix:
                { 'same', 'FA' },

                { 'del',  'B' },
                { 'same', 'CDE' },
                { 'add',  'X' },

                -- shared suffix
                { 'same', 'FG' },
            }
            should.be_same(expected_diff, actual_diff)
        end)
    end)

    describe('no shared suffix, nor prefix', function()
        it('diff works', function()
            local before_text = 'B C B'
            local after_text = 'A C A'
            local before_tokens = splitter.split_on_whitespace_then_skip_the_whitespace(before_text)
            local after_tokens = splitter.split_on_whitespace_then_skip_the_whitespace(after_text)

            local expected_diff = {
                { 'del',  'B' },
                { 'add',  'A' },
                { 'same', 'C' },
                { 'del',  'B' },
                { 'add',  'A' },
            }

            local actual_diff = weslcs.lcs_diff_from_tokens(before_tokens, after_tokens)

            should.be_same(expected_diff, actual_diff)
        end)
    end)

    describe('both sequences match 100%', function()
        it('returns all under same_suffix', function()
            local before_text = 'A B C D'
            local after_text = 'A B C D'
            local before_tokens = splitter.split_on_whitespace_then_skip_the_whitespace(before_text)
            local after_tokens = splitter.split_on_whitespace_then_skip_the_whitespace(after_text)

            local expected_middle = {
                before_tokens = {},
                after_tokens = {},
            }

            local same_prefix, middle, same_suffix = weslcs.split_common_prefix_and_suffix(before_tokens, after_tokens)

            -- FYI doesn't matter if I expect them to be in prefix or suffix, just need to validate I do one of the two
            should.be_same({ 'same', '' }, same_prefix) -- TODO what do I want here? nil? "" (emtpy)? {} empty table?
            should.be_same({ 'same', 'ABCD' }, same_suffix)
            should.be_same(expected_middle, middle)
        end)
    end)
end)

_describe('can convert to sign types', function()
    local before_text = 'B C B'
    local after_text = 'A C A'

    it('setup is as expected', function()
        -- *** INCLUDES SPACES as WORDS
        --   SO, the same sequenceds above won't match... b/c those strip space separators
        -- intermediate token diff:
        local expected_token_diff = {
            { 'add',  'A' },
            { 'del',  'B' },
            { 'same', ' ' },
            { 'same', 'C' },
            { 'same', ' ' },
            { 'add',  'A' },
            { 'del',  'B' },
        }
        local token_diff = weslcs.get_token_diff(splitter.split_on_whitespace(before_text), splitter.split_on_whitespace(after_text))
        should.be_same(expected_token_diff, token_diff)

        -- FYI LCS is " C " which is obvious here:
        local expected_diff = {
            { 'del',  'B' },
            { 'add',  'A' },
            { 'same', ' C ' },
            { 'del',  'B' },
            { 'add',  'A' },
        }

        -- * HONESTLY its fine to just test the final aggregated diff (can skip token diff above):
        local actual_diff = weslcs.lcs_diff_from_text(before_text, after_text)

        should.be_same(expected_diff, actual_diff)
    end)

    it('here are the add/del/same', function()
        local expected_diff = {
            { '-', 'B' },
            { '+', 'A' },
            { '=', ' C ' },
            { '-', 'B' },
            { '+', 'A' },
        }

        local actual_diff = weslcs.lcs_diff_with_sign_types_from_text(before_text, after_text, true)

        should.be_same(expected_diff, actual_diff)
    end)
end)
