(declare-project
  :name "janet-lsp"
  :description "A Language Server (LSP) for the Janet Programming Language"
  :version "0.0.2"
  :dependencies ["https://github.com/janet-lang/spork.git"
                 "https://github.com/ianthehenry/judge.git"])

(def cflags
  (case (os/which)
    :windows []
    ["-s"]))

(declare-executable
  :name "janet-lsp"
  :entry "src/main.janet"
  :cflags cflags
  :install true)

(declare-archive
 :name "janet-lsp"
 :entry "/src/main")
