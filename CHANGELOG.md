# Changelog
All notable changes to this project will be documented in this file.
Format for entires is <version-string> - release date.

## 0.0.5 - 2024-06-14

- Diagnostics
  - Only syntax highlight function signatures in pop-up hover definitions by @CFiggers in [#23](https://github.com/CFiggers/janet-lsp/pull/23)
  - Fix bug with publishing diagnostics (was causing last diagnostic warning to not clear when using for e.g. nvim-lsp) by @CFiggers in [#23](https://github.com/CFiggers/janet-lsp/pull/23)
- Tests
  - Additional tests and reorganization by @CFiggers in [#23](https://github.com/CFiggers/janet-lsp/pull/23)

## 0.0.4 - 2024-01-26

- Project
  - We now install `janet-lsp` as a binscript instead of building an executable at all by @CFiggers in https://github.com/CFiggers/janet-lsp/pull/19
- Formatting
  - Tweak to vendored copy of `spork/fmt` by @CFiggers in https://github.com/CFiggers/janet-lsp/pull/19
- Diagnostics
  - `eval-buffer` now starts with a clean environment on every evaluation (resolving many consistency issues) by @CFiggers in https://github.com/CFiggers/janet-lsp/pull/19
  - Can now push diagnostics to clients that prefer not to request by issuing `testDocument/publishDiagnostics` RPC notifications by @CFiggers in https://github.com/CFiggers/janet-lsp/pull/18
- Completion and Hover Definitions
  - Bugs with jpm definitions resolved by @CFiggers in https://github.com/CFiggers/janet-lsp/pull/19
- Signature helps
  - Fix bugs in `sexp-at` (off-by-one and crash on unparenthesized top-level forms) by @CFiggers in https://github.com/CFiggers/janet-lsp/pull/19
- RPC
  - Can now send properly formatted LSP notifications (in addition to responses, needed for publishing diagnostics)by @CFiggers in https://github.com/CFiggers/janet-lsp/pull/19
- Testing
  - Migrated Judge tests from main.janet into a separate fileby @CFiggers in https://github.com/CFiggers/janet-lsp/pull/19
- CLI
  - `--debug` flag now works correctlyby @CFiggers in https://github.com/CFiggers/janet-lsp/pull/19
- Misc
  - Source code formatting and comment cleanup by @CFiggers in https://github.com/CFiggers/janet-lsp/pull/17

## 0.0.3 - 2024-01-09

- Completion
  - Add basic CompletionItemKind by @fnurk in https://github.com/CFiggers/janet-lsp/pull/9
- Formatting
  - New feature: Document formatting by @CFiggers in https://github.com/CFiggers/janet-lsp/pull/13
- Signature Helps
  - New Feature: Signature Helps by @CFiggers in https://github.com/CFiggers/janet-lsp/pull/14
- Debug Console
  - New Feature: Debug Console by @CFiggers in https://github.com/CFiggers/janet-lsp/pull/15
- Diagnostics
  - Improvement: Multiple Diagnostic Errors by @CFiggers in https://github.com/CFiggers/janet-lsp/pull/16
- Cross-cutting
  - Separate environment for flychecking user code (better separation between running server env and diagnostic eval env)
  - Replace `spork/argparse` with `ianthehenry/cmd` for command line argument parsing
  - Bug fixes

## 0.0.2 - 2023-10-24

- Hover
  - Improved hover documentation (more detailed info, syntax highlighting for function signatures)
- Completion
  - Added `project.janet` symbols for jpm (`declare-project`, `declare-native`, `declare-executable`, etc.)
- General
  - Improved module loading logic for eval/completion environment
  - Replaced `spork/json` dependency with `CFiggers/jayson` for .jimage compatibility
  - Handle `shutdown` and `exit` lifecycle requests properly

## 0.0.1 - 2023-09-26

- Hard forked this project from [JohnDoneth/janet-language-server](https://github.com/JohnDoneth/janet-language-server).
  