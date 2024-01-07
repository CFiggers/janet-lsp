(import spork/rpc)

(defn init-logger []
  (setdyn :out stderr)
  (spit "janetlsp.log.txt" ""))

(defn shutdown-logger []
  (file/close (dyn :logfile)))

(defn log [output]
  
  (pp (dyn :console))
  
  (when true
    (print "Trying to ping console")
    (unless (dyn :client)
      (def opts (dyn :opts))

      (print "Trying to create a client")
      
      (def host "127.0.0.1")
      (def port (if (opts :port) (string (opts :port)) "8037"))

      (setdyn :client (rpc/client host port))
      (pp (dyn :client)))

    (print (:print (dyn :client) output)))
  
  (when (dyn :debug)
    (spit "janetlsp.log.txt" (string output "\n") :a)
    (file/write stderr (string output "\n"))))