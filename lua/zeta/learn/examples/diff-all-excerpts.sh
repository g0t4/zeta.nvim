#!/bin/bash

set -x

echo "01 request vs 01 response:"
icdiff 01_request.excerpt.md 01_response.excerpt.md
icdiff 01_request.excerpt.md 02_response.excerpt.md
icdiff 01_request.excerpt.md 03_response.excerpt.md

echo "## response differences:"
icdiff 01_response.excerpt.md 02_response.excerpt.md
icdiff 02_response.excerpt.md 03_response.excerpt.md
icdiff 01_response.excerpt.md 03_response.excerpt.md
