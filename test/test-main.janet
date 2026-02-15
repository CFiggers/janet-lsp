(use judge)

(import ../src/main)

(deftest "parse-content-length"
  (test (main/parse-content-length "000:123:456:789") 123)
  (test (main/parse-content-length "123:456:789") 456)
  (test (main/parse-content-length "0123:456::::789") 456))

(test (peg/match main/uri-percent-encoding-peg "file:///c%3A/Users/pete/Desktop/code/libmpsse")
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
        @[[:symbol {:kind 12 :label hello}]
          [:boolean {:kind 6 :label true}]
          [:function {:kind 3 :label @%}]
          [:cfunction {:kind 3 :label @abstract?}]
          [:string {:kind 6 :label "Hello world"}]
          [:buffer {:kind 6 :label @"Hello world"}]
          [:number {:kind 6 :label 123}]
          [:keyword {:kind 6 :label :keyword}]
          [:core/file {:kind 17 :label "<core/file 0x1>"}]
          [:core/peg {:kind 6 :label "<core/peg 0x2>"}]
          [:struct {:kind 6 :label {:a 1}}]
          [:table {:kind 6 :label @{:a 1}}]
          [:tuple {:kind 6 :label atuple}]
          [:array {:kind 6 :label @[:a 1]}]
          [:nil {:kind 12 :label anil}]]))

(deftest "test find-all-module-files"
  (test (main/find-all-module-files (os/cwd))
    @["/home/deck/projects/janet/janet-lsp/build/janet-lsp.jimage"
      "/home/deck/projects/janet/janet-lsp/test/test-main.janet"
      "/home/deck/projects/janet/janet-lsp/test/test-format-file-after.janet"
      "/home/deck/projects/janet/janet-lsp/test/test-lookup.janet"
      "/home/deck/projects/janet/janet-lsp/test/test-integration.janet"
      "/home/deck/projects/janet/janet-lsp/test/test-format-file-before.janet"
      "/home/deck/projects/janet/janet-lsp/test/test-parser.janet"
      "/home/deck/projects/janet/janet-lsp/src/lookup.janet"
      "/home/deck/projects/janet/janet-lsp/src/rpc.janet"
      "/home/deck/projects/janet/janet-lsp/src/eval.janet"
      "/home/deck/projects/janet/janet-lsp/src/doc.janet"
      "/home/deck/projects/janet/janet-lsp/src/main.janet"
      "/home/deck/projects/janet/janet-lsp/src/misc.janet"
      "/home/deck/projects/janet/janet-lsp/src/utils.janet"
      "/home/deck/projects/janet/janet-lsp/src/parser.janet"
      "/home/deck/projects/janet/janet-lsp/src/logging.janet"
      "/home/deck/projects/janet/janet-lsp/scratch.janet"
      "/home/deck/projects/janet/janet-lsp/libs/fmt.janet"
      "/home/deck/projects/janet/janet-lsp/libs/jayson.janet"
      "/home/deck/projects/janet/janet-lsp/libs/jpm-defs.janet"]))

(deftest "test find-all-module-files"
  (test (main/find-all-module-files (os/cwd) true)
    @["/home/deck/projects/janet/janet-lsp/build/janet-lsp.jimage"
      "/home/deck/projects/janet/janet-lsp/test/test-main.janet"
      "/home/deck/projects/janet/janet-lsp/test/test-format-file-after.janet"
      "/home/deck/projects/janet/janet-lsp/test/test-lookup.janet"
      "/home/deck/projects/janet/janet-lsp/test/test-integration.janet"
      "/home/deck/projects/janet/janet-lsp/test/test-format-file-before.janet"
      "/home/deck/projects/janet/janet-lsp/test/test-parser.janet"
      "/home/deck/projects/janet/janet-lsp/src/lookup.janet"
      "/home/deck/projects/janet/janet-lsp/src/rpc.janet"
      "/home/deck/projects/janet/janet-lsp/src/eval.janet"
      "/home/deck/projects/janet/janet-lsp/src/doc.janet"
      "/home/deck/projects/janet/janet-lsp/src/main.janet"
      "/home/deck/projects/janet/janet-lsp/src/misc.janet"
      "/home/deck/projects/janet/janet-lsp/src/utils.janet"
      "/home/deck/projects/janet/janet-lsp/src/parser.janet"
      "/home/deck/projects/janet/janet-lsp/src/logging.janet"
      "/home/deck/projects/janet/janet-lsp/scratch.janet"
      "/home/deck/projects/janet/janet-lsp/libs/fmt.janet"
      "/home/deck/projects/janet/janet-lsp/libs/jayson.janet"
      "/home/deck/projects/janet/janet-lsp/libs/jpm-defs.janet"]))

(deftest "test find-unique-paths"
  (test (main/find-unique-paths (main/find-all-module-files (os/cwd)))
    @["./build/:all:.jimage"
      "./test/:all:.janet"
      "./src/:all:.janet"
      "./:all:.janet"
      "./libs/:all:.janet"]))

(deftest "test find-unique-paths"
  (test (main/find-unique-paths (main/find-all-module-files (os/cwd) true))
    @["./build/:all:.jimage"
      "./test/:all:.janet"
      "./src/:all:.janet"
      "./:all:.janet"
      "./libs/:all:.janet"]))
