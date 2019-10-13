#!/bin/sh
# Cf. https://www.jessesquires.com/blog/swift-documentation-part-2/

jazzy \
    --author 'Anders Blehr' \
    --author_url 'https://twitter.com/andersblehr' \
    --github_url 'https://github.com/andersblehr/JSONCache' \
    --module 'JSONCache' \
    --source-directory . \
    --readme 'README.md' \
    --output docs/
