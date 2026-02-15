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
           # (printf "context is (from reset): %q" context)
           (exit-lsp context)
           (os/proc-wait (context :process))
           (merge-into context (start-lsp)))
  :teardown (fn [context]
              (exit-lsp context)
              (os/proc-wait (context :process))))

(deftest: with-process "Starts and exits" [context]
  (var got (ev/read (context :from-lsp) 2048))

  (test (-> (jayson/decode (last (string/split "\r\n" got)) true)
            (put-in [:result :serverInfo :commit] "{{commit}}")
            (put-in [:result :serverInfo :version] "{{version}}"))
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
                    :serverInfo @{:commit "{{commit}}"
                                  :name "janet-lsp"
                                  :version "{{version}}"}}})

  (write-output context (jayson/encode {:jsonrpc 2.0
                                        :method "janet/serverInfo"
                                        :params {}}))
  (set got (ev/read (context :from-lsp) 2048))

  (test (-> (jayson/decode (last (string/split "\r\n" got)) true)
            (put-in [:result :serverInfo :commit] "{{commit}}")
            (put-in [:result :serverInfo :version] "{{version}}"))
        @{:jsonrpc "2.0"
          :result @{:serverInfo @{:commit "{{commit}}"
                                  :name "janet-lsp"
                                  :version "{{version}}"}}}))

(deftest: with-process "test textDocument/didOpen" [context]
  (var got (ev/read (context :from-lsp) 2048))
  (write-output context (slurp "./test/resources/textDocument_didOpen_rpc.json"))
  (set got (ev/read (context :from-lsp) 2048))

  (test (jayson/decode (last (string/split "\r\n" got)) true)
        @{:jsonrpc "2.0"
          :method "textDocument/publishDiagnostics"
          :params @{:diagnostics @[]
                    :uri "file:///home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/test/test-format-file-after.janet"}}))

(deftest-type with-process-open
  :setup (fn []
           (start-lsp))
  :reset (fn [context]
           (exit-lsp context)
           (os/proc-wait (context :process))
           (merge-into context (start-lsp))

           # Consume the `initialize` response from the LSP server 
           (var got (ev/read (context :from-lsp) 2048))

           # Call "textDocument/didOpen" to load "./test/test-format-file-after.janet"
           (write-output context (slurp "./test/resources/textDocument_didOpen_rpc.json"))
           (set got (ev/read (context :from-lsp) 2048)))
  :teardown (fn [context]
              (exit-lsp context)
              (os/proc-wait (context :process))))

(deftest: with-process-open "test textDocument/didChange" [context]
  (write-output context (slurp "./test/resources/textDocument_didChange_rpc.json"))
  (var got (ev/read (context :from-lsp) 2048))

  (test (jayson/decode (last (string/split "\r\n" got)) true)
        @{:jsonrpc "2.0"
          :method "textDocument/publishDiagnostics"
          :params @{:diagnostics @[]
                    :uri "file:///home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/test/test-format-file-after.janet"}}))

(deftest: with-process-open "test textDocument/hover" [context]
  (write-output context (slurp "./test/resources/textDocument_hover_rpc.json"))
  (var got (ev/read (context :from-lsp) 2048))

  (test (jayson/decode (last (string/split "\r\n" got)) true)
    @{:id 350
      :jsonrpc "2.0"
      :result @{:contents @{:kind "markdown"
                            :value "macro  \nboot.janet on line 3245, column 1\n\n```janet\n(use & modules)\n```\n\nSimilar to `import`, but imported bindings are not prefixed with a module\nidentifier. Can also import multiple modules in one shot."}
                :range @{:end @{:character 4 :line 0}
                         :start @{:character 1 :line 0}}}}))

(deftest: with-process-open "test textDocument/diagnostic" [context]
  (write-output context (slurp "./test/resources/textDocument_diagnostic_rpc.json"))
  (var got (ev/read (context :from-lsp) 2048))

  (test (jayson/decode (last (string/split "\r\n" got)) true)
        @{:id 6
          :jsonrpc "2.0"
          :result @{:items @[] :kind "full"}}))

(deftest: with-process-open "test textDocument/completion" [context]
  (write-output context (slurp "./test/resources/textDocument_completion_rpc.json"))
  (var got (ev/read (context :from-lsp) 30000))

  (test (as-> (jayson/decode (last (string/split "\r\n" got)) true) x
              (put-in x [:result :items] (string/format "{{%d items here}}" (length (get-in x [:result :items])))))
    @{:id 6
      :jsonrpc "2.0"
      :result @{:isIncomplete true
                :items "{{749 items here}}"}}))

(deftest: with-process-open "test completionItem/resolve" [context]
  (write-output context (slurp "./test/resources/textDocument_completion_rpc.json"))
  (var got (ev/read (context :from-lsp) 30000))

  (test (as-> (jayson/decode (last (string/split "\r\n" got)) true) x
              (put-in x [:result :items] (string/format "{{%d items here}}" (length (get-in x [:result :items])))))
    @{:id 6
      :jsonrpc "2.0"
      :result @{:isIncomplete true
                :items "{{749 items here}}"}})

  (write-output context (slurp "./test/resources/completionItem_resolve_rpc.json"))
  (set got (ev/read (context :from-lsp) 2048))

  (test (jayson/decode (last (string/split "\r\n" got)) true)
    @{:id 31
      :jsonrpc "2.0"
      :result @{:documentation @{:kind "markdown"
                                 :value "cfunction  \nsrc/core/corelib.c on line 330, column 1\n\n```janet\n(string & xs)\n```\n\nCreates a string by concatenating the elements of `xs` together. If an element is not a byte sequence, it is converted to bytes via `describe`. Returns the new string."}
                :label "string"}}))
