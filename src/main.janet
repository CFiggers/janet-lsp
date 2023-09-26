(import ./rpc)
(import spork/json :as json)
(import ./eval)
(import ./lookup)

(defn parse-content-length [input]
  (int/to-number 
    (int/u64 
      (string/trim 
        (in (string/split ":" input) 1)))))

(defn init-logger []
  (setdyn :out stderr)
  (setdyn :logfile (file/open "janetlslogs.txt" :w)))

(defn shutdown-logger []
  (file/close (dyn :logfile)))

(defn log [output]
  (file/write (dyn :logfile) (string output "\n"))
  (file/write stderr (string output "\n"))
  (file/flush (dyn :logfile)))

(defn on-document-change 
  ``
  Handler for the ["textDocument/didChange"](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocument_didChange) event.
  
  Params contains the new state of the document.
  ``
  [state params]
  (let [
    content (get-in params ["contentChanges" 0 "text"])
    uri (get-in params ["textDocument" "uri"])
  ]

  (put-in state [:documents uri] @{:content content})

  (pp (eval/eval-buffer content))

  [:ok state {}]))


(defn on-document-diagnostic [state params]
  (var uri (get-in params ["textDocument" "uri"]))

  (var content (get-in state [:documents uri :content]))

  (var items @[])

  (match (eval/eval-buffer content)
    :ok ()
    [:error {:location [line col] :message message}] 
    (array/push items 
      {
        :range 
        {
          :start { :line line :character col }
          :end   { :line line :character col }
        }
        :message message
      }
    ))

  [:ok state {
    :kind "full"
    :items items
  }])

(defn on-document-open [state params]
  (let [
    content (get-in params ["textDocument" "text"])
    uri (get-in params ["textDocument" "uri"])
  ]

  (put-in state [:documents uri] @{:content content}))

  [:ok state {}])

(defn on-completion [state params]
  [:ok state {
			:isIncomplete true
			:items (map (fn [x] {:label x}) (all-bindings))
	}])

(defn on-completion-item-resolve [state params]
  (let [label (get params "label")]
    [:ok state {
      :label label
      :documentation {
        :kind "markdown"
        :value (get (dyn (symbol label)) :doc)
      }
    }]))

(defn on-document-hover [state params]
  (var uri (get-in params ["textDocument" "uri"]))
  (var content (get-in state [:documents uri :content]))

  (def {"line" line "character" character} (get params "position"))

  (def {:word hover-word  :range [start end]} (lookup/word-at {:line line :character character} content))

  [:ok state (match hover-word
    nil {}
    _ {
      :contents {
        :kind "markdown"
        :value (get (dyn (symbol hover-word)) :doc)
      }
      :range {
        :start {:line line :character start}
        :end {:line line :character end}
      }
    }
  )]
  )

(defn on-initialize 
  `` 
  Called by the LSP client to recieve a list of capabilities
  that this server provides so the client knows what it can request.
  ``
  [state params]
  [:ok state {
    :capabilities {
      :completionProvider {
        :resolveProvider true
      }
      :textDocumentSync {
        :openClose true
        :change 1 # send the Full document https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#textDocumentSyncKind
      }
      :diagnosticProvider {
        :interFileDependencies true
	      :workspaceDiagnostics false
      }
      :hoverProvider true
    }
  }])

(defn handle-message [message state]
  (log "method:")
  (log (get message "method"))

  (let [id (get message "id") method (get message "method") params (get message "params")]
    (case method
      "initialize" (on-initialize state params)
      "initialized" [:ok state {}]
      "textDocument/didOpen" (on-document-open state params)
      "textDocument/didChange" (on-document-change state params)
      "textDocument/completion" (on-completion state params)
      "completionItem/resolve" (on-completion-item-resolve state params)
      "textDocument/diagnostic" (on-document-diagnostic state params)
      "textDocument/hover" (on-document-hover state params)
      [:ok state {}])))

(defn line-ending [] 
  (case (os/which)
    :windows "\n\n"
    "\r\n\r\n"
  ))

(defn read-offset [] 
  (case (os/which)
    :windows 1
    2
  ))

(defn write-response [file response]
  # Write headers
  (file/write file (string "Content-Length: " (length response) (line-ending)))
  (log (string "Content-Length: " (length response) "\n\n"))

  # Write response
  (file/write file response)
  (log response)

  # Flush response
  (file/flush file))


(defn init-state []
  @{:documents @{}})


(defn read-message []
  (log "Waiting for message\n")
  
  (let [input (file/read stdin :line)]
    (log input)

    (let [content-length (+ (parse-content-length input) (read-offset))]

      (log (string "reading " content-length))

      (let [input (file/read stdin content-length)]
        (log input)
        (json/decode input)
      )
    )
  )
)

(defn message-loop [state]  
  (let [message (read-message)]
    (match (handle-message message state)
      [:ok new-state response] (do 
        (pp "new-state:")
        (pp new-state)
        (write-response stdout (rpc/success-response (get message "id") response))
        (message-loop state))

      [:error new-state error] (log "unhandled error response")
    )
  )
)

(defn main [args &]
  (init-logger)

  # TODO: Don't hardcode this.
  # Before evaling document, set for eval environment only?
  (array/push module/paths ["/home/john/projects/janet-language-server/server-janet/src/:all:.janet" :source])
  (array/push module/paths ["/home/john/projects/janet-language-server/server-janet/src/:all:.janet" :native])
  (array/push module/paths ["/home/john/projects/janet-language-server/server-janet/src/:all:.janet" :jimage])

  (let [state (init-state)]
    (message-loop state))

  (shutdown-logger)
)
