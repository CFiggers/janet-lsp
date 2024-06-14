(import ../libs/jayson)

(use judge)

(defn line-ending []
  (case (os/which)
    :windows "\r\n\r\n"
    "\n\n"))

(defn write-output [handle response]
  # Write headers
  (:write handle (string "Content-Length: " (length response) (line-ending)))

  # Write response
  (:write handle (string response (if (string/has-suffix? "\n" response) "" "\n")))

  # Flush response
#   (file/flush handle)
  )

(defn start-lsp []
  (var request-id 0)
  (def janet-lsp (os/spawn ["janet" "./src/main.janet" "--debug"] :p {:in :pipe :out :pipe}))

  (def to-lsp (janet-lsp :in))
  (def from-lsp (janet-lsp :out))

  (write-output to-lsp
                (string (jayson/encode
                         {:id request-id
                          :method :initialize
                          :params {:rootUri (os/cwd)
                                   :capabilities []}})))
  (+= request-id 1)

  (print (:read (janet-lsp :out) 1024))
  {:process janet-lsp
   :request-id request-id})

(defn exit-lsp [context]
  (def lsp-handle (context :process))
  (var request-id (context :request-id))
  (write-output (lsp-handle :in)
                (string (jayson/encode
                         {:id request-id
                          :method :shutdown})))
  (+= request-id 1)

  (print (:read (lsp-handle :out) 1024))

  (write-output (lsp-handle :in)
                (string (jayson/encode
                         {:id request-id
                          :method :exit})))
  (print (:read (lsp-handle :out) 1024)))


(deftest-type with-process
  :setup    (fn []
              (start-lsp))
  :reset    (fn [context]
              (printf "context is: %q" context)
              (exit-lsp context)
              (start-lsp))
  :teardown (fn [context] ))

(deftest: with-process "Starts and exits" [context]
  (printf "context is: %q" context)
  (test (= true true) true))