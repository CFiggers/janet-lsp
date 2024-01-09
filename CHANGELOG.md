# Changelog
All notable changes to this project will be documented in this file.
Format for entires is <version-string> - release date.

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
  