(use judge)
(import ./logging)

(defn make-module-entry [x]
  (logging/info (string/format "make-module-entry on %m" x) [:hover] 1)
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
              (let [parts (string/split "\n" d)]
                (if (every? ((juxt |(string/has-prefix? "(" $)
                                   |(string/has-suffix? ")" $))
                             (parts 0)))
                  (string/join (-> parts
                                   (array/insert 1 "```")
                                   (array/insert 0 "```janet")) "\n")
                  d))
              "No documentation found.\n"))))

(deftest "test make-module-entry: string/trim"
  (test (dyn (symbol "string/trim"))
    @{:doc "(string/trim str &opt set)\n\nTrim leading and trailing whitespace from a byte sequence. If the argument `set` is provided, consider only characters in `set` to be whitespace."
      :source-map ["src/core/string.c" 602 1]
      :value @string/trim})
  (test (make-module-entry (dyn (symbol "string/trim"))) 
        ````cfunction  
        src/core/string.c on line 602, column 1
        
        ```janet
        (string/trim str &opt set)
        ```
        
        Trim leading and trailing whitespace from a byte sequence. If the argument `set` is provided, consider only characters in `set` to be whitespace.
        ````)
  (test-stdout (print (make-module-entry (dyn (symbol "string/trim")))) ````
    cfunction  
    src/core/string.c on line 602, column 1
    
    ```janet
    (string/trim str &opt set)
    ```
    
    Trim leading and trailing whitespace from a byte sequence. If the argument `set` is provided, consider only characters in `set` to be whitespace.
  ````))

(deftest "test make-module-entry: length" 
  (test (dyn (symbol "length"))
    @{:doc "(length ds)\n\nReturns the length or count of a data structure in constant time as an integer. For structs and tables, returns the number of key-value pairs in the data structure."
      :value @length})
  (test (make-module-entry (dyn (symbol "length"))) 
        ````function
        
        ```janet
        (length ds)
        ```
        
        Returns the length or count of a data structure in constant time as an integer. For structs and tables, returns the number of key-value pairs in the data structure.
        ````)
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
  [sym env]
  (assert (not (nil? env)) "get-signature: env is nil")
  (logging/info (string/format "get-signature tried %m" (env sym)) [:hover] 1)
  (if-let [x (env sym)]
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
      (logging/info (string/format "Symbol %m not found" sym) [:hover]))))

(defn my-doc*
  "Get the documentation for a symbol in a given environment."
  [sym env]
  (assert env "my-doc*: env is nil")
  (logging/info (string/format "env is: %m" env) [:hover] 3)
  (logging/info (string/format "my-doc* tried: %m" (env sym)) [:hover] 3)
  (if-let [x (env sym)]
    (make-module-entry x)
    (if (has-value? '[break def do fn if quasiquote quote
                      set splice unquote upscope var while] sym)
      (make-special-form-entry sym)
      (do
        (logging/info "Not a symbol or a special form, seeking module" [:hover] 1)
        (logging/info (string/format "Regular module/find returns: %m" (module/find (string sym))) [:hover])
        (def module-find-fiber (fiber/new |(module/find (string sym)) :e env))
        (def mff-return (resume module-find-fiber))
        (logging/info (string/format "mff-return is: %m" mff-return) [:hover] 1)
        (def [fullpath mod-kind]
          (if (= :error (fiber/status module-find-fiber))
            nil
            mff-return))

        (logging/info (string/format "env has this in module/cache: %m" (env 'module/cache)) [:hover] 2)

        (logging/info (string/format "module-find-fiber got %m for %m" mff-return sym) [:hover] 1)
        (def module-cache-fiber (fiber/new |(in module/cache fullpath) :e env))
        (def mcf-return (resume module-cache-fiber))
        (cond
          (= :error (fiber/status module-cache-fiber)) (logging/err (string/format "symbol %m not found." sym) [:hover])
          mcf-return (make-module-entry {:module true
                                         :kind mod-kind
                                         :source-map [fullpath nil nil]
                                         :doc (in mcf-return :doc)})
          (logging/info (string/format "symbol %m not found." sym) [:hover]))))))

(deftest "testing my-doc*: string/trim"
  (def env (make-env root-env)) 
  (test (my-doc* 'string/trim env) 
        ````cfunction  
        src/core/string.c on line 602, column 1
        
        ```janet
        (string/trim str &opt set)
        ```
        
        Trim leading and trailing whitespace from a byte sequence. If the argument `set` is provided, consider only characters in `set` to be whitespace.
        ````))

(deftest "testing my-doc*: length"
  (def env (make-env root-env))
  (test-stdout (print (my-doc* 'length env)) ````
    function
    
    ```janet
    (length ds)
    ```
    
    Returns the length or count of a data structure in constant time as an integer. For structs and tables, returns the number of key-value pairs in the data structure.
  ````))

(deftest "testing my-doc*: set"
  (def env (make-env root-env))
  (test-stdout (print (my-doc* 'set env)) `
    special form
    
    (set ...)
    
    See https://janet-lang.org/docs/specials.html
  `))

(deftest "testing my-doc*: test-def"
  (def env (make-env root-env))
  (test (my-doc* 'test-def env)
    nil))

(deftest "testing my-doc*: wackythingthatdoesntexist"
  (def env (make-env root-env))
  (test (my-doc* (symbol "wackythingthatdoesntexist") env)
    nil))

(deftest "testing my-doc*: module entry"
  (def env (make-env root-env))
  (def import-fiber (fiber/new |(import spork/path) :e env))
  (def if-result (resume import-fiber))
  (if (= :error (fiber/status import-fiber))
    (error "fiber errored")
    (merge env (fiber/getenv import-fiber)))

  (test-stdout (print (my-doc* (symbol "spork/path") env)) `
    module (source)  
    /usr/local/lib/janet/spork/path.janet
    
    No documentation found.
    
  `))
