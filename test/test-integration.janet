(import ../libs/jayson)

(use judge)

(defn write-output [cursor & responses]
  (each response responses
    # Write headers
    (:write (cursor :to-lsp) (string "Content-Length: " (length response)
                                     (case (os/which)
                                       :windows "\n\n" "\r\n\r\n")))

    # Write response
    (:write (cursor :to-lsp) response)
    (+= (cursor :request-id) 1)))

(defn start-lsp []
  (def janet-lsp (os/spawn ["janet" "./src/main.janet"] :p {:in :pipe :out :pipe}))

  (def cursor
    @{:process janet-lsp
      :request-id 0
      :to-lsp (janet-lsp :in)
      :from-lsp (janet-lsp :out)})

  (write-output cursor
                (string (jayson/encode
                          {:id (cursor :request-id)
                           :method :initialize
                           :params {:rootUri (os/cwd)
                                    :capabilities {}}})))

  cursor)

(defn exit-lsp [cursor]
  (write-output cursor
                (string (jayson/encode
                          {:id (cursor :request-id)
                           :method :shutdown}))
                (string (jayson/encode
                          {:id (cursor :request-id)
                           :method :exit}))))

(deftest-type with-process
  :setup (fn []
           (start-lsp))
  :reset (fn [context]
           (printf "context is (from reset): %q" context)
           (exit-lsp context)
           (os/proc-wait (context :process))
           (merge-into context (start-lsp)))
  :teardown (fn [context]
              (exit-lsp context)
              (os/proc-wait (context :process))))

(deftest: with-process "Starts and exits" [context]
  (var got (ev/read (context :from-lsp) 2048))
  (test (jayson/decode (last (string/split "\r\n" got)) true)
        @{:id 0
          :jsonrpc "2.0"
          :result @{:capabilities @{:completionProvider @{:resolveProvider true}
                                    :definitionProvider true
                                    :diagnosticProvider @{:interFileDependencies true
                                                          :workspaceDiagnostics false}
                                    :documentFormattingProvider true
                                    :hoverProvider true
                                    :signatureHelpProvider @{:triggerCharacters @[" "]}
                                    :textDocumentSync @{:change 1 :openClose true}}
                    :serverInfo @{:commit "90bdf70"
                                  :name "janet-lsp"
                                  :version "0.0.7"}}})
  (write-output context (jayson/encode {:jsonrpc 2.0
                                        :method "janet/serverInfo"
                                        :params {}}))
  (set got (ev/read (context :from-lsp) 2048))
  (test (jayson/decode (last (string/split "\r\n" got)) true)
        @{:jsonrpc "2.0"
          :result @{:server-info @{:commit "90bdf70"
                                   :name "janet-lsp"
                                   :version "0.0.7"}}}))

### 
### textdocument/didOpen
### 

(defmacro make-didopen-rpc [uri text]
  (with-syms [$uri $text]
    ~(let [,$uri ,uri ,$text ,text]
       (jayson/encode
         {:jaysonrpc "2.0"
          :method "textDocument/didOpen"
          :params {:textDocument {:uri ,$uri
                                  :languageId "janet"
                                  :version 1
                                  :text ,$text}}}))))

(deftest: with-process "test textDocument/didOpen simple" [context]
  (var got (ev/read (context :from-lsp) 2048))

  (write-output context (make-didopen-rpc "file:///home/caleb/projects/janet/janet-lsp/scratch.janet" "(+ 1 1)"))
  (set got (ev/read (context :from-lsp) 2048))
  (test (jayson/decode (last (string/split "\r\n" got)) true)
        @{:jsonrpc "2.0"
          :method "textDocument/publishDiagnostics"
          :params @{:diagnostics @[]
                    :uri "file:///home/caleb/projects/janet/janet-lsp/scratch.janet"}}))

(deftest: with-process "test textDocument/didOpen" [context]
  (var got (ev/read (context :from-lsp) 2048))
  (write-output context (slurp "./test/resources/textDocument_didOpen_rpc.json"))
  (set got (ev/read (context :from-lsp) 2048))
  (test (jayson/decode (last (string/split "\r\n" got)) true)
        @{:jsonrpc "2.0"
          :method "textDocument/publishDiagnostics"
          :params @{:diagnostics @[]
                    :uri "file:///home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/test/test-format-file-after.janet"}}))

### 
### textDocument/diagnostic
### 

(defmacro make-diagnostic-rpc [uri]
  (with-syms [$uri]
    ~(let [,$uri ,uri]
       (jayson/encode
         {:jsonrpc "2.0"
          :method "textDocument/diagnostic"
          :params {:textDocument {:uri ,$uri}}}))))

(deftest: with-process "test textDocument/diagnostics - all clean" [context]
  (var got (ev/read (context :from-lsp) 2048))

  (write-output context (make-didopen-rpc "file:///home/caleb/projects/janet/janet-lsp/scratch.janet" "(+ 1 1)"))
  (set got (ev/read (context :from-lsp) 2048))
  (test (jayson/decode (last (string/split "\r\n" got)) true)
        @{:jsonrpc "2.0"
          :method "textDocument/publishDiagnostics"
          :params @{:diagnostics @[]
                    :uri "file:///home/caleb/projects/janet/janet-lsp/scratch.janet"}})

  (write-output context (make-diagnostic-rpc "file:///home/caleb/projects/janet/janet-lsp/scratch.janet"))
  (set got (ev/read (context :from-lsp) 2048))
  (test (jayson/decode (last (string/split "\r\n" got)) true)
        @{:jsonrpc "2.0"
          :result @{:items @[] :kind "full"}}))

(deftest: with-process "test textDocument/diagnostics - with errors" [context]
  (var got (ev/read (context :from-lsp) 2048))

  (write-output context (make-didopen-rpc "file:///home/caleb/projects/janet/janet-lsp/scratch.janet" "(+ 1 1)\n\n()"))
  (set got (ev/read (context :from-lsp) 2048))
  (test (jayson/decode (last (string/split "\r\n" got)) true)
        @{:jsonrpc "2.0"
          :method "textDocument/publishDiagnostics"
          :params @{:diagnostics @[@{:message "expected integer key for tuple in range [0, 0), got 0"
                                     :range @{:end @{:character 0 :line 0}
                                              :start @{:character 0 :line 0}}}]
                    :uri "file:///home/caleb/projects/janet/janet-lsp/scratch.janet"}})

  (write-output context (make-diagnostic-rpc "file:///home/caleb/projects/janet/janet-lsp/scratch.janet"))
  (set got (ev/read (context :from-lsp) 2048))
  (test (jayson/decode (last (string/split "\r\n" got)) true)
        @{:jsonrpc "2.0"
          :result @{:items @[@{:message "expected integer key for tuple in range [0, 0), got 0"
                               :range @{:end @{:character 0 :line 0}
                                        :start @{:character 0 :line 0}}}]
                    :kind "full"}}))

(deftest: with-process "test textDocument/diagnostics - libraries that attempt to print should not crash" [context]
  (var got (ev/read (context :from-lsp) 2048))

  (write-output context (make-didopen-rpc "file:///home/caleb/projects/janet/janet-lsp/scratch.janet" "(use spork/cjanet) (module-entry \"test\")"))
  (set got (ev/read (context :from-lsp) 2048))
  (test got @"Content-Length: 308\r\n\r\n{\"params\":{\"uri\":\"file:///home/caleb/projects/janet/janet-lsp/scratch.janet\",\"diagnostics\":[{\"range\":{\"start\":{\"character\":20,\"line\":0},\"end\":{\"character\":20,\"line\":0}},\"message\":\"(macro) expected integer key for symbol in range [0, 5), got nil\"}]},\"jsonrpc\":\"2.0\",\"method\":\"textDocument/publishDiagnostics\"}")
  (test (jayson/decode (last (string/split "\r\n" got)) true)
        @{:jsonrpc "2.0"
          :method "textDocument/publishDiagnostics"
          :params @{:diagnostics @[@{:message "(macro) expected integer key for symbol in range [0, 5), got nil"
                                     :range @{:end @{:character 20 :line 0}
                                              :start @{:character 20 :line 0}}}]
                    :uri "file:///home/caleb/projects/janet/janet-lsp/scratch.janet"}})

  (write-output context (make-diagnostic-rpc "file:///home/caleb/projects/janet/janet-lsp/scratch.janet"))
  (set got (ev/read (context :from-lsp) 2048))
  (test (jayson/decode (last (string/split "\r\n" got)) true)
        @{:jsonrpc "2.0"
          :result @{:items @[@{:message "(macro) expected integer key for symbol in range [0, 5), got nil"
                               :range @{:end @{:character 20 :line 0}
                                        :start @{:character 20 :line 0}}}]
                    :kind "full"}}))

### 
### textDocument/didChange
### 

(defmacro make-didChange-rpc [uri text]
  (with-syms [$uri $text]
    ~(let [,$uri ,uri ,$text ,text]
       (jayson/encode
         {:jsonrpc "2.0"
          :method "textDocument/didChange"
          :params {:contentChanges @[@{:text ,$text}]
                   :textDocument @{:uri ,$uri
                                   :version 2}}}))))

(deftest: with-process "test textDocument/didChange" [context]
  (var got (ev/read (context :from-lsp) 2048))

  (write-output context (make-didopen-rpc "file:///home/caleb/projects/janet/janet-lsp/scratch.janet" "(use spork/cjanet)"))
  (set got (ev/read (context :from-lsp) 2048))
  (test (jayson/decode (last (string/split "\r\n" got)) true)
        @{:jsonrpc "2.0"
          :method "textDocument/publishDiagnostics"
          :params @{:diagnostics @[]
                    :uri "file:///home/caleb/projects/janet/janet-lsp/scratch.janet"}})

  (write-output context (make-didChange-rpc "file:///home/caleb/projects/janet/janet-lsp/scratch.janet" "(use spork/cjanet)\n\n"))
  (set got (ev/read (context :from-lsp) 2048))
  (test (jayson/decode (last (string/split "\r\n" got)) true)
        @{:jsonrpc "2.0"
          :method "textDocument/publishDiagnostics"
          :params @{:diagnostics @[]
                    :uri "file:///home/caleb/projects/janet/janet-lsp/scratch.janet"}}))

### 
### textDocument/completion
### 

(defmacro make-completion-rpc [uri position]
  (with-syms [$uri $position]
    ~(let [,$uri ,uri ,$position ,position]
       (jayson/encode
         {:jsonrpc "2.0"
          :method "textDocument/completion"
          :params {:context {:triggerKind 1}
                   :position ,$position
                   :textDocument @{:uri ,$uri}}}))))

(deftest: with-process "test textDocument/completion" [context]
  (var got (ev/read (context :from-lsp) 2048))

  (write-output context (make-didopen-rpc "file:///home/caleb/projects/janet/janet-lsp/scratch.janet" "(use spork/cjanet)\n\n(def)"))
  (set got (ev/read (context :from-lsp) 2048))
  (test (jayson/decode (last (string/split "\r\n" got)) true)
    @{:jsonrpc "2.0"
      :method "textDocument/publishDiagnostics"
      :params @{:diagnostics @[@{:message "expected at least 2 arguments to def"
                                 :range @{:end @{:character 1 :line 2}
                                          :start @{:character 1 :line 2}}}]
                :uri "file:///home/caleb/projects/janet/janet-lsp/scratch.janet"}})

  (write-output context (make-completion-rpc "file:///home/caleb/projects/janet/janet-lsp/scratch.janet"
                                             @{:character 4 :line 2}))
  (set got (ev/read (context :from-lsp) 23000))
  (test (length (get-in (jayson/decode (last (string/split "\r\n" got)) true) [:result :items]))
    719))



(comment

  ### 
  ### textDocument/formatting
  ### 

  (defmacro make-formatting-rpc []
    (with-syms []
      ~(let []
         (jayson/encode
           {:jsonrpc "2.0"
            :method "textDocument/formatting"
            :params {}}))))

  (deftest: with-process "test textDocument/formatting" [context]
    (var got (ev/read (context :from-lsp) 2048))

    (write-output context (make-formatting-rpc))
    (set got (ev/read (context :from-lsp) 2048))
    (test (jayson/decode (last (string/split "\r\n" got)) true)))

  ### 
  ### textDocument/hover
  ### 

  (defmacro make-hover-rpc []
    (with-syms []
      ~(let []
         (jayson/encode
           {:jsonrpc "2.0"
            :method "textDocument/hover"
            :params {}}))))

  (deftest: with-process "test textDocument/hover" [context]
    (var got (ev/read (context :from-lsp) 2048))

    (write-output context (make-hover-rpc))
    (set got (ev/read (context :from-lsp) 2048))
    (test (jayson/decode (last (string/split "\r\n" got)) true)))

  ### 
  ### textDocument/signatureHelp
  ### 

  (defmacro make-signatureHelp-rpc []
    (with-syms []
      ~(let []
         (jayson/encode
           {:jsonrpc "2.0"
            :method "textDocument/signatureHelp"
            :params {}}))))

  (deftest: with-process "test textDocument/signatureHelp" [context]
    (var got (ev/read (context :from-lsp) 2048))

    (write-output context (make-signatureHelp-rpc))
    (set got (ev/read (context :from-lsp) 2048))
    (test (jayson/decode (last (string/split "\r\n" got)) true)))

  ### 
  ### textDocument/definition
  ### 

  (defmacro make-definition-rpc []
    (with-syms []
      ~(let []
         (jayson/encode
           {:jsonrpc "2.0"
            :method "textDocument/definition"
            :params {}}))))

  (deftest: with-process "test textDocument/definition" [context]
    (var got (ev/read (context :from-lsp) 2048))

    (write-output context (make-definition-rpc))
    (set got (ev/read (context :from-lsp) 2048))
    (test (jayson/decode (last (string/split "\r\n" got)) true))))
