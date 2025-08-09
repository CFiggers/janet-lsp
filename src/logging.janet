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
    
    # Ensure log file exists
    (unless (os/stat "janetlsp.log")
      (spit "janetlsp.log" ""))

    # Log to file, all categories but only if this log's level is <= the specified level
    (when (or (nil? level) # There is no level specified on this log
              (<= level (dyn :log-to-file-level)))
      (try
        (do
          (def logfiles (filter |(string/has-prefix? "janetlsp.log" $) (os/dir ".")))
          (when (> (get (os/stat "janetlsp.log") :size) 5000000)
            (when (and (has-value? logfiles "janetlsp.log") (has-value? logfiles "janetlsp.log.1"))
              (when (and (has-value? logfiles "janetlsp.log.1") (has-value? logfiles "janetlsp.log.2"))
                (when (and (has-value? logfiles "janetlsp.log.2") (has-value? logfiles "janetlsp.log.3"))
                  (when (and (has-value? logfiles "janetlsp.log.3") (has-value? logfiles "janetlsp.log.4"))
                    (when (and (has-value? logfiles "janetlsp.log.4") (has-value? logfiles "janetlsp.log.5"))
                      (os/rm "janetlsp.log.5"))
                    (os/rename "janetlsp.log.4" "janetlsp.log.5"))
                  (os/rename "janetlsp.log.3" "janetlsp.log.4"))
                (os/rename "janetlsp.log.2" "janetlsp.log.3"))
              (os/rename "janetlsp.log.1" "janetlsp.log.2"))
            (os/rename "janetlsp.log" "janetlsp.log.1")
            (spit "janetlsp.log" ""))
          (spit "janetlsp.log" (string output "\n") :a))
        ([e]
         (file/write stderr (string/format "error while trying to write to log file: %q\n" e)))))

    # Log to console, only specified categories and if this log's level is >= the specified level
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

      (file/write stderr (string output "\n"))))
  nil)

(defmacro dbg [output categories &opt level id]
  (default level 3)
  (with-syms [$output $categories $level $id]
    ~(let [,$output (case (type ,output) :string ,output (string/format "%m" ,output))
           ,$categories ,categories
           ,$level ,level
           ,$id ,id]
       (,log (string/format "[DEBUG%s:%s] %s" (if ,$id (string ":" ,$id) "") (first ,$categories) ,$output)
             ,$categories ,$level))))

(defmacro info [output categories &opt level id]
  (default level 2)
  (with-syms [$output $categories $level $id]
    ~(let [,$output (case (type ,output) :string ,output (string/format "%m" ,output))
           ,$categories ,categories
           ,$level ,level
           ,$id ,id]
       (,log (string/format "[INFO%s:%s] %s" (if ,$id (string ":" ,$id) "") (first ,$categories) ,$output)
             ,$categories ,$level))))

(defmacro message [output categories &opt level id]
  (default level 2)
  (with-syms [$output $categories $level $id]
    ~(let [,$output (case (type ,output) :string ,output (string/format "%m" ,output))
           ,$categories ,categories
           ,$level ,level
           ,$id ,id]
       (,log (string/format "[MESSAGE%s:%s] %s" (if ,$id (string ":" ,$id) "") (first ,$categories) ,$output)
             ,$categories ,$level))))

(defmacro warn [output categories &opt level id]
  (default level 1)
  (with-syms [$output $categories $level $id]
    ~(let [,$output (case (type ,output) :string ,output (string/format "%m" ,output))
           ,$categories ,categories
           ,$level ,level
           ,$id ,id]
       (,log (string/format "[WARNING%s:%s] %s" (if ,$id (string ":" ,$id) "") (first ,$categories) ,$output)
             ,$categories ,$level))))

(defmacro err [output categories &opt level id]
  (default level 0)
  (with-syms [$output $categories $level $id]
    ~(let [,$output (case (type ,output) :string ,output (string/format "%m" ,output))
           ,$categories ,categories
           ,$level ,level
           ,$id ,id]
       (,log (string/format "[ERROR%s:%s] %s" (if ,$id (string ":" ,$id) "") (first ,$categories) ,$output)
             ,$categories ,$level))))

(defmacro fatal [output categories &opt level id]
  (default level 0)
  (with-syms [$output $categories $level $id]
    ~(let [,$output (case (type ,output) :string ,output (string/format "%m" ,output))
           ,$categories ,categories
           ,$level ,level
           ,$id ,id]
       (,log (string/format "[FATAL%s:%s] %s" (if ,$id (string ":" ,$id) "") (first ,$categories) ,$output)
             ,$categories ,$level))))

(defmacro unknown [output categories &opt level id]
  (default level 0)
  (with-syms [$output $categories $level $id]
    ~(let [,$output (case (type ,output) :string ,output (string/format "%m" ,output))
           ,$categories ,categories
           ,$level ,level
           ,$id ,id]
       (,log (string/format "[UNKNOWN%s:%s] %s" (if ,$id (string ":" ,$id) "") (first ,$categories) ,$output)
             ,$categories ,$level))))
