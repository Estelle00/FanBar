# Code quality gates

`.github/workflows/quality.yml` runs on every pull request and on `main`. The
rule is **gate new code, freeze old debt**: nothing here forces legacy files up
to a target, but anything a PR adds has to pass.

| Gate | Fails when | Run locally |
| --- | --- | --- |
| SwiftLint | a violation not in `.swiftlint-baseline.json` appears (warnings count, `--strict`) | `swiftlint lint --strict --baseline .swiftlint-baseline.json` |
| SwiftFormat | any file drifts from `.swiftformat` | `swiftformat --lint .` (fix: `swiftformat .`) |
| Build | the compiler emits any Swift or C warning | `swift build -Xswiftc -warnings-as-errors -Xcc -Werror` |
| Tests | any test fails | `swift test --enable-code-coverage` |
| Diff coverage | < 60% of executable lines added in `Sources/` are covered (only when the PR adds ≥ 5 such lines) | `python3 scripts/coverage-report.py --base origin/main --min-diff 60` |

Tools: `brew install swiftlint swiftformat`. Optional pre-commit hook that
lints staged files:

```sh
ln -sf ../../scripts/pre-commit.sh .git/hooks/pre-commit
```

## Legacy debt

- `.swiftlint-baseline.json` holds the violations that existed when the gate was
  introduced. After fixing some, shrink it with
  `swiftlint lint --write-baseline .swiftlint-baseline.json`. Never regenerate it
  to hide a new violation.
- Size rules (`file_length`, `type_body_length`, `function_body_length`,
  `cyclomatic_complexity`) report the current count in their message, so a
  baseline entry stops matching as soon as the file is edited. Those cases are
  marked inline with `swiftlint:disable` instead (`FanController`,
  `FanCurveEditorView`, `FanMenu`, a few long functions). Search for
  `swiftlint:disable` to find them; remove the marker when the code is split.

## Coverage snapshot (when the gate was introduced)

Total line coverage of `Sources/` was about 30%. Curve math, temperature chart,
widget snapshot and SMC decoding are well covered; SwiftUI/AppKit view files
are near 0%.

`FanBarHelperTests` runs the privileged helper against `FakeSMC`, an in-memory
key table that models per-fan mode keys with the `Ftst` unlock, the older Intel
`FS! ` bitmask and fpe2 values. It covers input validation, clamping to each
fan's limits, rollback after a partial write, and handing control back to macOS
on disconnect, shutdown and driver release. Only `AppleSMCKeyStore` (the IOKit
calls) and the XPC/code-signing plumbing stay untested.

The lcov file is uploaded as the `coverage-lcov` artifact of each run, so it
can feed Codecov or SonarCloud later without changing the test step.
