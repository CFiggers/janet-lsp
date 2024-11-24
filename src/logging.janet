(use judge)

(import spork/rpc)

(defn log [output categories &opt level]

  (unless (dyn :debug) (break))

  (unless (dyn :client)
    (def opts (dyn :opts))

    (def host "127.0.0.1")
    (def port (if (and opts (opts :port)) (string (opts :port)) "8037"))

    (setdyn :client (try (rpc/client host port) ([_] "No debug console detected"))))

  (when (not= (dyn :client) "No debug console detected")
    (print (:print (dyn :client) output)))

  (when (dyn :debug)
    # Always log to file
    # (try (spit "janetlsp.log.txt" (string output "\n") :a)
    #     ([_]))
    (when (and
           # Category Match
           (or (empty? (dyn :log-categories)) # No log categories are specified
               (empty? categories) # OR, this log doesn't specify a categories (default to sending it)
               (any? (map |(has-value? (dyn :log-categories) $) categories))) # Any of this log's categories is in the target categories
           # Level Match
           (or (nil? level) # There is no level specified on this log
               (<= level (dyn :log-level)))) # OR, this log's level is <= the specified level

      (comment (eprintf "Debug is: %m" (dyn :debug))

               (eprintf "Is :log-categories empty? %m" (empty? (dyn :log-categories)))
               (eprintf "Is categories nil? %m" (nil? categories))
               (eprintf "Does :log-categories have categories in it? %m" (has-value? (dyn :log-categories) categories))
               (eprintf "first condition is: %m"
                        (or (empty? (dyn :log-categories))
                            (nil? categories)
                            (has-value? (dyn :log-categories) categories)))


               (eprintf "is level nil? %m" (nil? level))
               (eprintf "is level high enough? %m" (<= level (dyn :log-level)))
               (eprintf "second condition %m" (or (nil? level)
                                                  (<= level (dyn :log-level)))))
      (try (spit "janetlsp.log.txt" (string output "\n") :a)
        ([_]))
      (file/write stderr (string output "\n"))))
  nil)

(defmacro info [output categories &opt level id]
  (with-syms [$output $categories $level $id]
    ~(let [,$output (case (type ,output) :string ,output (string/format "%m" ,output)) 
           ,$categories ,categories 
           ,$level ,level 
           ,$id ,id] 
       (,log (string/format "[INFO%s:%s] %s" (if ,$id (string ":" ,$id) "") (first ,$categories) ,$output) 
            ,$categories ,$level))))

(defmacro message [output categories &opt level id]
  (with-syms [$output $categories $level $id]
    ~(let [,$output (case (type ,output) :string ,output (string/format "%m" ,output))
           ,$categories ,categories
           ,$level ,level
           ,$id ,id]
       (,log (string/format "[MESSAGE%s:%s] %s" (if ,$id (string ":" ,$id) "") (first ,$categories) ,$output)
            ,$categories ,$level))))

(defmacro err [output categories &opt level id]
  (with-syms [$output $categories $level $id]
    ~(let [,$output (case (type ,output) :string ,output (string/format "%m" ,output))
           ,$categories ,categories
           ,$level ,level
           ,$id ,id]
       (,log (string/format "[ERROR%s:%s] %s" (if ,$id (string ":" ,$id) "") (first ,$categories) ,$output)
             ,$categories ,$level))))
