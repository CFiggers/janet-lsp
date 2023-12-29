(import ../libs/jayson :prefix "json/")
# (import spork/json)
(import spork/path)
(import spork/argparse)
(import ./rpc)
(import ./eval)
(import ./lookup)
(import ./doc)
(import ./logging)

(use judge)

(def jpm-defs (require "../libs/jpm-defs"))

(eachk k jpm-defs
  (match (type k) :symbol (put-in jpm-defs [k :source-map] nil) nil))

(defn parse-content-length [input]
  (scan-number (string/trim ((string/split ":" input) 1))))

(deftest "parse-content-length"
  (test (parse-content-length "000:123:456:789") 123)
  (test (parse-content-length "123:456:789") 456)
  (test (parse-content-length "0123:456::::789") 456))

(defn on-document-change 
  ``
  Handler for the ["textDocument/didChange"](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_didChange) event.
  
  Params contains the new state of the document.
  ``
  [state params]
  (let [content (get-in params ["contentChanges" 0 "text"])
        uri (get-in params ["textDocument" "uri"])]

    (put-in state [:documents uri] @{:content content})
    
    (pp (eval/eval-buffer content (path/basename uri)))

    [:noresponse state]))


(defn on-document-diagnostic [state params] 
  (let [uri (get-in params ["textDocument" "uri"])
        content (get-in state [:documents uri :content])
        items @[]]

    (match (eval/eval-buffer content (path/basename uri))
      :ok ()
      [:error {:location [line col] :message message}]
      (array/push items
                  {:range
                   {:start {:line (max 0 (dec line)) :character col}
                    :end   {:line (max 0 (dec line)) :character col}}
                   :message message}))

    [:ok state {:kind "full"
                :items items}]))

(defn on-document-open [state params]
  (let [content (get-in params ["textDocument" "text"])
        uri (get-in params ["textDocument" "uri"])]

  (put-in state [:documents uri] @{:content content}))

  [:noresponse state])

(defn binding-type [x] 
  (let [s (get ((dyn :eval-env) x) :value x)]
    (case (type s)
      :symbol    12  :boolean   6
      :function  3   :cfunction 3
      :string    6   :buffer    6
      :number    6   :keyword   6
      :core/file 17  :core/peg  6
      :struct    6   :table     6
      :tuple     6   :array     6
      :fiber     6   :nil       6)))

(defn binding-to-lsp-item
    "Takes a binding and returns a CompletionItem"
    [name]
    {:label name :kind (binding-type name)})

(deftest "test binding-to-lsp-item"
  (setdyn :eval-env (table/proto-flatten (make-env root-env)))
  
  (def bind-fiber (fiber/new |(do (defglobal "anil" nil)
                                  (defglobal "hello" 'world)
                                  (defglobal "atuple" [:a 1])
                                  true) :e (dyn :eval-env)))
  (def bf-return (resume bind-fiber))

  (def test-cases @[['hello :symbol] [true :boolean] [% :function]
                    [abstract? :cfunction] ["Hello world" :string]
                    [@"Hello world":buffer] [123 :number]
                    [:keyword :keyword] [stderr :core/file]
                    [(peg/compile 1) :core/peg] [{:a 1} :struct]
                    [@{:a 1} :table] ['atuple :tuple]
                    [@[:a 1]:array] # [(coro) :fiber]
                    ['anil :nil]])

  (test (map (juxt 1 |(binding-to-lsp-item (first $))) test-cases)
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
        {:word hover-word  :range [start end]} (lookup/word-at {:line line :character character} content)
        hover-text (doc/my-doc* (symbol hover-word) (dyn :eval-env))]
    [:ok state (match hover-word
                 nil {}
                 _ {:contents {:kind "markdown"
                               :value hover-text}
                    :range {:start {:line line :character start}
                            :end {:line line :character end}}})]))

(defn on-signature-help [state params]
  (comment logging/log (string "on-signature-help state: "))
  (comment logging/log (string/format "%q" state))
  (comment logging/log (string "on-signature-help params: "))
  (comment logging/log (string/format "%q" params))
  (let [uri (get-in params ["textDocument" "uri"])
        content (get-in state [:documents uri :content])
        {"line" line "character" character} (get params "position")
        {:source sexp-text :range [start end]} (lookup/sexp-at {:line line :character character} content)
        function-symbol (first (peg/match '(* "(" (any :s) (<- (to " "))) sexp-text))
        _ (logging/log (string/format "signature help request for: %s" function-symbol))
        # [fn-name & params] (doc/get-signature (symbol function-symbol))
        # _ (logging/log (string/format "got fn-name: %s" fn-name))
        # _ (logging/log (string/format "got params: %q" params))
        signature (doc/get-signature (symbol function-symbol))
        _ (logging/log (string/format "got signature: %s" signature))]
    [:ok state (match signature
                 nil :json/null
                 _ [{:label signature}])]))

(defn on-initialize 
  `` 
  Called by the LSP client to recieve a list of capabilities
  that this server provides so the client knows what it can request.
  ``
  [state params] 
  [:ok state {:capabilities {:completionProvider {:resolveProvider true}
                             :textDocumentSync {:openClose true
                                                :change 1 # send the Full document https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocumentSyncKind
                                                }
                             :diagnosticProvider {:interFileDependencies true
                                                  :workspaceDiagnostics false}
                             :hoverProvider true
                            #  :signatureHelpProvider {:triggerCharacters [" "]}
                             }
              :serverInfo {:name "janet-lsp"
                           :version "0.0.1"}}])

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
      "textDocument/hover" (on-document-hover state params)
      "textDocument/signatureHelp" (on-signature-help state params)
      "shutdown" (on-shutdown state params)
      "exit" (on-exit state params)
      [:noresponse state])))

(defn line-ending []
  (case (os/which)
    :windows "\n\n"
    "\r\n\r\n"))

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
    # (print "spork/json and jayson are identical: " (deep= (json/decode input) (jayson/decode input)))
    (json/decode input)))

(defn message-loop [&named state]
  (let [message (read-message)]
    (match (handle-message message state)
      [:ok new-state response] (do
                                 # (logging/log (string/format "successful rpc: \n - New state: %m \n - Response: %m" new-state response))
                                 (write-response stdout (rpc/success-response (get message "id") response))
                                 (message-loop :state new-state))
      [:noresponse new-state] (message-loop :state new-state)

      [:error new-state error] (pp "unhandled error response")
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
    :file      (when (or explicit (not= (path/basename path) "project.janet"))
                 (when (or (string/has-suffix? ".janet"  path)
                           (string/has-suffix? ".jimage" path)
                           (string/has-suffix? ".so"     path))
                   (array/push results path))))
  results)

(deftest "test find-all-module-files"
  (test (find-all-module-files (os/cwd))
    @["/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/main.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/rpc.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/logging.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/misc.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/lookup.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/doc.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/eval.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/libs/jpm-defs.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/libs/jayson.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/test/basic.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/build/janet-lsp.jimage"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/dist/janet-lsp.jimage"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/test/syntax-highlighting.janet"]))

(deftest "test find-all-module-files"
  (test (find-all-module-files (os/cwd) true)
    @["/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/main.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/rpc.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/logging.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/misc.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/lookup.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/doc.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/eval.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/libs/jpm-defs.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/libs/jayson.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/test/basic.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/build/janet-lsp.jimage"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/dist/janet-lsp.jimage"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/test/syntax-highlighting.janet"]))

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

(deftest "test find-unique-paths"
  (test (find-unique-paths (find-all-module-files (os/cwd)))
    @["./janet-lsp/src/:all:.janet"
      "./janet-lsp/libs/:all:.janet"
      "./janet-lsp/test/:all:.janet"
      "./janet-lsp/build/:all:.jimage"
      "./dist/:all:.jimage"
      "./test/:all:.janet"]))

(deftest "test find-unique-paths"
  (test (find-unique-paths (find-all-module-files (os/cwd) true))
    @["./janet-lsp/src/:all:.janet"
      "./janet-lsp/libs/:all:.janet"
      "./janet-lsp/test/:all:.janet"
      "./janet-lsp/build/:all:.jimage"
      "./dist/:all:.jimage"
      "./test/:all:.janet"]))

(def argparse-params
  ["A Language Server Protocol (LSP)-compliant language server implemented in Janet."
   "dont-search-jpm-tree" {:kind :flag
                           :short "j"
                           :help "Whether to search `jpm_tree` for modules."}
   "stdio" {:kind :flag
            :help "Whether to respond to stdio"}])

(defn main [name & args]
  (setdyn :out stderr)
  # (setdyn :debug true)
  (when (dyn :debug) (spit "janetlsp.log.txt" ""))
  (def cli-args (argparse/argparse ;argparse-params))

  (setdyn :eval-env (make-env root-env))

  (merge-module (dyn :eval-env) (((curenv) 'module/paths) :value))
  (merge-module (dyn :eval-env) jpm-defs)

  (each path (find-unique-paths (find-all-module-files (os/cwd) (not (cli-args "dont-search-jpm-tree"))))
    (cond
      (string/has-suffix? ".janet" path) (array/push (((dyn :eval-env) 'module/paths) :value) [path :source])
      (string/has-suffix? ".so" path) (array/push (((dyn :eval-env) 'module/paths) :value) [path :native])
      (string/has-suffix? ".jimage" path) (array/push (((dyn :eval-env) 'module/paths) :value) [path :jimage])))

  (when (os/stat "./.janet-lsp/startup.janet")
    (eval/eval-buffer (slurp "./.janet-lsp/startup.janet") "startup.janet"))

  (message-loop :state @{:documents @{}}))
