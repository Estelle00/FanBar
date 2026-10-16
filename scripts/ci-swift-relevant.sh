#!/usr/bin/env bash
# Prints "swift=true|false" for $GITHUB_OUTPUT: whether a pull request touches anything the
# macOS build, tests or packaging can see. Non-PR events always build (main refreshes the
# coverage baseline; tags release). Usage: ci-swift-relevant.sh <event> <base-sha> <head-sha>
set -euo pipefail
event=${1:?event}; base=${2:-}; head=${3:-}
if [[ "$event" != "pull_request" ]]; then echo "swift=true"; exit 0; fi
# Everything else, including contracts/ and the Worker's src/, migrations and config (the
# native integration tests run against it), still triggers the macOS jobs.
ignored='^(docs/|.*\.md$|LICENSE$|\.github/ISSUE_TEMPLATE/|services/compatibility/(web|test)/|\.github/workflows/(compatibility-service|download-badge|homebrew)\.yml$)'
relevant=$(git diff --name-only "$base...$head" | grep -Ev "$ignored" || true)
if [[ -n "$relevant" ]]; then
  { echo "Swift-relevant changes:"; echo "$relevant"; } >&2
  echo "swift=true"
else
  echo "Only documentation, Worker web/tests or unrelated workflows changed; skipping macOS jobs." >&2
  echo "swift=false"
fi
