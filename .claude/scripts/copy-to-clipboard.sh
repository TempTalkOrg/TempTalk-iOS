#!/bin/bash
# Copy content to clipboard
# Usage: ./copy-to-clipboard.sh "content"
printf '%s' "$1" | pbcopy
