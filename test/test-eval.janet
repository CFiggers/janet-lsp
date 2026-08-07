(use judge)

(use ../src/eval)

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
