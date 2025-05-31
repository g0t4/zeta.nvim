require('zeta.helpers.testing')
local tags = require('zeta.helpers.tags')
local should = require('devtools.tests.should')

--
-- * tests specific to the zeta model:
--   - prompt formulation
--   - prompt parsing

describe('zeta tags', function()
    it('adding editable start and end tags are put on their own lines', function()
        -- * start tag:
        -- https://github.com/zed-industries/zed/blob/5872276511/crates/zeta/src/input_excerpt.rs#L86
        --   writeln!(prompt, "{EDITABLE_REGION_START_MARKER}").unwrap();
        --
        --   uses `writeln` => for start tag =>
        --   THUS, start tag goes on a new line by itself ABOVE the excerpt text

        -- * end tag:
        -- https://github.com/zed-industries/zed/blob/5872276511/crates/zeta/src/input_excerpt.rs#L94
        --  write!(prompt, "\n{EDITABLE_REGION_END_MARKER}").unwrap();
        --  uses `write` => no trailing new line (intutively)
        --  but, note it prepends a new line before the end tag!
        --  THUS, tag goes on a new line by itself BELOW the excerpt text

        -- FYI might seem inconsequential but the model is fine tuned on specific examples
        --  and the closer I can make a request to consistent features of that SFT...
        --  the better the responses will be

        local lines = {
            'function add(a, b)',
            '    return a + b',
            'end',
        }

        tags.wrap_editable_tags(lines)
        local expected = {
            '<|editable_region_start|>',
            'function add(a, b)',
            '    return a + b',
            'end',
            '<|editable_region_end|>',
        }
        should.be_same(expected, lines)
    end)

    it('parsing editable region removes the newline associated with edit tags', function()
        local text =
        '<|editable_region_start|>\nfunction add(a, b)\n    return a + b\nend\n<|editable_region_end|>'

        local expected = 'function add(a, b)\n    return a + b\nend'

        local parsed = tags.get_editable_region(text)
        should.be_equal(expected, parsed)
    end)

    it('cursor position should literally be between consecutive chars with nothing added, no padding', function()
        local text = 'function add(a, b)\n    return a + b\nend'
        local cursor_position = 9 -- 0-indexed, 10 == 1-indexed (10th char)
        -- means 10th char has the cursor sitting on top of it (if block style cursor)
        -- when you use thin line, the cursor is on the let side of the block
        -- so when using block just remember the insertion point is to your left
        -- in vim:
        --   i = insert mode (first char is right under the cursor block)
        --   a = append mode (first char is right after the cursor block)
        -- TODO double check how zed does this
        -- TODO AND double check I didn't screw up the offsets! in 0/1 indexing (MADNESS)

        local tagged = tags.insert_cursor_tag(text, cursor_position)
        local expected_with_tag = 'function <|user_cursor_is_here|>add(a, b)\n    return a + b\nend'
        should.be_equal(expected_with_tag, tagged)
    end)

    it('cursor tag should be removed without touching any other characters', function()
        local text = 'function <|user_cursor_is_here|>add(a, b)\n    return a + b\nend'
        local expected = 'function add(a, b)\n    return a + b\nend'
        local cleaned = tags.strip_user_cursor_tag(text)
        should.be_equal(expected, cleaned)
    end)


    -- TODO! precise tests around start_of_file tag
end)
