(import ../libs/jayson :prefix "json/")
(import ../libs/fmt)
(import ./doc)
(import ./eval)
(import ./logging)
(import ./lookup)
(import ./rpc)

(import cmd)
(import spork/argparse)
(import spork/path)
(import spork/rpc)

(use judge)

(def version "0.0.5")

(def jpm-defs (require "../libs/jpm-defs"))

(eachk k jpm-defs
  (match (type k) :symbol (put-in jpm-defs [k :source-map] nil) nil))

(defn parse-content-length [input]
  (scan-number (string/trim ((string/split ":" input) 1))))

(defn run-diagnostics [uri content]
  (let [items @[]
        eval-result (eval/eval-buffer content (path/basename uri))]

    (each res eval-result
      (match res
        {:location [line col] :message message}
        (array/push items
                    {:range
                     {:start {:line (max 0 (dec line)) :character col}
                      :end {:line (max 0 (dec line)) :character col}}
                     :message message})))
    
    items))

(defn on-document-change
  ``
  Handler for the ["textDocument/didChange"](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_didChange) event.
  
  Params contains the new state of the document.
  ``
  [state params]
  (let [content (get-in params ["contentChanges" 0 "text"])
        uri (get-in params ["textDocument" "uri"])]
    (put-in state [:documents uri] @{:content content})
    
    (if (dyn :push-diagnostics)
      (let [d (run-diagnostics uri content)]
        [:ok state {:method "textDocument/publishDiagnostics"
                    :params {:uri uri
                             :diagnostics d}} :notify true]) 
      [:noresponse state])))

(defn on-document-diagnostic [state params]
  (let [uri (get-in params ["textDocument" "uri"])
        content (get-in state [:documents uri :content])
        diagnostics (run-diagnostics uri content)] 

    [:ok state {:kind "full"
                :items diagnostics}]))

(defn on-document-formatting [state params]
  (let [uri (get-in params ["textDocument" "uri"])
        content (get-in state [:documents uri :content])
        new-content (freeze (fmt/format (string/slice content)))]
    (comment logging/log (string/format "old content: %m" content))
    (comment logging/log (string/format "new content: %m" new-content))
    (comment logging/log (string/format "formatting changed something: %m" (not= content new-content)))
    (if (= content new-content)
      [:ok state :json/null]
      (do (put-in state [:documents uri] {:content new-content})
          [:ok state [{:range {:start {:line 0 :character 0}
                               :end {:line 1000000 :character 1000000}}
                       :newText new-content}]]))))

(defn on-document-open [state params]
  (let [content (get-in params ["textDocument" "text"])
        uri (get-in params ["textDocument" "uri"])]

    (put-in state [:documents uri] @{:content content}))

  [:noresponse state])

(defn binding-type [x]
  (let [s (get ((dyn :eval-env) x) :value x)]
    (case (type s)
      :symbol    12 :boolean   6
      :function  3  :cfunction 3
      :string    6  :buffer    6
      :number    6  :keyword   6
      :core/file 17 :core/peg  6
      :struct    6  :table     6
      :tuple     6  :array     6
      :fiber     6  :nil       6)))

(defn binding-to-lsp-item
  "Takes a binding and returns a CompletionItem"
  [name]
  {:label name :kind (binding-type name)})

(defn on-completion [state params]
  [:ok state {:isIncomplete true
              :items (seq [bind :in (all-bindings (dyn :eval-env))] (binding-to-lsp-item bind))}])

(defn on-completion-item-resolve [state params]
  (let [label (get params "label")]
    [:ok state {:label label
                :documentation {:kind "markdown"
                                :value (doc/my-doc* (symbol label) (dyn :eval-env))}}]))

(defn on-document-hover [state params]
  (let [uri (get-in params ["textDocument" "uri"])
        content (get-in state [:documents uri :content])
        {"line" line "character" character} (get params "position")
        {:word hover-word :range [start end]} (lookup/word-at {:line line :character character} content)
        hover-text (doc/my-doc* (symbol hover-word) (dyn :eval-env))]
    [:ok state (match hover-word
                 nil {}
                 _ {:contents {:kind "markdown"
                               :value hover-text}
                    :range {:start {:line line :character start}
                            :end {:line line :character end}}})]))

(defn on-document-signature-help [state params]
  (comment logging/log (string "on-signature-help state: "))
  (comment logging/log (string/format "%q" state))
  (comment logging/log (string "on-signature-help params: "))
  (comment logging/log (string/format "%q" params))
  (let [uri (get-in params ["textDocument" "uri"])
        content (get-in state [:documents uri :content])
        {"line" line "character" character} (get params "position")
        {:source sexp-text :range [start end]} (lookup/sexp-at {:line line :character character} content)
        function-symbol (or (first (peg/match '(* "(" (any :s) (<- (to " "))) sexp-text)) "none")
        signature (or (doc/get-signature (symbol function-symbol)) "not found")]
    (case signature
      "not found" [:ok state :json/null]
      [:ok state {:signatures [{:label signature}]}])))

(defn on-initialize
  `` 
  Called by the LSP client to recieve a list of capabilities
  that this server provides so the client knows what it can request.
  ``
  [state params]
  (logging/log (string/format "on-initialize called with these params: %m" params))

  (if-let [diagnostic? (get-in params ["capabilities" "textDocument" "diagnostic"])]
    (setdyn :push-diagnostics false)
    (setdyn :push-diagnostics true))

  [:ok state {:capabilities {:completionProvider {:resolveProvider true}
                             :textDocumentSync {:openClose true
                                                :change 1 # send the Full document https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocumentSyncKind
                                                }
                             :diagnosticProvider {:interFileDependencies true
                                                  :workspaceDiagnostics false}
                             :hoverProvider true
                             :signatureHelpProvider {:triggerCharacters [" "]}
                             :documentFormattingProvider true}
              :serverInfo {:name "janet-lsp"
                           :version version}}])

(defn on-shutdown
  ``
  Called by the LSP client to request that the server shut down.
  ``
  [state params]
  (setdyn :shutdown-received true)
  [:ok state :json/null])

(defn on-exit
  ``
  Called by the LSP client to request that the server process exit.
  ``
  [state params]
  (unless (dyn :shutdown-received)
    (ev/sleep 2)
    (quit 1))
  [:exit])

(defn on-janet-serverinfo
  ``
  Called by the LSP client to request information about the server.
  ``
  [state params]
  [:ok state :json/null])

(defn handle-message [message state]
  (let [id (get message "id")
        method (get message "method")
        params (get message "params")]
    (logging/log (string/format "handle-message received method request: %m" method))
    (case method
      "initialize" (on-initialize state params)
      "initialized" [:noresponse state]
      "textDocument/didOpen" (on-document-open state params)
      "textDocument/didChange" (on-document-change state params)
      "textDocument/completion" (on-completion state params)
      "completionItem/resolve" (on-completion-item-resolve state params)
      "textDocument/diagnostic" (on-document-diagnostic state params)
      "textDocument/formatting" (on-document-formatting state params)
      "textDocument/hover" (on-document-hover state params)
      "textDocument/signatureHelp" (on-document-signature-help state params)
      # "textDocument/references" (on-document-references state params) TODO: Implement this? See src/lsp/api.ts:103
      # "textDocument/documentSymbol" (on-document-symbols state params) TODO: Implement this? See src/lsp/api.ts:121
      "janet/serverInfo" (on-janet-serverinfo state params)
      "shutdown" (on-shutdown state params)
      "exit" (on-exit state params)
      [:noresponse state])))

(defn line-ending []
  (case (os/which)
    :windows "\r\n\r\n"
    "\n\n"))

(defn read-offset []
  (case (os/which)
    :windows 1
    2))

(defn write-response [file response]
  # Write headers
  (file/write file (string "Content-Length: " (length response) (line-ending)))

  # Write response
  (file/write file response)

  # Flush response
  (file/flush file))

(defn read-message []
  (let [input (file/read stdin :line)
        content-length (+ (parse-content-length input) (read-offset))
        input (file/read stdin content-length)]
    (json/decode input))) 

(defn message-loop [&named state]
  (let [message (read-message)] 
    (logging/log (string/format "got: %q" message))
    (match (handle-message message state)
      [:ok new-state & response] (do
                                 (logging/log "successful rpc")
                                 (write-response stdout (rpc/success-response (get message "id") ;response))
                                 (message-loop :state new-state))
      [:noresponse new-state] (message-loop :state new-state)

      [:error new-state err] (printf "unhandled error response: %m" err)
      [:exit] (do (file/flush stdout) (ev/sleep 2) nil))))

(defn find-all-module-files [path &opt search-jpm-tree explicit results]
  (default explicit true)
  (default results @[])
  (case (os/stat path :mode)
    :directory (when (or explicit
                         search-jpm-tree
                         (not= (path/basename path) "jpm_tree"))
                 (each entry (os/dir path)
                   (find-all-module-files (path/join path entry)
                                          search-jpm-tree false results)))
    :file (when (or explicit (not= (path/basename path) "project.janet"))
            (when (or (string/has-suffix? ".janet" path)
                      (string/has-suffix? ".jimage" path)
                      (string/has-suffix? ".so" path))
              (array/push results path))))
  results)

(defn find-unique-paths [paths]
  (->> (seq [found-path :in paths]
         (if (= (path/basename found-path) "init.janet")
           [(path/join (path/dirname found-path)
                       (string ":all:" (path/ext found-path)))
            (path/join (path/dirname found-path) "init.janet")]
           [(path/join (path/dirname found-path)
                       (string ":all:" (path/ext found-path)))]))
       flatten
       distinct
       (map |(path/relpath (os/cwd) $))
       (map |(string "./" $))))

(defn start-language-server []
  (print "Starting LSP")
  (when (dyn :debug) (spit "janetlsp.log.txt" ""))

  (merge-module root-env jpm-defs nil true)
  (setdyn :eval-env (make-env root-env))

  (each path (find-unique-paths (find-all-module-files (os/cwd) (not ((dyn :opts) :dont-search-jpm-tree))))
    (cond
      (string/has-suffix? ".janet" path) (array/push (((dyn :eval-env) 'module/paths) :value) [path :source])
      (string/has-suffix? ".so" path) (array/push (((dyn :eval-env) 'module/paths) :value) [path :native])
      (string/has-suffix? ".jimage" path) (array/push (((dyn :eval-env) 'module/paths) :value) [path :jimage])))

  (when (os/stat "./.janet-lsp/startup.janet")
    (merge-into root-env (dofile "./.janet-lsp/startup.janet")))

  (message-loop :state @{:documents @{}}))

(defn start-debug-console []
  (def host "127.0.0.1")
  (def port (if ((dyn :opts) :port) (string ((dyn :opts) :port)) "8037"))

  (print (string/format "Janet LSP Debug Console Active on %s:%s" host port))
  (print "Awaiting reports from running LSP...")

  (var linecount 0)

  (rpc/server
    {:print (fn [self x]
              (print (string/format "server:%d:> %s" linecount x))
              (file/flush stdout)
              (+= linecount 1))}
    host port))

(defn main [& args]

  (def parsed-args (cmd/args))

  (when (or (has-value? parsed-args "--version")
            (has-value? parsed-args "-v"))
    (print "Janet LSP v" version)
    (os/exit 0))

  (cmd/run
    (cmd/fn
      "A Language Server (LSP) for the Janet Programming Language."
      [[--dont-search-jpm-tree -j] (flag) "Whether to search `jpm_tree` for modules."
       --stdio (flag) "Use STDIO."
       [--debug -d] (flag) "Print debug messages."
       [--console -c] (flag) "Start a debug console instead of starting the Language Server."
       [--debug-port -p] (optional :int++) "What port to start or connect to the debug console on. Defaults to 8037."]

      (default stdio true)
      (default debug-port 8037)

      (def opts
        {:dont-search-jpm-tree dont-search-jpm-tree
         :stdio stdio
         :console console
         :debug-port debug-port})

      (setdyn :opts opts)
      (when debug (setdyn :debug true))
      (setdyn :out stderr)

      (if console
        (start-debug-console)
        (start-language-server)))
    parsed-args))
