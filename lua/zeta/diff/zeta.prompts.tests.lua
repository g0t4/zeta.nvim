local tags = require("zeta.helpers.tags")
local should = require("zeta.helpers.should")

--
-- * tests specific to the zeta model:
--   - prompt formulation
--   - prompt parsing

describe("zeta tags", function()
    it("adding editable start and end tags are put on their own lines", function()
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
            "function add(a, b)",
            "    return a + b",
            "end",
        }

        tags.wrap_editable_tags(lines)
        local expected = {
            "<|editable_region_start|>",
            "function add(a, b)",
            "    return a + b",
            "end",
            "<|editable_region_end|>",
        }
        should.be_same(expected, lines)
    end)

    it("parsing editable region removes the newline associated with edit tags", function()
        local text =
        "<|editable_region_start|>\nfunction add(a, b)\n    return a + b\nend\n<|editable_region_end|>"

        local expected = "function add(a, b)\n    return a + b\nend"

        local parsed = tags.get_editable_region(text)
        should.be_equal(expected, parsed)
    end)

    it("TODO cursor position should literally be between consecutive chars with nothing added, no padding", function()

    end)
end)
