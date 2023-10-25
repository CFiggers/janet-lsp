(defn init-logger []
  (setdyn :out stderr)
  (setdyn :logfile (file/open "janetlslogs.txt" :w)))

(defn shutdown-logger []
  (file/close (dyn :logfile)))

(defn log [output]
  (spit "janetlsp.log.txt" (string output) :a)
  (file/write stderr (string output "\n")))