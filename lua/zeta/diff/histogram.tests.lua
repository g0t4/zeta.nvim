require('zeta.helpers.testing')
local should = require('zeta.helpers.should')
local histogram = require('zeta.diff.histogram')
local inspect = require('devtools.inspect')
local weslcs = require('zeta.diff.weslcs')
local combined = require('zeta.diff.combined')

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
        local A_words = weslcs.split(A)
        -- inspect.pretty_print(A_words)
        local B_words = weslcs.split(B)
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

    it('diff stability - first line only', function()
        local A = [[
            local function foo()]]
        local B = [[
            local function bar()]]
        local A_words = weslcs.split(A)
        -- inspect.pretty_print(A_words)
        local B_words = weslcs.split(B)
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


    it('diff stability - first two lines', function()
        local A = [[
            local function foo()
                print('foo')]]
        local B = [[
            local function bar()
                print('bar')]]
        local A_words = weslcs.split(A)
        -- inspect.pretty_print(A_words)
        local B_words = weslcs.split(B)
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
