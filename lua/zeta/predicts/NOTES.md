

- Put my notes (i.e. design ideas) here so they dont waste tokens for predictions
  - or worse, mislead the model!

## ExcerptSelector:select_at_position

- TODOs
  - expand outward until hit a limit on editable range
    - THEN mark the editable range
    - THEN expand until we hit excerpt limit
  - insert cursor position
  - insert start of file if applicable

- for now, pass position, do not query it here (i.e. cursor position)

- initial idea => use the immediately enclosing function body (scope) as the editable range
  - reduce if it's a huge function body
- initial languages supported: lua, python, javascript... will do others as I have time

| language       | named funcs           | anonymous funcs          |
|----------------|-----------------------|--------------------------|
| lua            | function_declaration  | function_definition      |
| python         | function_definition   | lambda                   |
| javascript     | function_declaration  | function_expression      |
|                |                       | arrow_function           |

- Fortunately, they all seem to have a child `body` (I could search for that and grab its parent)
- FML... this is GAHHHHH
  - i.e. markdown files require entirely diff selection logic (and yet are still worth supporting)
      - markdown => `document` (root) => `section`
        - => (children: `atx_heading`, `paragraph`, `list`, `pipe_table`)
        - probably want to find nearest section and take its text
  - ultimately might have a set of selectors for related languages

- I suspect I can use node range as a proxy for text length?
  - if the latter is more expensive to obtain
- avoid taking partial lines, default to full lines in most cases should work nicely
- TODO revisit SFT/DPO training datasets for optimizing the selection logic
  - including look at how Zed does their selection
  - after I come up with my own basic idea, to avoid theirs biasing me prematurely
- personally I might want a way to mark comments that I don't need predictions to see...
  - i.e. these design trade off notes
  - strip them out when selecting excerpt but then add back in during diff?
  - the diff part would be tricky as I'd have to do two levels of diffing and yuck
  - for now the best idea is probably to keep those notes in separate files

