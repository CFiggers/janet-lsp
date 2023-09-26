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

(deftest "word-at: line 0, character 12, of \"word not a word\n23\n45\"" 
  (test (word-at {:line 0 :character 12} "word not a word\n23\n45") {:range [11 12] :word "word"}))

(deftest "word-at: line 1, character 6, of \"\nword not a word\n23\n45\"" 
  (test (word-at {:line 1 :character 6} "\nword not a word\n23\n45") {:range [5 8] :word "not"}))

(deftest "word-at: line 0, character 0, of \"word\"" 
  (test (word-at {:line 0 :character 0} "word") {:range [0 0] :word "word"}))

(deftest "word-at: line 0, character 4, of \" word \"" 
  (test (word-at {:line 0 :character 4} " word ") {:range [1 5] :word "word"}))

(deftest "word-at: line 0, character 0, of \"  \"" 
  (test (word-at {:line 0 :character 0} "  ") {:range [0 0] :word ""}))