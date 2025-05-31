require('zeta.helpers.testing')
local should = require('devtools.tests.should')
local histogram = require('zeta.diff.histogram')
local inspect = require('devtools.inspect')
local splitter = require('zeta.diff.splitter')


function ignore(a, b)
end
only = it
-- TODO! how can I make this more elegant?
-- it = ignore  -- uncomment to run "only" tests, otherwise, comment out to run all again (regardless if marked only/it)

_describe('test using histogram diff', function()
    it('with lines', function()
        local A = {
            'foo',
            'the cow',
            'the cow',
            'baz',
        }
        local B = {
            'the cow',
            'qux the flux',
            'the cow',
            'baz',
        }

        local expected = {
            { '-', 'foo' },
            { '=', 'the cow' },
            { '+', 'qux the flux' },
            { '=', 'the cow' },
            { '=', 'baz' },
        }
        local diff = histogram.diff(A, B)

        -- FYI this is example of NOT pretty printing nicely
        --   needs indentation, for first level (at least)
        --   but second level down, probably best to show each table as 1 line
        -- inspect.pretty_print(diff)

        should.be_same(expected, diff)
    end)

    -- FYI run this file with:
    --    nvim --headless -c 'PlenaryBustedFile lua/zeta/diff/histogram.tests.lua'

    it('diff stability - full example', function()
        local A = [[
            local function foo()
                print('foo')
            end
        ]]
        local B = [[
            local function bar()
                print('bar')
            end
        ]]
        local A_words = splitter.split_on_whitespace(A)
        -- inspect.pretty_print(A_words)
        local B_words = splitter.split_on_whitespace(B)
        local diff = histogram.diff(A_words, B_words)
        local expected_diff = {
            { '=', '' }, -- TODO why an empty chunk?
            { '=', '            ' },
            { '=', 'local' },
            { '=', ' ' },
            { '=', 'function' },
            { '=', ' ' },

            { '-', 'foo()' },
            { '+', 'bar()' },

            { '=', '\n                ' },

            { '-', "print('foo')" },
            { '+', "print('bar')" },

            { '=', '\n            ' },
            { '=', 'end' },
            { '=', '\n        ' },
        }
        should.be_same(expected_diff, diff)
    end)

    only('diff stability - first line only', function()
        local A = [[
            local function foo()]]
        local B = [[
            local function bar()]]
        local A_words = splitter.split_on_whitespace(A)
        -- inspect.pretty_print(A_words)
        local B_words = splitter.split_on_whitespace(B)
        local diff = histogram.diff(A_words, B_words)
        local expected_diff = {
            { '=', '' }, -- TODO why an empty chunk?
            { '=', '            ' },
            { '=', 'local' },
            { '=', ' ' },
            { '=', 'function' },
            { '=', ' ' },

            { '-', 'foo()' },
            { '+', 'bar()' },

        }
        should.be_same(expected_diff, diff)
    end)

    -- FYI need some better test cases to investigate diff stability, but it seems to be working
    it('diff stability - first two lines', function()
        local A = [[
            local function foo()
                print('foo')]]
        local B = [[
            local function bar()
                print('bar')]]
        local A_words = splitter.split_on_whitespace(A)
        -- inspect.pretty_print(A_words)
        local B_words = splitter.split_on_whitespace(B)
        local diff = histogram.diff(A_words, B_words)
        local expected_diff = {
            { '=', '' }, -- TODO why an empty chunk?
            { '=', '            ' },
            { '=', 'local' },
            { '=', ' ' },
            { '=', 'function' },
            { '=', ' ' },

            { '-', 'foo()' },
            { '+', 'bar()' },

            { '=', '\n                ' },

            { '-', "print('foo')" },
            { '+', "print('bar')" },
        }
        should.be_same(expected_diff, diff)
    end)
end)
