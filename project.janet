(declare-project
  :name "janet-lsp"
  :description "A Language Server (LSP) for the Janet Programming Language"
  :version "0.0.12"
  :dependencies ["https://github.com/janet-lang/spork.git"
                 "https://github.com/CFiggers/jayson.git"
                 "https://github.com/CFiggers/cmd.git" 
                 "https://github.com/CFiggers/judge.git" ])

# (def cflags
#   (case (os/which)
#     :windows []
#     ["-s"]))

# (declare-executable
#   :name "janet-lsp"
#   :entry "src/main.janet"
#   :cflags cflags
#   :install true)

(declare-archive
  :name "janet-lsp"
  :entry "/src/main")

(declare-binscript
  :main "src/janet-lsp"
  :hardcode-syspath true
  :is-janet true)
