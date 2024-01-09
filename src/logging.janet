(import spork/rpc)

(defn log [output]

  (comment pp (dyn :console))

  (comment print "Trying to ping console")
  (unless (dyn :client)
    (def opts (dyn :opts))

    (comment print "Trying to create a client")

    (def host "127.0.0.1")
    (def port (if (opts :port) (string (opts :port)) "8037"))

    (setdyn :client (try (rpc/client host port) ([_] "No debug console detected")))
    (comment pp (dyn :client)))

  (when (not= (dyn :client) "No debug console detected")
    (print (:print (dyn :client) output)))

  (when (dyn :debug)
    (spit "janetlsp.log.txt" (string output "\n") :a)
    (file/write stderr (string output "\n"))))
