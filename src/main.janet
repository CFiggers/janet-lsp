(import ../libs/jayson :prefix "json/")
# (import spork/json)
(import spork/path :as path)
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
    
    (pp (eval/eval-buffer content))

    [:noresponse]))


(defn on-document-diagnostic [state params] 
  (let [uri (get-in params ["textDocument" "uri"])
        content (get-in state [:documents uri :content])
        items @[]]

    (match (eval/eval-buffer content)
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

  [:noresponse])

(defn on-completion [state params]
  [:ok state {:isIncomplete true
              :items (map (fn [x] {:label x}) (all-bindings))}])

(defn on-completion-item-resolve [state params]
  (let [label (get params "label")]
    [:ok state {:label label
                :documentation {:kind "markdown"
                                :value (get (dyn (symbol label)) :doc)}}]))

(defn on-document-hover [state params]
  (let [uri (get-in params ["textDocument" "uri"])
        content (get-in state [:documents uri :content])
        {"line" line "character" character} (get params "position")
        {:word hover-word  :range [start end]} (lookup/word-at {:line line :character character} content)
        hover-text (doc/my-doc* (symbol hover-word))]
    [:ok state (match hover-word
                 nil {}
                 _ {:contents {:kind "markdown"
                               :value hover-text}
                    :range {:start {:line line :character start}
                            :end {:line line :character end}}})]))

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
                             :hoverProvider true}
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
    (case method
      "initialize" (on-initialize state params)
      "initialized" [:noresponse]
      "textDocument/didOpen" (on-document-open state params)
      "textDocument/didChange" (on-document-change state params)
      "textDocument/completion" (on-completion state params)
      "completionItem/resolve" (on-completion-item-resolve state params)
      "textDocument/diagnostic" (on-document-diagnostic state params)
      "textDocument/hover" (on-document-hover state params)
      "shutdown" (on-shutdown state params)
      "exit" (on-exit state params)
      [:noresponse])))

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

(defn init-state []
  @{:documents @{}})

(defn read-message []
  (let [input (file/read stdin :line)
        content-length (+ (parse-content-length input) (read-offset))
        input (file/read stdin content-length)]
    # (print "spork/json and jayson are identical: " (deep= (json/decode input) (jayson/decode input)))
    (json/decode input)))

(defn message-loop [state]
  (let [message (read-message)]
    (match (handle-message message state)
      [:ok new-state response] (do
                                 (write-response stdout (rpc/success-response (get message "id") response))
                                 (message-loop state))
      [:noresponse] (message-loop state)

      [:error new-state error] (pp "unhandled error response")
      [:exit] (do (file/flush stdout) (ev/sleep 2) nil))))

(defn find-all-janet-files [path &opt explicit results]
  (default explicit true)
  (default results @[])
  (let [basename |(last (string/split "/" $))]
    (case (os/stat path :mode)
      :directory
      (when (or explicit (not= (basename path) "jpm_tree"))
        (each entry (os/dir path)
          (find-all-janet-files (string path "/" entry) false results)))
      :file
      (when (or explicit (not= (basename path) "project.janet"))
        (if (string/has-suffix? ".janet" path) (array/push results path))))
    results))

(deftest "test find-all-janet-files"
  (test (find-all-janet-files (os/cwd))
    @["/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/main.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/rpc.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/logging.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/lookup.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/doc.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/src/eval.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/libs/jpm-defs.janet"
      "/home/caleb/projects/vscode/vscode-janet-plus-plus/janet-lsp/test/basic.janet"]))

(defn find-unique-paths [paths]
  (->> (seq [found-path :in paths]
        (path/join (path/dirname found-path)
                   (string ":all:" (path/ext found-path)))) 
       distinct 
       (map |((case (os/which) 
                    :linux path/posix/relpath
                    :windows path/win32/relpath) (os/cwd) $))
       (map |(string "./" $))))

(deftest "test find-unique-paths"
  (test (find-unique-paths (find-all-janet-files (os/cwd)))
    @["./janet-lsp/src/:all:.janet"
      "./janet-lsp/libs/:all:.janet"
      "./janet-lsp/test/:all:.janet"]))

(defn main [args &]
  (setdyn :out stderr)

  (merge-module (curenv) jpm-defs) 
  
  (each path (find-unique-paths (find-all-janet-files (os/cwd)))
    (array/push module/paths [path :source])
    (array/push module/paths [path :native])
    (array/push module/paths [path :jimage]))

  (let [state (init-state)]
    (message-loop state)))
