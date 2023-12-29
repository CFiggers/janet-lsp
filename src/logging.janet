(defn init-logger []
  (setdyn :out stderr)
  (spit "janetlsp.log.txt" ""))

(defn shutdown-logger []
  (file/close (dyn :logfile)))

(defn log [output]
  (when (dyn :debug)
    (spit "janetlsp.log.txt" (string output "\n") :a)
    (file/write stderr (string output "\n"))))