(declare-project
  :name "janet-lsp"
  :description "A Language Server (LSP) for the Janet Programming Language"
  :version "0.0.1"
  :dependencies ["https://github.com/janet-lang/spork.git"
                 "https://github.com/ianthehenry/judge.git"])

(declare-executable
  :name "janet-lsp"
  :entry "src/main.janet"
  :install true)