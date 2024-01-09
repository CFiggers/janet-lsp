(use judge)
(import ./logging)

(defn make-module-entry [x] 
  (comment logging/log (string/format "make-module-entry on %m" x))
  (let [bind-type (cond
                    (x :redef) (type (in (x :ref) 0))
                    (x :ref) (string :var " (" (type (in (x :ref) 0)) ")")
                    (x :macro) :macro
                    (x :module) (string :module " (" (x :kind) ")")
                    (type (x :value)))
        sm (x :source-map)
        d (x :doc)]
    (string bind-type
            (when-let [[path line col] sm]
              (string "  \n" path
                      (when line (string " on line " line))
                      (when col (string ", column " col))))
            "\n\n"
            (if d 
              (string/join (-> (string/split "\n" d)
                               (array/insert 1 "```")
                               (array/insert 0 "```janet")) "\n")
              "No documentation found.\n"))))

(deftest "test make-module-entry: string/trim"
  (test-stdout (print (make-module-entry (dyn (symbol "string/trim")))) ````
    cfunction  
    src/core/string.c on line 602, column 1
    
    ```janet
    (string/trim str &opt set)
    ```
    
    Trim leading and trailing whitespace from a byte sequence. If the argument `set` is provided, consider only characters in `set` to be whitespace.
  ````))

(deftest "test make-module-entry: length"
  (test-stdout (print (make-module-entry (dyn (symbol "length")))) ````
    function
    
    ```janet
    (length ds)
    ```
    
    Returns the length or count of a data structure in constant time as an integer. For structs and tables, returns the number of key-value pairs in the data structure.
  ````))

(deftest "test make-module-entry: def" 
  (defglobal "test-def" :a)
  (test-stdout (print (make-module-entry (dyn (symbol "test-def")))) `
    keyword
    
    No documentation found.
    
  `))

(defn make-special-form-entry
  [x]
  (string "special form\n\n"
          "(" x " ...)\n\n"
          "See https://janet-lang.org/docs/specials.html"))

(deftest "test make-special-form-entry"
  (test (make-special-form-entry 'set) 
        ````
        special form
        
        (set ...)
        
        See https://janet-lang.org/docs/specials.html
        ````))

(defn get-signature 
  "Look up the signature of a symbol in a given environment."
  [sym]
  (logging/log (string/format "get-signature tried %m" ((dyn :eval-env) sym)))
  (if-let [x ((dyn :eval-env) sym)]
    (-> (string/split "\n" (x :doc))
        (array/slice nil 1)
        (first))
    # (as-> (string/split "\n" (x :doc)) s
    #     (array/slice s nil 1)
    #     (first s)
    #     (peg/match '(* "(" :s* (<- (to (set " )"))) (any (* :s* (<- (to (set " )"))))) :s* ")") s))
    # (do (print "symbol " sym " not found.")
    #     [nil])
    (if (has-value? '[break def do fn if quasiquote quote
                      set splice unquote upscope var while] sym)
      (string "(" sym " ... )")
      (print "symbol " sym " not found."))))

(defn my-doc*
  "Get the documentation for a symbol in a given environment."
  [sym env]
  (logging/log (string/format "my-doc* tried: %m" ((dyn :eval-env) sym)))
  (if-let [x ((dyn :eval-env) sym)]
    (make-module-entry x)
    (if (has-value? '[break def do fn if quasiquote quote
                      set splice unquote upscope var while] sym)
      (make-special-form-entry sym)
      (do
        (def module-find-fiber (fiber/new |(module/find (string sym)) :e (dyn :eval-env)))
        (def mff-return (resume module-find-fiber))
        (def [fullpath mod-kind]
          (if (= :error (fiber/status module-find-fiber))
            nil
            mff-return))

        # (logging/log (string/format ":eval-env has this in module/cache: %m" ((dyn :eval-env) 'module/cache)))

        # (logging/log (string/format "module-find-fiber got %m for %m" mff-return sym))
        (def module-cache-fiber (fiber/new |(in module/cache fullpath) :e (dyn :eval-env)))
        (def mcf-return (resume module-cache-fiber))
        (cond
          (= :error (fiber/status module-cache-fiber)) (print "symbol " sym " not found.")
          mcf-return (make-module-entry {:module true
                                         :kind mod-kind
                                         :source-map [fullpath nil nil]
                                         :doc (in mcf-return :doc)})
          (print "symbol " sym " not found."))))))

(deftest "testing my-doc*: string/trim"
  (setdyn :eval-env (make-env root-env))
  (test-stdout (print (my-doc* 'string/trim (dyn :eval-env))) ````
    cfunction  
    src/core/string.c on line 602, column 1
    
    ```janet
    (string/trim str &opt set)
    ```
    
    Trim leading and trailing whitespace from a byte sequence. If the argument `set` is provided, consider only characters in `set` to be whitespace.
  ````))

(deftest "testing my-doc*: length"
  (setdyn :eval-env (make-env root-env))
  (test-stdout (print (my-doc* 'length (dyn :eval-env))) ````
    function
    
    ```janet
    (length ds)
    ```
    
    Returns the length or count of a data structure in constant time as an integer. For structs and tables, returns the number of key-value pairs in the data structure.
  ````))

(deftest "testing my-doc*: set"
  (setdyn :eval-env (make-env root-env))
  (test-stdout (print (my-doc* 'set (dyn :eval-env))) `
    special form
    
    (set ...)
    
    See https://janet-lang.org/docs/specials.html
  `))

(deftest "testing my-doc*: test-def"
  (setdyn :eval-env (make-env root-env))
  (test-stdout (print (my-doc* 'test-def (dyn :eval-env))) `
    symbol test-def not found.
    
  `))

(deftest "testing my-doc*: wackythingthatdoesntexist"
  (setdyn :eval-env (make-env root-env))
  (test-stdout (print (my-doc* (symbol "wackythingthatdoesntexist") (dyn :eval-env))) `
    symbol wackythingthatdoesntexist not found.
    
  `))

(deftest "testing my-doc*: module entry"
  (setdyn :eval-env (make-env root-env))
  (def import-fiber (fiber/new |(import spork/path) :e (dyn :eval-env)))
  (def if-result (resume import-fiber)) 
  (if (= :error (fiber/status import-fiber)) 
    (error "fiber errored")
    (merge (dyn :eval-env) (fiber/getenv import-fiber)))

  (test-stdout (print (my-doc* (symbol "spork/path") (dyn :eval-env))) `
    module (source)  
    /usr/local/lib/janet/spork/path.janet
    
    No documentation found.
    
  `))