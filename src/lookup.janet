(use judge)

(defn lookup [{:line line :character character} source]
  (string/from-bytes (((string/split "\n" source) line) character)))

(deftest "lookup"
  (test (lookup {:line 0 :character 0} "1\n23\n45") "1"))

(defmacro letv [bindings & body]
  ~(do ,;(seq [[k v] :in (partition 2 bindings)] ['var k v]) ,;body))

(deftest "Check letv"
  (test (macex1 '(letv [thing "something"
                        another 123]
                       (print thing)
                       (print another)
                       (set thing "other thing")
                       (print thing)))
    [do
     [var thing "something"]
     [var another 123]
     [print thing]
     [print another]
     [set thing "other thing"]
     [print thing]]))

(defn word-at [location source] 
  (letv [{:character character-pos :line line-pos} location
         line            ((string/split "\n" source) line-pos)
         backward        @[]
         forward         @[]
         offset-backward 0
         offset-forward  0
         done            false]

    (loop [i :range [character-pos (length line)]
           :let [char (string/from-bytes (line i))]]
      (if (and (not done) (all |(not= char $) [" " "(" ")"]))
        (array/push forward char)
        (do
          (set done true)
          (set offset-forward (length forward)))))

    (set done false)
    (loop [i :range [(- (dec character-pos)) 1]
           :let [char (string/from-bytes (line (- i)))]] 
      (if (and (not done) (all |(not= char $) [" " "(" ")"]))
        (array/insert backward 0 char)
        (do
          (set done true)
              (set offset-backward (length backward)))))

    (set offset-backward (- character-pos offset-backward))
    (set offset-forward (+ offset-forward character-pos))

    {:word (string/join (array/concat backward forward))
     :range [offset-backward offset-forward]}))

(def word-peg
  (peg/compile 
   ~{:s (set " \t\0\f\v") :s* (any :s) :s+ (some :s)
     :paren (/ (* (column) (set "()") (constant "") (column)) ,|[(dec $0) $1 (- $2 2)])
     :ws (/ (* (column) :s+ (constant "") (column)) ,|$&)
     :word (/ (* (column) (<- (some (if-not (set " ()") 1))) (? (+ :s ")")) (column)) ,|[(dec $0) $1 (- $2 2)])
     :main (some (+ :paren :ws :word -1))}))

# TODO: Test this more and then substitute in rest of LSP
(defn word-at-peg [location source]
  (let [{:character character-pos :line line-pos} location
        line ((string/split "\n" source) line-pos)
        parsed (sort-by last (peg/match word-peg line))
        word (first (filter |(>= ($ 2) character-pos) parsed))]
    {:range [(word 0) (word 2)] :word (word 1)}))

(deftest "test word-peg1"
  (def sample "word not a word")
  (test (peg/match word-peg sample)
    @[[0 "word" 4]
      [5 "not" 8]
      [9 "a" 10]
      [11 "word" 14]]))

(deftest "test word-peg2"
  (def sample "(defn main [& args] (print \"hello world\"))")
  (test (peg/match word-peg sample)
    @[[0 "" 0]
      [1 "defn" 5]
      [6 "main" 10]
      [11 "[&" 13]
      [14 "args]" 19]
      [20 "" 20]
      [21 "print" 26]
      [27 "\"hello" 33]
      [34 "world\"" 40]
      [41 "" 41]]))

(deftest "test word-peg3"
  (test (word-at-peg {:line 0 :character 13} "(defn main [& args] (print \"hello world\"))") 
        {:range [11 13] :word "[&"}))

(test (map |[$ (word-at {:line 0 :character $} "word   not a word\n23\n45")
               (word-at-peg {:line 0 :character $} "word   not a word\n23\n45")] 
           (range (length "word   not a word")))
  @[[0
     {:range [0 4] :word "word"}
     {:range [0 4] :word "word"}]
    [1
     {:range [1 4] :word "word"}
     {:range [0 4] :word "word"}]
    [2
     {:range [2 4] :word "word"}
     {:range [0 4] :word "word"}]
    [3
     {:range [3 4] :word "word"}
     {:range [0 4] :word "word"}]
    [4
     {:range [4 4] :word "word"}
     {:range [0 4] :word "word"}]
    [5
     {:range [5 5] :word ""}
     {:range [6 8] :word ""}]
    [6
     {:range [6 6] :word ""}
     {:range [6 8] :word ""}]
    [7
     {:range [7 10] :word "not"}
     {:range [6 8] :word ""}]
    [8
     {:range [7 10] :word "not"}
     {:range [6 8] :word ""}]
    [9
     {:range [7 10] :word "not"}
     {:range [7 10] :word "not"}]
    [10
     {:range [7 10] :word "not"}
     {:range [7 10] :word "not"}]
    [11
     {:range [11 12] :word "a"}
     {:range [11 12] :word "a"}]
    [12
     {:range [11 12] :word "a"}
     {:range [11 12] :word "a"}]
    [13
     {:range [13 13] :word "word"}
     {:range [13 16] :word "word"}]
    [14
     {:range [13 14] :word "word"}
     {:range [13 16] :word "word"}]
    [15
     {:range [13 15] :word "word"}
     {:range [13 16] :word "word"}]
    [16
     {:range [13 16] :word "word"}
     {:range [13 16] :word "word"}]])

(test (map |[$ (= (word-at {:line 0 :character $} "(defn main [& args] (print \"hello world\"))")
                  (word-at-peg {:line 0 :character $} "(defn main [& args] (print \"hello world\"))"))
             ] (range (length "(defn main [& args] (print \"hello world\"))")))
  @[[0 true]
    [1 true]
    [2 true]
    [3 true]
    [4 true]
    [5 true]
    [6 true]
    [7 true]
    [8 true]
    [9 true]
    [10 true]
    [11 true]
    [12 true]
    [13 true]
    [14 true]
    [15 true]
    [16 true]
    [17 true]
    [18 true]
    [19 true]
    [20 true]
    [21 true]
    [22 true]
    [23 true]
    [24 true]
    [25 true]
    [26 true]
    [27 true]
    [28 true]
    [29 true]
    [30 true]
    [31 true]
    [32 true]
    [33 true]
    [34 true]
    [35 true]
    [36 true]
    [37 true]
    [38 true]
    [39 true]
    [40 true]
    [41 true]])

(deftest "word-at: line 0, character 12, of \"word not a word\n23\n45\"" 
  (test (word-at {:line 0 :character 12} "word not a word\n23\n45") {:range [11 12] :word "word"}))

(deftest "word-at-peg: line 0, character 12, of \"word not a word\n23\n45\"" 
  (test (word-at-peg {:line 0 :character 12} "word not a word\n23\n45") {:range [11 14] :word "word"}))

(deftest "word-at: line 1, character 6, of \"\nword not a word\n23\n45\"" 
  (test (word-at {:line 1 :character 6} "\nword not a word\n23\n45") {:range [5 8] :word "not"}))

(deftest "word-at-peg: line 1, character 6, of \"\nword not a word\n23\n45\"" 
  (test (word-at-peg {:line 1 :character 6} "\nword not a word\n23\n45") {:range [5 8] :word "not"}))

(deftest "word-at: line 0, character 0, of \"word\"" 
  (test (word-at {:line 0 :character 0} "word") {:range [0 0] :word "word"}))

(deftest "word-at-peg: line 0, character 0, of \"word\"" 
  (test (word-at-peg {:line 0 :character 0} "word") {:range [0 3] :word "word"}))

(deftest "word-at: line 0, character 4, of \" word \"" 
  (test (word-at {:line 0 :character 4} " word ") {:range [1 5] :word "word"}))

(deftest "word-at-peg: line 0, character 4, of \" word \"" 
  (test (word-at-peg {:line 0 :character 4} " word ") {:range [1 5] :word "word"}))

(deftest "word-at: line 0, character 0, of \"  \"" 
  (test (word-at {:line 0 :character 0} "  ") {:range [0 0] :word ""}))

(deftest "word-at-peg: line 0, character 0, of \"  \"" 
  (test (word-at-peg {:line 0 :character 0} "  ") {:range [1 3] :word ""}))