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
  (def janet-lsp (os/spawn ["janet" "./src/main.janet" "--debug"] :p {:in :pipe :out :pipe}))

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
  (test (jayson/decode (last (string/split "\r\n" got)))
        @{"id" 0
          "jsonrpc" "2.0"
          "result" @{"capabilities" @{"completionProvider" @{"resolveProvider" true}
                                      "definitionProvider" true
                                      "diagnosticProvider" @{"interFileDependencies" true
                                                             "workspaceDiagnostics" false}
                                      "documentFormattingProvider" true
                                      "hoverProvider" true
                                      "signatureHelpProvider" @{"triggerCharacters" @[" "]}
                                      "textDocumentSync" @{"change" 1 "openClose" true}}
                     "serverInfo" @{"name" "janet-lsp" "version" "0.0.6"}}}))

(deftest: with-process "test textDocument/didOpen" [context]
  (var got (ev/read (context :from-lsp) 2048)) 
  (write-output context (slurp "./test/resources/textDocument_didOpen_rpc.json"))
  (var got (ev/read (context :from-lsp) 2048))
  (test (jayson/decode (last (string/split "\r\n" got)))
    @{"jsonrpc" "2.0"
      "method" "textDocument/publishDiagnostics"
      "params" @{"diagnostics" @[]
                 "uri" "file:///home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/test/test-format-file-after.janet"}}))
