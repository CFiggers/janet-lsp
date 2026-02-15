(use judge)
(import ./logging)

(varfn is-safe-def :private [])

(var- safe-forms {})

(defn- no-side-effects
  `Check if form may have side effects. If returns true, then the src
  must not have side effects, such as calling a C function.`
  [src]
  (cond
    (tuple? src) (cond
                   (= (tuple/type src) :brackets) (all no-side-effects src)
                   (= true (get safe-forms (src 0))) true
                   (get safe-forms (src 0)) ((get safe-forms (src 0)) src)
                   (get (dyn 'safe-forms) :flycheck))
    (array? src) (all no-side-effects src)
    (dictionary? src) (and (all no-side-effects (keys src))
                           (all no-side-effects (values src)))
    true))

(varfn is-safe-def :private [x]
  (or (filter |(= $ :flycheck) (tuple/slice x 2 -2))
      (no-side-effects (last x))))

(set safe-forms {'defn true 'varfn true 'defn- true 'defmacro true 'defmacro- true
                 'def is-safe-def 'var is-safe-def 'def- is-safe-def 'var- is-safe-def
                 'defglobal is-safe-def 'varglobal is-safe-def
                 #'merge-into true
                 'fn true
                 #'keyword true 'short-fn true
})

(def- importers {'import true 'import* true 'dofile true 'require true})

(defn- use-2 [evaluator args]
  (each a args (import* (string a) :prefix "" :evaluator evaluator)))

(defn- flycheck-evaluator
  ``An evaluator function that is passed to `run-context` that lints (flychecks) code.
  This means code will parsed and compiled, macros executed, but the code will not be run.
  Used by `flycheck`.``
  [thunk source env where]

  (when (tuple? source)
    (let [head (source 0)
          safe-check (or (safe-forms head)
                         (when (and (symbol? head) (string/has-prefix? "define-" head))
                           is-safe-def)
                         (get (dyn head) :flycheck))]
      (cond
        (= 'upscope head)
        (each f (tuple/slice source 1)
          (flycheck-evaluator (compile f) f env where))
        # Use
        (= 'use head) (use-2 flycheck-evaluator (tuple/slice source 1))
        # Import-like form
        (importers head)
        (if (or (string/has-prefix? "." (source 1))
                (string/has-prefix? "/" (source 1)))
          (let [[line column] (tuple/sourcemap source)
                newtup (tuple/setmap (tuple ;source :evaluator flycheck-evaluator) line column)]
            ((compile newtup env where)))
          (thunk))
        # Sometimes safe form
        (function? safe-check) (if (safe-check source) (thunk))
        # Always safe form
        safe-check (thunk)))))

(defn eval-buffer [str &opt filename]
  (logging/info (string/format "`eval-buffer` received filename: `%s`" (or filename "none")) [:evaluation])
  (logging/dbg (string/format "`eval-buffer` received str: `%s`" str) [:evaluation])

  (default filename "eval.janet")
  (var state (string str))
  (defn chunks [buf parser]
    (def ret state)
    (set state nil)
    (when ret
      (buffer/push-string buf str)
      (buffer/push-string buf "\n")))

  (def fresh-env (make-env root-env))

  (each path (or (dyn :unique-paths) @[])
    (cond
      (string/has-suffix? ".janet" path) (array/push ((fresh-env 'module/paths) :value) [path :source])
      (string/has-suffix? ".so" path) (array/push ((fresh-env 'module/paths) :value) [path :native])
      (string/has-suffix? ".jimage" path) (array/push ((fresh-env 'module/paths) :value) [path :jimage])))

  (def eval-fiber
    (fiber/new
      |(do (var returnval @[])
         (try (run-context {:chunks chunks
                            :on-compile-error (fn compile-error [msg errf where line col]
                                                (array/push returnval {:message (string/format "compile error: %s" msg)
                                                                       :location [line col]
                                                                       :severity 1}))
                            :on-compile-warning (fn compile-warning [msg errf where line col]
                                                  (array/push returnval {:message (string/format "compile warning: %s" msg)
                                                                         :location [line col]
                                                                         :severity 2}))
                            :on-parse-error (fn parse-error [p x]
                                              (array/push returnval {:message (string/format "parse error: %s" (parser/error p))
                                                                     :location (parser/where p)
                                                                     :severity 1}))
                            :evaluator flycheck-evaluator
                            :fiber-flags :i
                            :source filename})
           ([err fib]
             (array/push returnval {:message (string/format "runtime error: %s" err)
                                    :location (tuple/slice ((first (debug/stack fib)) :slots) 1 3)
                                    :severity 1})))
         returnval) :e fresh-env))
  (def eval-fiber-return (resume eval-fiber))
  (logging/dbg (string/format "`eval-buffer` is returning: %m" eval-fiber-return) [:evaluation])
  [eval-fiber-return fresh-env])

# tests

(deftest "test eval-buffer: (+ 2 2)"
  (test (eval-buffer "(+ 2 2)" "test.janet") [@[] @{:current-file "test.janet"}]))

(deftest "test eval-buffer: (2)"
  (test (eval-buffer "(2)" "test.janet")
    [@[{:location [1 1]
        :message "compile error: 2 expects 1 argument, got 0"
        :severity 1}]
     @{:current-file "test.janet"}]))

(deftest "test eval-buffer: (+ 2 2"
  (test (eval-buffer "(+ 2 2" "test.janet")
    [@[{:location [2 0]
        :message "parse error: unexpected end of source, ( opened at line 1, column 1"
        :severity 1}]
     @{:current-file "test.janet"}]))

# check for side effects
(deftest "test eval-buffer: (pp 42)"
  (test (eval-buffer "(pp 42)") [@[] @{:current-file "eval.janet"}]) "test.janet")

(deftest "test eval-buffer: ()"
  (test (eval-buffer "()" "test.janet")
    [@[{:location [1 1]
        :message "runtime error: expected integer key for tuple in range [0, 0), got 0"
        :severity 1}]
     @{:current-file "test.janet"}]))

(deftest "import with no argument should give a parse error"
  (test (eval-buffer "(import )" "test.janet")
    [@[{:location [1 1]
        :message "compile error: macro arity mismatch, expected at least 1, got 0"
        :severity 1}]
     @{:current-file "test.janet"}]))

(deftest "import with no matching module should give a parse error"
  (test (eval-buffer "(import randommodulethatdoesntexist)" "test.janet")
    [@[{:location [1 1]
        :message "runtime error: could not find module randommodulethatdoesntexist:\n    /home/deck/.local/share/janet/lib/randommodulethatdoesntexist.jimage\n    /home/deck/.local/share/janet/lib/randommodulethatdoesntexist.janet\n    /home/deck/.local/share/janet/lib/randommodulethatdoesntexist/init.janet\n    /home/deck/.local/share/janet/lib/randommodulethatdoesntexist.so"
        :severity 1}]
     @{:current-file "test.janet"}]))

(deftest "does not error because string/trim is a cfunction"
  (test (eval-buffer "(string/trim )") [@[] @{:current-file "eval.janet"}]) "test.janet")

(deftest "should give a parser error 2"
  (test (eval-buffer "(freeze )" "test.janet")
    [@[{:location [1 1]
        :message "compile error: <function freeze> expects at least 1 argument, got 0"
        :severity 1}]
     @{:current-file "test.janet"}]))

(deftest "multiple compiler errors"
  (test (eval-buffer "(freeze ) (import )" "test.janet")
    [@[{:location [1 1]
        :message "compile error: <function freeze> expects at least 1 argument, got 0"
        :severity 1}
       {:location [1 11]
        :message "compile error: macro arity mismatch, expected at least 1, got 0"
        :severity 1}]
     @{:current-file "test.janet"}]))
