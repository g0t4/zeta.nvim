#!/bin/bash

set -x

# my LCS diff should look about like what you get with --color-words
#   at least as far as chagned sections are concerned, red/green
git diff --no-index --color-words 01_request.excerpt.md 01_response.excerpt.md


# --output-indicator-* can be used to hide +/-/' ' at start of lines (when doing line diff)
git diff --no-index --diff-algorithm patience --output-indicator-new "" --output-indicator-old "" --output-indicator-context "" 01_request.excerpt.md  01_response.excerpt.md
#   unfortunately, AFAICT you cannot set these with `git config`
