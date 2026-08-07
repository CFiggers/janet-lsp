(use judge)

(use ../src/doc)

# Testing make-module-entry

(deftest "test make-module-entry: string/trim"
  (test (dyn (symbol "string/trim"))
        @{:doc "(string/trim str &opt set)\n\nTrim leading and trailing whitespace from a byte sequence. If the argument `set` is provided, consider only characters in `set` to be whitespace."
          :source-map ["src/core/string.c" 605 1]
          :value @string/trim})
  (test (make-module-entry (dyn (symbol "string/trim")))
        "cfunction  \nsrc/core/string.c on line 605, column 1\n\n```janet\n(string/trim str &opt set)\n```\n\nTrim leading and trailing whitespace from a byte sequence. If the argument `set` is provided, consider only characters in `set` to be whitespace.")
  (test-stdout (print (make-module-entry (dyn (symbol "string/trim")))) ````
    cfunction  
    src/core/string.c on line 605, column 1
    
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

(deftest "test make-special-form-entry"
  (test (make-special-form-entry 'set)
        ````
        special form
        
        (set ...)
        
        See https://janet-lang.org/docs/specials.html
        ````))

### Testing my-doc*

(deftest "testing my-doc*: string/trim"
  (def env (make-env root-env))
  (test (my-doc* 'string/trim env)
        "cfunction  \nsrc/core/string.c on line 605, column 1\n\n```janet\n(string/trim str &opt set)\n```\n\nTrim leading and trailing whitespace from a byte sequence. If the argument `set` is provided, consider only characters in `set` to be whitespace."))

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
    /home/deck/.local/share/janet/lib/spork/path.janet
    
    No documentation found.
    
  `))
