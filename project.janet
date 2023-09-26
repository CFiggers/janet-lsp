(declare-project
  :name "janet-language-server"
  :description "Language Server for the Janet Programming Language"
  :version "0.0.0"
  :dependencies [
    "https://github.com/janet-lang/spork.git"
  ])

(declare-executable
  :name "janet-language-server"
  :entry "src/main.janet"
  :install true)