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

(def version "0.0.10")
(def commit
  (with [proc (os/spawn ["git" "rev-parse" "--short" "HEAD"] :xp {:out :pipe})]
    (let [[out] (ev/gather
                  (ev/read (proc :out) :all)
                  (os/proc-wait proc))]
      (if out (string/trimr out) ""))))

(def jpm-defs (require "../libs/jpm-defs"))

(eachk k jpm-defs
  (match (type k) :symbol (put-in jpm-defs [k :source-map] nil) nil))

(defn parse-content-length [input]
  (scan-number (string/trim ((string/split ":" input) 1))))

(defn run-diagnostics [uri content]
  (let [items @[]
        [diagnostics env]
        (eval/eval-buffer content
                          (path/relpath
                            (os/cwd)
                            (if (string/has-prefix? "file:" uri)
                              (string/slice uri 5) uri)))]

    (logging/dbg (string/format "`eval-buffer` returned: %m" diagnostics) [:evaluation])

    (each res diagnostics
      (match res
        {:location [line col] :message message}
        (array/push items
                    {:range
                     {:start {:line (max 0 (dec line)) :character col}
                      :end {:line (max 0 (dec line)) :character col}}
                     :message message})))

    (logging/info (string/format "`run-diagnostics` is returning these errors: %m" items) [:evaluation])
    (logging/dbg (string/format "`run-diagnostics` is returning this eval-context: %m" env) [:evaluation])
    [items env]))

(def uri-percent-encoding-peg
  ~{:bang (/ (<- "%21") "!")
    :hash (/ (<- "%23") "#")
    :dollar (/ (<- "%24") "$")
    :amp (/ (<- "%26") "&")
    :tick (/ (<- "%27") "'")
    :lparen (/ (<- "%28") "(")
    :rparen (/ (<- "%29") ")")
    :star (/ (<- (* "%2" (+ "A" "a"))) "*")
    :plus (/ (<- (* "%2" (+ "B" "b"))) "+")
    :comma (/ (<- (* "%2" (+ "C" "c"))) ",")
    :slash (/ (<- (* "%2" (+ "F" "f"))) "/")
    :colon (/ (<- (* "%3" (+ "A" "a"))) ":")
    :semi (/ (<- (* "%3" (+ "B" "b"))) ";")
    :equals (/ (<- (* "%3" (+ "D" "d"))) "=")
    :question (/ (<- (* "%3" (+ "F" "f"))) "?")
    :at (/ (<- "%40") "@")
    :lbracket (/ (<- (* "%5" (+ "B" "b"))) "[")
    :rbracket (/ (<- (* "%5" (+ "D" "d"))) "]")
    :main (% (some (+ :bang :hash :dollar :amp :tick :lparen
                      :rparen :star :plus :comma :slash :colon
                      :semi :equals :question :at :lbracket
                      :rbracket '1)))})

(defn on-document-change
  ``
  Handler for the ["textDocument/didChange"](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_didChange) event.
  
  Params contains the new state of the document.
  ``
  [state params]
  (let [content (get-in params ["contentChanges" 0 "text"])
        uri (first (peg/match uri-percent-encoding-peg
                              (get-in params ["textDocument" "uri"])))]
    (put-in state [:documents uri :content] content)

    (if (dyn :push-diagnostics)
      (let [[diagnostics env] (run-diagnostics uri content)
            message {:method "textDocument/publishDiagnostics"
                     :params {:uri uri
                              :diagnostics diagnostics}}]
        (put-in state [:documents uri :eval-env] env)
        (logging/message message [:diagnostics])
        [:ok state message :notify true])
      [:noresponse state])))

(defn on-document-diagnostic [state params]
  (let [uri (first (peg/match uri-percent-encoding-peg
                              (get-in params ["textDocument" "uri"])))
        content (get-in state [:documents uri :content])
        [diagnostics env] (run-diagnostics uri content)
        message {:kind "full"
                 :items diagnostics}]
    (put-in state [:documents uri :eval-env] env)
    (logging/message message [:diagnostics])
    [:ok state message]))

(defn on-document-formatting [state params]
  (let [uri (first (peg/match uri-percent-encoding-peg
                              (get-in params ["textDocument" "uri"])))
        content (get-in state [:documents uri :content])
        new-content (freeze (fmt/format (string/slice content)))]
    (logging/info (string/format "old content: %m" content) [:formatting])
    (logging/info (string/format "new content: %m" new-content) [:formatting])
    (logging/info (string/format "formatting changed something: %m" (not= content new-content)) [:formatting])
    (if (= content new-content)
      (do
        (logging/info "No changes" [:formatting])
        [:ok state :json/null])
      (do
        (put-in state [:documents uri] @{:content new-content})
        (let [message [{:range {:start {:line 0 :character 0}
                                :end {:line 1000000 :character 1000000}}
                        :newText new-content}]]
          (logging/message message [:formatting])
          [:ok state message])))))

(defn on-document-open [state params]
  (let [content (get-in params ["textDocument" "text"])
        uri (first (peg/match uri-percent-encoding-peg
                              (get-in params ["textDocument" "uri"])))
        [diagnostics env] (run-diagnostics uri content)]
    (put-in state [:documents uri] @{:content content
                                     :eval-env env})
    (logging/info "Document opened" [:open] 1)
    (if (dyn :push-diagnostics)
      (let [message {:method "textDocument/publishDiagnostics"
                     :params {:uri uri
                              :diagnostics diagnostics}}]
        (put-in state [:documents uri :eval-env] env)
        (logging/message message [:diagnostics])
        [:ok state message :notify true])
      [:noresponse state])))

(defmacro binding-to-lsp-item
  "Takes a binding and returns a CompletionItem"
  [name eval-env]
  (with-syms [$name $eval-env]
    ~(let [,$name ,name
           ,$eval-env ,eval-env
           s (get-in ,$eval-env [,$name :value] ,$name)]
       (,logging/dbg (string/format "binding-to-lsp-item: s is %m" s) [:completion] 3)
       {:label ,$name :kind
        (case (type s)
          :symbol    12 :boolean   6
          :function  3  :cfunction 3
          :string    6  :buffer    6
          :number    6  :keyword   6
          :core/file 17 :core/peg  6
          :struct    6  :table     6
          :tuple     6  :array     6
          :fiber     6  :nil       6)})))

(defn on-completion [state params]
  (let [uri (first (peg/match uri-percent-encoding-peg
                              (get-in params ["textDocument" "uri"])))
        eval-env (get-in state [:documents uri :eval-env])
        bindings (seq [bind :in (all-bindings eval-env)]
                   (binding-to-lsp-item bind eval-env))
        message {:isIncomplete true
                 :items bindings}]
    (logging/message message [:completion])
    [:ok state message]))

(defn on-completion-item-resolve [state params]
  (var eval-env nil)
  (def lbl (get params "label"))
  (def envs (seq [docu :in (state :documents)]
              (docu :eval-env)))

  (each env envs
    (when (env (symbol lbl))
      (set eval-env env)
      (break)))

  (let [message {:label lbl
                 :documentation
                 {:kind "markdown"
                  :value (doc/my-doc*
                           (symbol lbl)
                           (or eval-env (make-env root-env)))}}]
    (logging/message message [:completion])
    [:ok state message]))

(defn on-document-hover [state params]
  (let [uri (first (peg/match uri-percent-encoding-peg
                              (get-in params ["textDocument" "uri"])))
        content (get-in state [:documents uri :content])
        eval-env (get-in state [:documents uri :eval-env])
        {"line" line "character" character} (get params "position")
        {:word hover-word :range [start end]} (lookup/word-at {:line line :character character} content)
        hover-text (doc/my-doc* (symbol hover-word) eval-env)
        _ (logging/log (string/format "on-document-hover: hover-text is %m" hover-text) [:hover])
        message (if (and hover-word hover-text)
                  {:contents {:kind "markdown"
                              :value hover-text}
                   :range {:start {:line line :character start}
                           :end {:line line :character end}}}
		  :json/null)]
    (logging/message message [:hover])
    [:ok state message]))

(defn on-document-signature-help [state params]
  (logging/info (string "on-signature-help state: ") [:signature])
  (logging/info (string/format "%q" state) [:signature])
  (logging/info (string "on-signature-help params: ") [:signature])
  (logging/info (string/format "%q" params) [:signature])
  (let [uri (first (peg/match uri-percent-encoding-peg
                              (get-in params ["textDocument" "uri"])))
        content (get-in state [:documents uri :content])
        eval-env (get-in state [:documents uri :eval-env])
        {"line" line "character" character} (get params "position")
        {:source sexp-text :range [start end]} (lookup/sexp-at {:line line :character character} content)
        function-symbol (or (first (peg/match '(* "(" (any :s) (<- (to " "))) sexp-text)) "none")
        signature (or (doc/get-signature (symbol function-symbol) eval-env) "not found")]
    (case signature
      "not found"
      (do (logging/info "No signature found" [:signature]) [:ok state :json/null])
      (let [message {:signatures [{:label signature}]}]
        (logging/message message [:signature])
        [:ok state message]))))

(defn on-initialize
  `` 
  Called by the LSP client to recieve a list of capabilities
  that this server provides so the client knows what it can request.
  ``
  [state params]
  (logging/info (string/format "on-initialize called with these params: %m" params) [:initialize])
  (if-let [diagnostic? (get-in params ["capabilities" "textDocument" "diagnostic"])]
    (setdyn :push-diagnostics false)
    (setdyn :push-diagnostics true))

  (let [message {:capabilities {:completionProvider {:resolveProvider true}
                                :textDocumentSync {:openClose true
                                                   :change 1 # send the Full document https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocumentSyncKind
                                                   }
                                :diagnosticProvider {:interFileDependencies true
                                                     :workspaceDiagnostics false}
                                :hoverProvider true
                                :signatureHelpProvider {:triggerCharacters [" "]}
                                :documentFormattingProvider true
                                :definitionProvider true}
                 :serverInfo {:name "janet-lsp"
                              :version version
                              :commit commit}}]
    (logging/message message [:initialize])
    [:ok state message]))

(defn on-shutdown
  ``
  Called by the LSP client to request that the server shut down.
  ``
  [state params]
  (setdyn :shutdown-received true)
  (logging/info "Shutting down" [:shutdown])
  [:ok state :json/null])

(defn on-exit
  ``
  Called by the LSP client to request that the server process exit.
  ``
  [state params]
  (unless (dyn :shutdown-received)
    (ev/sleep 2)
    (logging/info "Shutting down" [:exit])
    (quit 1))
  [:exit])

(defn on-janet-serverinfo
  ``
  Called by the LSP client to request information about the server.
  ``
  [state params]
  (let [message {:serverInfo {:name "janet-lsp"
                               :version version
                               :commit commit}}]
    (logging/message message [:info])
    [:ok state message]))

(defn on-document-definition
  ``
  Called by the LSP client to request the location of a symbol's definition.
  ``
  [state params]
  (let [request-uri (first (peg/match uri-percent-encoding-peg
                                      (get-in params ["textDocument" "uri"])))
        content (get-in state [:documents request-uri :content])
        eval-env (get-in state [:documents request-uri :eval-env])
        {"line" line "character" character} (get params "position")
        {:word define-word :range [start end]} (lookup/word-at {:line line :character character} content)]
    (logging/info (string/format ``
                                -------------------------
                                uri is: %s
                                content length is: %d
                                line is: %d
                                character is: %d
                                define word is: %s
                                start is: %d
                                end is: %d
                                -------------------------
                                ``
                                 request-uri (length content) line character define-word start end) [:definition])
    (logging/info (string/format "symbol is: %s" (symbol define-word)) [:definition])
    (logging/dbg (string/format "eval-env is: %m" eval-env) [:definition])
    (logging/info (string/format "symbol lookup is: %m" (get eval-env (symbol define-word) nil)) [:definition])
    (logging/info (string/format "`:source-map` is: %m" (get (get eval-env (symbol define-word) nil) :source-map nil)) [:definition])
    (if-let [symbol-lookup (get eval-env (symbol define-word) nil)
             [uri line col] (get symbol-lookup :source-map nil)
             found (os/stat (path/abspath uri))
             filepath (string "file:" (path/abspath uri))
             message {:uri filepath
                      :range {:start {:line (max 0 (dec line)) :character col}
                              :end {:line (max 0 (dec line)) :character col}}}]
      (do
        (logging/message message [:definition])
        [:ok state message])
      (do
        (logging/info "Couldn't find definition" [:definition])
        [:ok state :json/null]))))

(defn on-set-trace [state params]
  (logging/info (string/format "on-set-trace: %m" params) [:settrace])
  (case (params "value")
    "off" nil
    "messages" nil
    "verbose" nil)
  [:noresponse state])

(defn on-janet-tell-joke [state params]
  (let [message {:question "What's brown and sticky?"
                 :answer "A stick!"}]
    (logging/message message [:joke])
    [:ok state message]))

(defn on-enable-debug [state params]
  (let [message {:message "Enabled :debug"}]
    (setdyn :debug true)
    (try (spit "janetlsp.log" "")
         ([_] (logging/err "Tried to write to janetlsp.log, but couldn't" [:core])))
    (logging/message message [:debug])
    [:ok state message]))

(defn on-disable-debug [state params]
  (let [message {:message "Disabled :debug"}]
    (setdyn :debug false)
    (setdyn :log-level 2)
    (logging/message message [:debug])
    [:ok state message]))

(defn do-set-log-level [state params kind]
  (let [new-level-string (params "level")
        new-level ({"off" 0 "messages" 1 "verbose" 2 "veryverbose" 3} new-level-string)
        message {:message (string/format "Set %s to %s" kind new-level-string)}]
    (logging/message message [:loglevel])
    (setdyn kind new-level)
    [:noresponse state]))

(defmacro on-set-log-level [state params] 
  ~(,do-set-log-level ,state ,params :log-level))

(defmacro on-set-file-log-level [state params]
  ~(,do-set-log-level ,state ,params :log-to-file-level))

(defn handle-message [message state]
  (let [id (get message "id")
        method (get message "method")
        params (get message "params")]
    (logging/info (string/format "handle-message received method request: `%s`" method) [:core] 0 id)
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
      "textDocument/definition" (on-document-definition state params)
      "janet/serverInfo" (on-janet-serverinfo state params)
      "janet/tellJoke" (on-janet-tell-joke state params)
      "enableDebug" (on-enable-debug state params)
      "disableDebug" (on-disable-debug state params)
      "setLogLevel" (on-set-log-level state params)
      "setLogToFileLevel" (on-set-file-log-level state params)
      "shutdown" (on-shutdown state params)
      "exit" (on-exit state params)
      "$/setTrace" (on-set-trace state params)
      (do
        (logging/warn (string/format "Received unrecognized RPC: %m" method) [:handle])
        [:noresponse state]))))

(defn write-response [file response]
  # Write headers
  (file/write file (string "Content-Length: " (length response) (case (os/which)
                                                                  :windows "\n\n" "\r\n\r\n")))

  # Write response
  (file/write file response)

  # Flush response
  (file/flush file))

(defn read-message []
  (let [content-length-line (file/read stdin :line)
        _ (file/read stdin :line)
        input (file/read stdin (parse-content-length content-length-line))]
    (logging/info (string/format "received json rpc: %s" input) [:rpc :priority])
    (json/decode input)))

(defn message-loop [&named state]
  (logging/info "Loop enter" [:core] 1)
  (logging/dbg (string/format "current state is: %m" state) [:priority])
  (let [message (read-message)]
    (logging/dbg (string/format "got: %q" message) [:core])
    (match (try (handle-message message state) ([err fib] [:error state err fib]))
      [:ok new-state & response] (do
                                   (write-response stdout (rpc/success-response (get message "id") ;response))
                                   (logging/info "successful rpc" [:core] (get message "id"))
                                   (message-loop :state new-state))
      [:noresponse new-state] (message-loop :state new-state)

      [:error new-state err fib] (do
                                   (logging/err (string/format "%m" err) [:core])
                                   (debug/stacktrace fib err "")
                                   (message-loop :state new-state))
      [:exit] (do (file/flush stdout) (ev/sleep 0.1) (os/exit 0)))))

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
  (print "Starting LSP " version "-" commit)
  (when (dyn :debug)
    (try (spit "janetlsp.log" "")
      ([_] (logging/err "Tried to write to janetlsp.log txt, but couldn't" [:core]))))

  (merge-module root-env jpm-defs nil true)
  (setdyn :unique-paths (find-unique-paths (find-all-module-files (os/cwd) (not ((dyn :opts) :dont-search-jpm-tree)))))

  (when (os/stat "./.janet-lsp/startup.janet")
    (merge-into root-env (dofile "./.janet-lsp/startup.janet")))

  (message-loop :state @{:documents @{}}))

(defn start-debug-console []
  (def host "127.0.0.1")
  (def port (if ((dyn :opts) :port) (string ((dyn :opts) :port)) "8037"))

  (print "Janet LSP Debug Console v" version "-" commit)
  (print (string/format "Listening on %s:%s" host port))
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
    (print "Janet LSP v" version "-" commit)
    (os/exit 0))

  (cmd/run
    (cmd/fn
      "A Language Server (LSP) for the Janet Programming Language."
      [[--dont-search-jpm-tree -j] (flag) "Whether to search `jpm_tree` for modules."
       --stdio (flag) "Use STDIO."
       [--debug -d] (flag) "Print debug messages."
       [--log-level -l] (optional :int++ 1) "What level of logging to display. Defaults to 1."
       [--log-to-file-level -f] (optional :int++ 2) "What level of logging to write to the log file. Defaults to 2."
       [--log-category -L] (tuple :string) "Enable logging by category. For multiple categories, repeat the flag."
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
      (when debug (setdyn :debug true)) #(setdyn :debug true)
      (setdyn :log-level log-level) #(setdyn :log-level 2)
      (setdyn :log-to-file-level log-to-file-level) #(setdyn :log-level 3)
      (setdyn :log-categories @[:core ;(map keyword log-category)]) #(setdyn :log-categories [:core :priority :loglevel])
      (setdyn :out stderr)
      (put root-env :out stderr)

      (if console
        (start-debug-console)
        (start-language-server)))
    parsed-args))
