(use judge)

(defn make-module-entry [x] 
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
  (test (make-module-entry (dyn (symbol "string/trim"))) 
        ````
        cfunction\
        src/core/string.c on line 602, column 1
        
        ```janet
        (string/trim str &opt set)
        ```
        
        Trim leading and trailing whitespace from a byte sequence. If the argument `set` is provided, consider only characters in `set` to be whitespace.
        ````))

(deftest "test make-module-entry: length"
  (test (make-module-entry (dyn (symbol "length"))) 
        ````
        function

        ```janet
        (length ds)
        ```
        
        Returns the length or count of a data structure in constant time as an integer. For structs and tables, returns the number of key-value pairs in the data structure.````))

(deftest "test make-module-entry: def" 
  (defglobal "test-def" :a)
  (test (make-module-entry (dyn (symbol "test-def"))) "keyword\n\nNo documentation found.\n"))

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

(defn my-doc*
  "Get the documentation for a symbol in a given environment."
  [sym]
  
  (if-let [x (dyn sym)]
    (make-module-entry x)
    (if (index-of sym '[break def do fn if quasiquote quote
                        set splice unquote upscope var while])
      (make-special-form-entry sym)
      (do
        (def [fullpath mod-kind] (module/find (string sym)))
        (if-let [mod-env (in module/cache fullpath)]
          (make-module-entry {:module true
                              :kind mod-kind
                              :source-map [fullpath nil nil]
                              :doc (in mod-env :doc)})
          (print "symbol " sym " not found."))))))

(deftest "testing my-doc*: string/trim"
  (test (my-doc* 'string/trim) 
        ````
        cfunction\
        src/core/string.c on line 602, column 1
        
        ```janet
        (string/trim str &opt set)
        ```
        
        Trim leading and trailing whitespace from a byte sequence. If the argument `set` is provided, consider only characters in `set` to be whitespace.
        ````))

(deftest "testing my-doc*: length"
  (test (my-doc* 'length) 
        ````
        function

        ```janet
        (length ds)
        ```
        
        Returns the length or count of a data structure in constant time as an integer. For structs and tables, returns the number of key-value pairs in the data structure.````))

(deftest "testing my-doc*: set"
  (test (my-doc* 'set) 
        ````
        special form
        
        (set ...)
        
        See https://janet-lang.org/docs/specials.html
        ````))

(deftest "testing my-doc*: def"
  (defglobal "test-def" :a)
  (test (my-doc* 'test-def) "keyword\n\nNo documentation found.\n"))

(deftest "testing my-doc*: wackythingthatdoesntexist"
  (test-stdout (my-doc* (symbol "wackythingthatdoesntexist")) `
    symbol wackythingthatdoesntexist not found.
  `))