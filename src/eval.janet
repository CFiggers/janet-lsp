
(defn- no-side-effects
  `Check if form may have side effects. If returns true, then the src
  must not have side effects, such as calling a C function.`
  [src]
  (cond
    (tuple? src)
    (if (= (tuple/type src) :brackets)
      (all no-side-effects src))
    (array? src)
    (all no-side-effects src)
    (dictionary? src)
    (and (all no-side-effects (keys src))
         (all no-side-effects (values src)))
    true))

(defn- is-safe-def [x] (no-side-effects (last x)))

(def- safe-forms {'defn true 'varfn true 'defn- true 'defmacro true 'defmacro- true
                  'def is-safe-def 'var is-safe-def 'def- is-safe-def 'var- is-safe-def
                  'defglobal is-safe-def 'varglobal is-safe-def})

(def- importers {'import true 'import* true 'dofile true 'require true})
(defn- use-2 [evaluator args]
  (each a args (import* (string a) :prefix "" :evaluator evaluator)))

(defn- flycheck-evaluator
  ``An evaluator function that is passed to `run-context` that lints (flychecks) code.
  This means code will parsed and compiled, macros executed, but the code will not be run.
  Used by `flycheck`.``
  [thunk source env where]
    
  (when (tuple? source)
    (def head (source 0))
    (def safe-check
      (or
        (safe-forms head)
        (if (symbol? head)
          (if (string/has-prefix? "define-" head) is-safe-def))))
    (cond
      # Sometimes safe form
      (function? safe-check)
      (if (safe-check source) (thunk))
      # Always safe form
      safe-check
      (thunk)
      # Use
      (= 'use head)
      (use-2 flycheck-evaluator (tuple/slice source 1))
      # Import-like form
      (importers head)
      (let [[l c] (tuple/sourcemap source)
            newtup (tuple/setmap (tuple ;source :evaluator flycheck-evaluator) l c)]
        ((compile newtup env where))))))

(defn eval-buffer [str]
	(var state (string str))
	(defn chunks [buf _]
		(def ret state)
		(set state nil)
		(when ret
			(buffer/push-string buf str)
			(buffer/push-string buf "\n")))
		
	(var returnval :ok)
  	
	(try
		(run-context {:chunks chunks
			:on-compile-error (fn compile-error [msg errf where line col]
							(set returnval [:error {
									:message msg
									:location [line col]
							}]))
			
			:on-parse-error (fn parse-error [p x]
								(set returnval [:error {
									:message (parser/error p)
									:location (parser/where p)
								}])
							)
			
			:evaluator flycheck-evaluator
			
			:fiber-flags :i
			
			:source :eval-buffer})
		([err] 
			(set returnval [:error {
								:message err
								:location [0 0]
							}]))
	)

  	returnval)

# tests

# (pp (eval-buffer "(+ 2 2)"))

# (pp (eval-buffer "(2)"))

# (pp (eval-buffer "(+ 2 2"))

# check for side effects
# (pp (eval-buffer "(pp 42)"))

# (pp (eval-buffer "()"))