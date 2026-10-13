#!/bin/zsh
# Lint staged Swift files before committing. Install once with:
#   ln -sf ../../scripts/pre-commit.sh .git/hooks/pre-commit
# Requires: brew install swiftlint swiftformat
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

staged=("${(@f)$(git diff --cached --name-only --diff-filter=ACMR -- '*.swift')}")
staged=(${staged:#})
(( ${#staged} )) || exit 0

for tool in swiftlint swiftformat; do
  command -v "$tool" >/dev/null || { echo "pre-commit: $tool not installed (brew install $tool)" >&2; exit 1; }
done

swiftformat --lint --quiet "${staged[@]}" || {
  echo "pre-commit: run 'swiftformat ${staged[*]}' and re-stage." >&2
  exit 1
}

swiftlint lint --quiet --strict --baseline .swiftlint-baseline.json "${staged[@]}"
