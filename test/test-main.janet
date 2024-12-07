(use judge)

(import ../src/main)

(deftest "parse-content-length"
  (test (main/parse-content-length "000:123:456:789") 123)
  (test (main/parse-content-length "123:456:789") 456)
  (test (main/parse-content-length "0123:456::::789") 456))

(test (peg/match uri-percent-encoding-peg "file:///c%3A/Users/pete/Desktop/code/libmpsse")
      @["file:///c:/Users/pete/Desktop/code/libmpsse"])

(deftest "test binding-to-lsp-item"
  (def eval-env (table/proto-flatten (make-env root-env)))

  (def bind-fiber (fiber/new |(do (defglobal "anil" nil)
                                  (defglobal "hello" 'world)
                                  (defglobal "atuple" [:a 1])
                                  true) :e eval-env))
  (def bf-return (resume bind-fiber))

  (def test-cases @[['hello :symbol] [true :boolean] [% :function]
                    [abstract? :cfunction] ["Hello world" :string]
                    [@"Hello world" :buffer] [123 :number]
                    [:keyword :keyword] [stderr :core/file]
                    [(peg/compile 1) :core/peg] [{:a 1} :struct]
                    [@{:a 1} :table] ['atuple :tuple]
                    [@[:a 1] :array] # [(coro) :fiber]
                    ['anil :nil]])

  (test (map (juxt 1 |(main/binding-to-lsp-item (first $) eval-env)) test-cases)
        @[[:symbol    {:kind 12 :label hello}]
          [:boolean   {:kind 6  :label true}]
          [:function  {:kind 3  :label @%}]
          [:cfunction {:kind 3  :label @abstract?}]
          [:string    {:kind 6  :label "Hello world"}]
          [:buffer    {:kind 6  :label @"Hello world"}]
          [:number    {:kind 6  :label 123}]
          [:keyword   {:kind 6  :label :keyword}]
          [:core/file {:kind 17 :label "<core/file 0x1>"}]
          [:core/peg  {:kind 6  :label "<core/peg 0x2>"}]
          [:struct    {:kind 6  :label {:a 1}}]
          [:table     {:kind 6  :label @{:a 1}}]
          [:tuple     {:kind 6  :label atuple}]
          [:array     {:kind 6  :label @[:a 1]}]
          [:nil       {:kind 12 :label anil}]]))

(deftest "test find-all-module-files"
  (test (main/find-all-module-files (os/cwd))
    @["/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/main.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/rpc.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/logging.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/misc.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/lookup.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/doc.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/eval.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/libs/fmt.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/libs/jpm-defs.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/libs/jayson.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/test/test-main.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/test/test-lookup.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/test/scratch.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/test/test-format-file-after.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/test/test-format-file-before.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/test/test-integration.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/build/janet-lsp.jimage"]))

(deftest "test find-all-module-files"
  (test (main/find-all-module-files (os/cwd) true)
    @["/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/main.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/rpc.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/logging.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/misc.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/lookup.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/doc.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/eval.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/libs/fmt.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/libs/jpm-defs.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/libs/jayson.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/test/test-main.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/test/test-lookup.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/test/scratch.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/test/test-format-file-after.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/test/test-format-file-before.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/test/test-integration.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/build/janet-lsp.jimage"]))

(deftest "test find-unique-paths"
  (test (main/find-unique-paths (main/find-all-module-files (os/cwd)))
    @["./src/:all:.janet"
      "./libs/:all:.janet"
      "./test/:all:.janet"
      "./build/:all:.jimage"]))

(deftest "test find-unique-paths"
  (test (main/find-unique-paths (main/find-all-module-files (os/cwd) true))
    @["./src/:all:.janet"
      "./libs/:all:.janet"
      "./test/:all:.janet"
      "./build/:all:.jimage"]))
