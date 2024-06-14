(use judge)

(use ../src/lookup)

(deftest "lookup"
  (test (lookup {:line 0 :character 0} "1\n23\n45") "1")
  (test (lookup {:line 1 :character 0} "1\n23\n45") "2")
  (test (lookup {:line 1 :character 1} "1\n23\n45") "3")
  (test (lookup {:line 2 :character 0} "1\n23\n45") "4")
  (test (lookup {:line 2 :character 1} "1\n23\n45") "5"))

(test (peg/match word-peg "(defn main [& args] (+ 1 1))")
      @[[0 "" 0]
        [1 "defn" 5]
        [6 "main" 10]
        [11 "[&" 13]
        [14 "args]" 19]
        [20 "" 20]
        [21 "+" 22]
        [23 "1" 24]
        [25 "1" 26]
        [27 "" 27]])

(test (peg/match word-peg "") nil)

(test (word-at {:line 0 :character 16} "(def- parse-peg\n") {:range [6 14] :word "parse-peg"})

(test (word-at {:line 1 :character 0} "(import )\n") {:range [0 0] :word ""})

(test (peg/match sexp-peg "(defn main [& args] (+ 1 1))") @[@[0 28] @[20 27]])

(test (peg/match sexp-peg "(+ 1 (- 1 1))") @[@[0 13] @[5 12]])

(deftest "advanced sexp-peg test"
  (def sample
    ``
(import spork)

(defmacro first-where [pred ds]
  (with-syms [$pred $ds]
    ~(let [,$pred ,pred ,$ds ,ds]
       (var ret "")
       (for i 0 (length ,$ds)
            (when (,$pred (,$ds i))
              (set ret (,$ds i))
              (break)))
       ret)))
                 
(defn main [& args]
  (+ 1 1)
  (let [a 1 b 2]
    (first-where |(< (first $) 0) [[-2 :a] [-1 :b] [0 :c]])))                 
``)
  (test (peg/match sexp-peg sample)
        @[@[0 14]
          @[16 263]
          @[50 262]
          @[78 261]
          @[114 126]
          @[134 249]
          @[143 156]
          @[169 248]
          @[175 192]
          @[183 191]
          @[207 225]
          @[216 224]
          @[240 247]
          @[282 390]
          @[304 311]
          @[314 389]
          @[333 388]
          @[347 362]
          @[350 359]]))

(deftest "slicing"
  (def sample
    ``
(import spork)

(defmacro first-where [pred ds]
  (with-syms [$pred $ds]
    ~(let [,$pred ,pred ,$ds ,ds]
       (var ret "")
       (for i 0 (length ,$ds)
            (when (,$pred (,$ds i))
              (set ret (,$ds i))
              (break)))
       ret)))
                 
(defn main [& args]
  (+ 1 1)
  (let [a 1 b 2]
    (first-where |(< (first $) 0) [[-2 :a] [-1 :b] [0 :c]])))                 
``)
  (test (map |[$ (string/slice sample ($ 0) ($ 1))] @[@[0 14] @[16 263] @[50 262] @[78 261] @[114 126] @[134 249] @[143 156] @[169 248] @[175 192] @[183 191] @[207 225] @[216 224] @[240 247] @[282 390] @[304 311] @[314 389] @[333 388] @[347 362] @[350 359]])
    @[[@[0 14] "(import spork)"]
      [@[16 263] "(defmacro first-where [pred ds]\n  (with-syms [$pred $ds]\n    ~(let [,$pred ,pred ,$ds ,ds]\n       (var ret \"\")\n       (for i 0 (length ,$ds)\n            (when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break)))\n       ret)))"]
      [@[50 262] "(with-syms [$pred $ds]\n    ~(let [,$pred ,pred ,$ds ,ds]\n       (var ret \"\")\n       (for i 0 (length ,$ds)\n            (when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break)))\n       ret))"]
      [@[78 261] "(let [,$pred ,pred ,$ds ,ds]\n       (var ret \"\")\n       (for i 0 (length ,$ds)\n            (when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break)))\n       ret)"]
      [@[114 126] "(var ret \"\")"]
      [@[134 249] "(for i 0 (length ,$ds)\n            (when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break)))"]
      [@[143 156] "(length ,$ds)"]
      [@[169 248] "(when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break))"]
      [@[175 192] "(,$pred (,$ds i))"]
      [@[183 191] "(,$ds i)"]
      [@[207 225] "(set ret (,$ds i))"]
      [@[216 224] "(,$ds i)"]
      [@[240 247] "(break)"]
      [@[282 390] "(defn main [& args]\n  (+ 1 1)\n  (let [a 1 b 2]\n    (first-where |(< (first $) 0) [[-2 :a] [-1 :b] [0 :c]])))"]
      [@[304 311] "(+ 1 1)"]
      [@[314 389] "(let [a 1 b 2]\n    (first-where |(< (first $) 0) [[-2 :a] [-1 :b] [0 :c]]))"]
      [@[333 388] "(first-where |(< (first $) 0) [[-2 :a] [-1 :b] [0 :c]])"]
      [@[347 362] "(< (first $) 0)"]
      [@[350 359] "(first $)"]]))

(test (sexp-at {:line 2 :character 3} "(def a-startup-symbol [])\n\nsymbol\n\n(import spork/argparse)")
  {:range @[2 3] :source ""})

(test (sexp-at {:character 15 :line 2} "(def a-startup-symbol [])\n\n(import spork/argparse)") 
      {:range @[27 50] :source "(import spork/argparse)"})

(deftest "sexp-at"
  (def sample
    ``
(import spork)

(defmacro first-where [pred ds]
  (with-syms [$pred $ds]
    ~(let [,$pred ,pred ,$ds ,ds]
       (var ret "")
       (for i 0 (length ,$ds)
            (when (,$pred (,$ds i))
              (set ret (,$ds i))
              (break)))
       ret)))
                 
(defn main [& args]
  (+ 1 1)
  (let [a 1 b 2]
    (first-where |(< (first $) 0) [[-2 :a] [-1 :b] [0 :c]])))                 
``)
  (test (map |[$ (sexp-at {:character $ :line 7} sample)] (range 0 37))
    @[[0
       {:range @[134 249]
        :source "(for i 0 (length ,$ds)\n            (when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break)))"}]
      [1
       {:range @[134 249]
        :source "(for i 0 (length ,$ds)\n            (when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break)))"}]
      [2
       {:range @[134 249]
        :source "(for i 0 (length ,$ds)\n            (when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break)))"}]
      [3
       {:range @[134 249]
        :source "(for i 0 (length ,$ds)\n            (when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break)))"}]
      [4
       {:range @[134 249]
        :source "(for i 0 (length ,$ds)\n            (when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break)))"}]
      [5
       {:range @[134 249]
        :source "(for i 0 (length ,$ds)\n            (when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break)))"}]
      [6
       {:range @[134 249]
        :source "(for i 0 (length ,$ds)\n            (when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break)))"}]
      [7
       {:range @[134 249]
        :source "(for i 0 (length ,$ds)\n            (when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break)))"}]
      [8
       {:range @[134 249]
        :source "(for i 0 (length ,$ds)\n            (when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break)))"}]
      [9
       {:range @[134 249]
        :source "(for i 0 (length ,$ds)\n            (when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break)))"}]
      [10
       {:range @[134 249]
        :source "(for i 0 (length ,$ds)\n            (when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break)))"}]
      [11
       {:range @[134 249]
        :source "(for i 0 (length ,$ds)\n            (when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break)))"}]
      [12
       {:range @[134 249]
        :source "(for i 0 (length ,$ds)\n            (when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break)))"}]
      [13
       {:range @[169 248]
        :source "(when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break))"}]
      [14
       {:range @[169 248]
        :source "(when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break))"}]
      [15
       {:range @[169 248]
        :source "(when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break))"}]
      [16
       {:range @[169 248]
        :source "(when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break))"}]
      [17
       {:range @[169 248]
        :source "(when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break))"}]
      [18
       {:range @[169 248]
        :source "(when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break))"}]
      [19
       {:range @[175 192]
        :source "(,$pred (,$ds i))"}]
      [20
       {:range @[175 192]
        :source "(,$pred (,$ds i))"}]
      [21
       {:range @[175 192]
        :source "(,$pred (,$ds i))"}]
      [22
       {:range @[175 192]
        :source "(,$pred (,$ds i))"}]
      [23
       {:range @[175 192]
        :source "(,$pred (,$ds i))"}]
      [24
       {:range @[175 192]
        :source "(,$pred (,$ds i))"}]
      [25
       {:range @[175 192]
        :source "(,$pred (,$ds i))"}]
      [26
       {:range @[175 192]
        :source "(,$pred (,$ds i))"}]
      [27
       {:range @[183 191] :source "(,$ds i)"}]
      [28
       {:range @[183 191] :source "(,$ds i)"}]
      [29
       {:range @[183 191] :source "(,$ds i)"}]
      [30
       {:range @[183 191] :source "(,$ds i)"}]
      [31
       {:range @[183 191] :source "(,$ds i)"}]
      [32
       {:range @[183 191] :source "(,$ds i)"}]
      [33
       {:range @[183 191] :source "(,$ds i)"}]
      [34
       {:range @[175 192]
        :source "(,$pred (,$ds i))"}]
      [35
       {:range @[169 248]
        :source "(when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break))"}]
      [36
       {:range @[169 248]
        :source "(when (,$pred (,$ds i))\n              (set ret (,$ds i))\n              (break))"}]]))

(deftest "to-index"
  (def sample
    ``
(import spork)

(defmacro first-where [pred ds]
  (with-syms [$pred $ds]
    ~(let [,$pred ,pred ,$ds ,ds]
       (var ret "")
       (for i 0 (length ,$ds)
            (when (,$pred (,$ds i))
              (set ret (,$ds i))
              (break)))
       ret)))
                 
(defn main [& args]
  (+ 1 1)
  (let [a 1 b 2]
    (first-where |(< (first $) 0) [[-2 :a] [-1 :b] [0 :c]])))                 
``)
  (to-index {:character 3 :line 7} sample))

(deftest "test word-peg1"
  (def sample "word not a word")
  (test (peg/match word-peg sample)
        @[[0 "word" 4]
          [5 "not" 8]
          [9 "a" 10]
          [11 "word" 14]]))

(deftest "test word-at1"
  (test (map |(word-at {:line 0 :character $} "word not a word") (range 15)) @[{:range [0 4] :word "word"} {:range [0 4] :word "word"} {:range [0 4] :word "word"} {:range [0 4] :word "word"} {:range [0 4] :word "word"} {:range [5 8] :word "not"} {:range [5 8] :word "not"} {:range [5 8] :word "not"} {:range [5 8] :word "not"} {:range [9 10] :word "a"} {:range [9 10] :word "a"} {:range [11 14] :word "word"} {:range [11 14] :word "word"} {:range [11 14] :word "word"} {:range [11 14] :word "word"}]))

(deftest "test word-peg2"
  (def sample "(defn main [& args] (print \"hello world\"))")
  (test (peg/match word-peg sample) @[[0 "" 0] [1 "defn" 5] [6 "main" 10] [11 "[&" 13] [14 "args]" 19] [20 "" 20] [21 "print" 26] [27 "\"hello" 33] [34 "world\"" 40] [41 "" 41]]))

(deftest "test word-peg3"
  (test (map |(word-at {:line 0 :character $} "(defn main [& args] (print \"hello world\"))") (range 42)) @[{:range [0 0] :word ""} {:range [1 5] :word "defn"} {:range [1 5] :word "defn"} {:range [1 5] :word "defn"} {:range [1 5] :word "defn"} {:range [1 5] :word "defn"} {:range [6 10] :word "main"} {:range [6 10] :word "main"} {:range [6 10] :word "main"} {:range [6 10] :word "main"} {:range [6 10] :word "main"} {:range [11 13] :word "[&"} {:range [11 13] :word "[&"} {:range [11 13] :word "[&"} {:range [14 19] :word "args]"} {:range [14 19] :word "args]"} {:range [14 19] :word "args]"} {:range [14 19] :word "args]"} {:range [14 19] :word "args]"} {:range [14 19] :word "args]"} {:range [20 20] :word ""} {:range [21 26] :word "print"} {:range [21 26] :word "print"} {:range [21 26] :word "print"} {:range [21 26] :word "print"} {:range [21 26] :word "print"} {:range [21 26] :word "print"} {:range [27 33] :word "\"hello"} {:range [27 33] :word "\"hello"} {:range [27 33] :word "\"hello"} {:range [27 33] :word "\"hello"} {:range [27 33] :word "\"hello"} {:range [27 33] :word "\"hello"} {:range [27 33] :word "\"hello"} {:range [34 40] :word "world\""} {:range [34 40] :word "world\""} {:range [34 40] :word "world\""} {:range [34 40] :word "world\""} {:range [34 40] :word "world\""} {:range [34 40] :word "world\""} {:range [34 40] :word "world\""} {:range [41 41] :word ""}]))

(deftest "word-at-peg: line 0, character 12, of \"word not a word\n23\n45\""
  (test (word-at {:line 0 :character 12} "word not a word\n23\n45") {:range [11 14] :word "word"}))

(deftest "word-at-peg: line 1, character 6, of \"\nword not a word\n23\n45\""
  (test (word-at {:line 1 :character 6} "\nword not a word\n23\n45") {:range [5 8] :word "not"}))

(deftest "word-at-peg: line 0, character 0, of \"word\""
  (test (word-at {:line 0 :character 0} "word") {:range [0 3] :word "word"}))

(deftest "word-at-peg: line 0, character 4, of \" word \""
  (test (word-at {:line 0 :character 4} " word ") {:range [1 5] :word "word"}))

(deftest "word-at-peg: line 0, character 0, of \"  \""
  (test (word-at {:line 0 :character 0} "  ") {:range [1 3] :word ""}))
