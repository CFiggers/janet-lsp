# Janet LSP

A Language Server (LSP) for the [Janet](https://janet-lang.org) programming language.

## Overview

The goal of this project is to provide an augmented editor/tooling experience for [Janet](https://janet-lang.org), via a self-contained, [Language Server Protocol](https://microsoft.github.io/language-server-protocol/)-compliant language server (which is itself implemented in Janet!).

Current features include:

- [x] Partial auto-completion based on defined symbols
- [x] On-hover definition of symbols as returned by `(doc ,symbol)`
- [x] Inline compiler errors

Planned features include:

- [ ] Additional autocompletion support
- [ ] Jump to definition/implementation
- [ ] Find references from definition/implementation
- [ ] Refactoring helps
- [ ] Symbol renaming helps

Possible (but de-prioritized) features include:

- [ ] Syntax highlighting for Janet via semantic tokens

Desirable, but possibly more complicated/difficult features include:

- [ ] Stand-alone (i.e. non-Editor-dependent) usage via API/CLI

## Caveats

- Windows/MacOS support is mostly untested and, in the case of Windows, known to be somewhat glitchy. Contributions welcome here.
- The only editor integration currently tested against is [Visual Studio Code](https://code.visualstudio.com/).
- I've never written a language server before, so I don't really know what I'm doing. Help me, if you'd like!

## Clients (i.e. Editors)

Currently, the only editor tested and known working with Janet LSP is [Visual Studio Code](https://code.visualstudio.com/), which you can try/take advantage of by installing the [Janet++](https://github.com/CFiggers/vscode-janet-plus-plus) extension [from the VS Code marketplace](https://marketplace.visualstudio.com/items?itemName=CalebFiggers.vscode-janet-plus-plus).

Other editors that implement LSP client protocols, either built-in or through editor extensions, include:

- Emacs
- vim/neovim
- Sublime Text
- Helix
- Kakoune

If you get Janet LSP working with any of these options, please let me know!

## Getting Started (for Development)

### Clone this project and Build the stand-alone binary

Requires [Janet](https://github.com/janet-lang/janet) and [jpm](https://github.com/janet-lang/jpm).

```shell
$ git clone https://github.com/CFiggers/janet-lsp
$ cd janet-lsp
$ jpm deps
$ jpm build
```

### Installing

After running the commands above, the following command will copy the `janet-lsp` binary to a location that can be executed via the command line.

```shell
$ jpm install
```

## Contributions

Issues and Pull Requests welcome.

## Prior Art

This project is a hard fork from (with much appreciation to) [JohnDoneth/janet-language-server](https://github.com/JohnDoneth/janet-language-server), which is Copyright (c) 2022 JohnDoneth and contributors.
