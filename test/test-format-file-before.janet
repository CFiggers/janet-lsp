# Uncomment to use `janet-lang/spork` helper functions.
# (use spork)
(import jgraph)

(def- parse-peg
  "Peg to parse Janet with extra information, namely comments."
  (peg/compile
    ~{:ws (/ (* ($) (<- (+ (set " \t\r\f\0\v"))) ($)) ,|[$1 :whitespace {:from $0 :to $2}])
      :newline (/ (* ($) (<- "\n") ($)) ,|[$1 :newline {:from $0 :to $2}])
      :readermac (set "';~,|")
      :symchars (+ (range "09" "AZ" "az" "\x80\xFF") (set "!$%&*+-./:<?=>@^_"))
      :token (some :symchars)
      :hex (range "09" "af" "AF")
      :escape (* "\\" (+ (set "ntrzfev0\"\\")
                         (* "x" :hex :hex)
                         (* "u" :hex :hex :hex :hex)
                         (* "U" :hex :hex :hex :hex :hex :hex)
                         (error (constant "bad hex escape"))))
      :comment (/ (* ($) (* "#" '(any (if-not (+ "\n" -1) 1))) ($)) ,|[$1 :comment {:from $0 :to $2}])
      :span (/ (* ($) ':token ($)) ,|[$1 :span {:from $0 :to $2}])
      :bytes '(* "\"" (any (+ :escape (if-not "\"" 1))) "\"")
      :string (/ (* ($) :bytes ($)) ,|[$1 :string {:from $0 :to $2}])
      :buffer (/ (* ($) (* "@" :bytes) ($)) ,|[$1 :buffer {:from $0 :to $2}])
      :long-bytes '{:delim (some "`")
                    :open (capture :delim :n)
                    :close (cmt (* (not (> -1 "`")) (-> :n) ':delim) ,=)
                    :main (drop (* :open (any (if-not :close 1)) :close))}
      :long-string (/ (* ($) :long-bytes ($)) ,|[$1 :string {:from $0 :to $2}])
      :long-buffer (/ (* ($) (* "@" :long-bytes) ($)) ,|[$1 :buffer {:from $0 :to $2}])
      :ptuple (/ (* ($) (group (* "(" (any :input) (+ ")" (error)))) ($)) ,|[$1 :ptuple {:from $0 :to $2}])
      :btuple (/ (* ($) (group (* "[" (any :input) (+ "]" (error)))) ($)) ,|[$1 :btuple {:from $0 :to $2}])
      :struct (/ (* ($) (group (* "{" (any :input) (+ "}" (error)))) ($)) ,|[$1 :struct {:from $0 :to $2}])
      :parray (/ (* ($) (group (* "@(" (any :input) (+ ")" (error)))) ($)) ,|[$1 :array {:from $0 :to $2}])
      :barray (/ (* ($) (group (* "@[" (any :input) (+ "]" (error)))) ($)) ,|[$1 :array {:from $0 :to $2}])
      :table (/ (* ($) (group (* "@{" (any :input) (+ "}" (error)))) ($)) ,|[$1 :table{:from $0 :to $2}])
      :rmform (/ (* ($) (group (* ':readermac
                                  (group (any :non-form))
                                  :form)) ($))
                 ,|[$1 :rmform {:from $0 :to $2}])
      :form (choice :rmform
                    :parray :barray :ptuple :btuple :table :struct
                    :buffer :string :long-buffer :long-string
                    :span)
      :non-form (choice :newline :ws :comment)
      :input (choice :non-form :form)
      :main (* (any :input) (+ -1 (error)))}))

(defn- make-tree
  "Turn a string of source code into a tree that will be printed"
  [source]
  [:top (peg/match parse-peg source)])

(defn count-lines [sq] (inc (length sq)))

(defn- calculate-coverage [ast]
    (let [second |(get $ 1) 
          ptuples (filter |(= (second $) :ptuple) (second ast)) 
          tagged-ptuples (map (fn [sexpr] [(get-in sexpr [0 0 0]) 
                                           (filter |(= :newline (second $)) 
                                                   (first sexpr))
                                           sexpr]) ptuples)]
      (map |[(first $) (count-lines (second $)) (get $ 2)] tagged-ptuples)))

(defn main [& args]
  (print "Hello, World!"))

(comment

  (def testfile (slurp "./misc/test-joule.janet.test"))
  (def testfile (slurp "./misc/small-test.janet.test"))
  (def testfile (slurp "./project.janet"))

  (defn count-lines [sq] (inc (length sq)))
  (def line (count-lines (string/find-all "\n" testfile)))
  (def ast (make-tree testfile))

  (:top @[(@[("declare-project" :span) ("\n" :newline)
             (" " :whitespace) (" " :whitespace) (":name" :span) (" " :whitespace) ("\"covrj\"" :string) ("\n" :newline)
             (" " :whitespace) (" " :whitespace) (":description" :span) (" " :whitespace) ("\"TODO: Write a cool description\"" :string)] :ptuple) (" " :whitespace) ("\n" :newline)
          (" " :whitespace) (" " :whitespace) (" " :whitespace) ("\n" :newline)
          (@[("declare-executable" :span) ("\n" :newline)
             (" " :whitespace) (" " :whitespace) (":name" :span) (" " :whitespace) ("\"covrj\"" :string) ("\n" :newline) 
             (" " :whitespace) (" " :whitespace) (":entry" :span) (" " :whitespace) ("\"src/covrj.janet\"" :string) ("\n" :newline)
             (" " :whitespace) (" " :whitespace) (" :lflags [\"-static\"]" :comment) 
             (" " :whitespace) (" " :whitespace) (":install" :span) (" " :whitespace) ("false" :span)] :ptuple)])
  
  (:top @[(@[("declare-project" :span {:from 1 :to 16}) ("\n" :newline {:from 16 :to 17}) 
             (" " :whitespace {:from 17 :to 18}) (" " :whitespace {:from 18 :to 19}) (":name" :span {:from 19 :to 24}) (" " :whitespace {:from 24 :to 25}) ("\"covrj\"" :string {:from 25 :to 34}) ("\n" :newline {:from 34 :to 35}) 
             (" " :whitespace {:from 35 :to 36}) (" " :whitespace {:from 36 :to 37}) (":description" :span {:from 37 :to 49}) (" " :whitespace {:from 49 :to 50}) ("\"TODO: Write a cool description\"" :string {:from 50 :to 82})] :ptuple {:from 0 :to 83}) (" " :whitespace {:from 83 :to 84}) ("\n" :newline {:from 84 :to 85}) 
          (" " :whitespace {:from 85 :to 86}) (" " :whitespace {:from 86 :to 87}) (" " :whitespace {:from 87 :to 88}) ("\n" :newline {:from 88 :to 89}) 
          (@[("declare-executable" :span {:from 90 :to 108}) ("\n" :newline {:from 108 :to 109}) 
             (" " :whitespace {:from 109 :to 110}) (" " :whitespace {:from 110 :to 111}) (":name" :span {:from 111 :to 116}) (" " :whitespace {:from 116 :to 117}) ("\"covrj\"" :string {:from 117 :to 126}) ("\n" :newline {:from 126 :to 127}) 
             (" " :whitespace {:from 127 :to 128}) (" " :whitespace {:from 128 :to 129}) (":entry" :span {:from 129 :to 135}) (" " :whitespace {:from 135 :to 136}) ("\"src/covrj.janet\"" :string {:from 136 :to 155}) ("\n" :newline {:from 155 :to 156}) 
             (" " :whitespace {:from 156 :to 157}) (" " :whitespace {:from 157 :to 158}) (" :lflags [\"-static\"]" :comment {:from 158 :to 179}) ("\n" :newline {:from 179 :to 180}) 
             (" " :whitespace {:from 180 :to 181}) (" " :whitespace {:from 181 :to 182}) (":install" :span {:from 182 :to 190}) (" " :whitespace {:from 190 :to 191}) ("false" :span {:from 191 :to 196})] :ptuple {:from 89 :to 197})])

  @[(@[("declare-project" :span {:from 1 :to 16}) ("\n" :newline {:from 16 :to 17}) 
       (" " :whitespace {:from 17 :to 18}) (" " :whitespace {:from 18 :to 19}) (":name" :span {:from 19 :to 24}) (" " :whitespace {:from 24 :to 25}) ("\"covrj\"" :string {:from 25 :to 32}) ("\n" :newline {:from 32 :to 33}) 
       (" " :whitespace {:from 33 :to 34}) (" " :whitespace {:from 34 :to 35}) (":description" :span {:from 35 :to 47}) (" " :whitespace {:from 47 :to 48}) ("\"TODO: Write a cool description\"" :string {:from 48 :to 80})] :ptuple {:from 0 :to 81}) 
    (@[("declare-executable" :span {:from 88 :to 106}) ("\n" :newline {:from 106 :to 107}) 
       (" " :whitespace {:from 107 :to 108}) (" " :whitespace {:from 108 :to 109}) (":name" :span {:from 109 :to 114}) (" " :whitespace {:from 114 :to 115}) ("\"covrj\"" :string {:from 115 :to 122}) ("\n" :newline {:from 122 :to 123}) 
       (" " :whitespace {:from 123 :to 124}) (" " :whitespace {:from 124 :to 125}) (":entry" :span {:from 125 :to 131}) (" " :whitespace {:from 131 :to 132}) ("\"src/covrj.janet\"" :string {:from 132 :to 149}) ("\n" :newline {:from 149 :to 150}) 
       (" " :whitespace {:from 150 :to 151}) (" " :whitespace {:from 151 :to 152}) (" :lflags [\"-static\"]" :comment {:from 152 :to 173}) ("\n" :newline {:from 173 :to 174}) 
       (" " :whitespace {:from 174 :to 175}) (" " :whitespace {:from 175 :to 176}) (":install" :span {:from 176 :to 184}) (" " :whitespace {:from 184 :to 185}) ("false" :span {:from 185 :to 190})] :ptuple {:from 87 :to 191})]

  @[("declare-project" (@[("declare-project" :span {:from 1 :to 16}) ("\n" :newline {:from 16 :to 17}) (" " :whitespace {:from 17 :to 18}) (" " :whitespace {:from 18 :to 19}) (":name" :span {:from 19 :to 24}) (" " :whitespace {:from 24 :to 25}) ("\"covrj\"" :string {:from 25 :to 32}) ("\n" :newline {:from 32 :to 33}) (" " :whitespace {:from 33 :to 34}) (" " :whitespace {:from 34 :to 35}) (":description" :span {:from 35 :to 47}) (" " :whitespace {:from 47 :to 48}) ("\"TODO: Write a cool description\"" :string {:from 48 :to 80})] :ptuple {:from 0 :to 81})) 
    ("declare-executable" (@[("declare-executable" :span {:from 88 :to 106}) ("\n" :newline {:from 106 :to 107}) (" " :whitespace {:from 107 :to 108}) (" " :whitespace {:from 108 :to 109}) (":name" :span {:from 109 :to 114}) (" " :whitespace {:from 114 :to 115}) ("\"covrj\"" :string {:from 115 :to 122}) ("\n" :newline {:from 122 :to 123}) (" " :whitespace {:from 123 :to 124}) (" " :whitespace {:from 124 :to 125}) (":entry" :span {:from 125 :to 131}) (" " :whitespace {:from 131 :to 132}) ("\"src/covrj.janet\"" :string {:from 132 :to 149}) ("\n" :newline {:from 149 :to 150}) (" " :whitespace {:from 150 :to 151}) (" " :whitespace {:from 151 :to 152}) (" :lflags [\"-static\"]" :comment {:from 152 :to 173}) ("\n" :newline {:from 173 :to 174}) (" " :whitespace {:from 174 :to 175}) (" " :whitespace {:from 175 :to 176}) (":install" :span {:from 176 :to 184}) (" " :whitespace {:from 184 :to 185}) ("false" :span {:from 185 :to 190})] :ptuple {:from 87 :to 191}))]

  @[(@[("defn" :span {:from 1 :to 5}) (" " :whitespace {:from 5 :to 6}) ("test-fn" :span {:from 6 :to 13}) (" " :whitespace {:from 13 :to 14}) (@[("bool" :span {:from 15 :to 19})] :btuple {:from 14 :to 20}) ("\n" :newline {:from 20 :to 21}) (" " :whitespace {:from 21 :to 22}) (" " :whitespace {:from 22 :to 23}) (@[("if" :span {:from 24 :to 26}) (" " :whitespace {:from 26 :to 27}) ("bool" :span {:from 27 :to 31}) ("\n" :newline {:from 31 :to 32}) (" " :whitespace {:from 32 :to 33}) (" " :whitespace {:from 33 :to 34}) (" " :whitespace {:from 34 :to 35}) (" " :whitespace {:from 35 :to 36}) (@[("print" :span {:from 37 :to 42}) (" " :whitespace {:from 42 :to 43}) ("\"True!\"" :string {:from 43 :to 50})] :ptuple {:from 36 :to 51}) ("\n" :newline {:from 51 :to 52}) (" " :whitespace {:from 52 :to 53}) (" " :whitespace {:from 53 :to 54}) (" " :whitespace {:from 54 :to 55}) (" " :whitespace {:from 55 :to 56}) (@[("print" :span {:from 57 :to 62}) (" " :whitespace {:from 62 :to 63}) ("\"False!\"" :string {:from 63 :to 71})] :ptuple {:from 56 :to 72})] :ptuple {:from 23 :to 73})] :ptuple {:from 0 :to 74}) ("\n" :newline {:from 74 :to 75}) ("\n" :newline {:from 75 :to 76}) (@[("defn" :span {:from 77 :to 81}) (" " :whitespace {:from 81 :to 82}) ("main" :span {:from 82 :to 86}) (" " :whitespace {:from 86 :to 87}) (@[("&" :span {:from 88 :to 89}) (" " :whitespace {:from 89 :to 90}) ("args" :span {:from 90 :to 94})] :btuple {:from 87 :to 95}) ("\n" :newline {:from 95 :to 96}) (" " :whitespace {:from 96 :to 97}) (" " :whitespace {:from 97 :to 98}) (@[("test-fn" :span {:from 99 :to 106}) (" " :whitespace {:from 106 :to 107}) ("true" :span {:from 107 :to 111})] :ptuple {:from 98 :to 112})] :ptuple {:from 76 :to 113})]
  
  (calculate-coverage ast)

  (def ptuples (filter |(= (second $) :ptuple) (second ast)))
  (def functions (filter |(= "defn" (get-in $ [0 0 0])) ptuples))
  (def function-names (map |(get-in $ [0 2 0]) functions))
  ()

  (var fn-graph (jgraph/defgraph))

  # (get-in $ [2 0 4 0])
  (let [coverage (calculate-coverage ast)
         (map |[(get $ 0) (get $ 1)] coverage)])

  (case a
    "use" :notest
    "import" :notest
    "def" :notest
    "var" :notest
    "defn" :needs-test
    (symbols))
  
  (do (var currently-in "")
      (prewalk
       (fn [n] 
         (when (= :ptuple (get n 1))
           (when (= "defn" (get-in n [0 0 0])) 
             (let [fn-name (get-in n [0 2 0])]
               (prewalk 
                (fn [m]
                  (when (= :ptuple (get m 1))
                    (unless (= :array (type (get-in m [0 0 0]))) 
                      (pp [fn-name (get-in m [0 0 0])])))
                  m)
                (first n)))))
         n)
       (get ast 1))!!
      nil)

  (def test-ast [[[[0 1 3]] 16 7 [3 [3 5]] 3 4] 1 [3 4]])
  
  (defn walker
  `Simple walker function, that prints non-sequential 
   members of the form or prints "Sequence" and walks 
   recursively sequential members of the tree.` 
  [form] 
  (if (or (indexed? form) (dictionary? form))
    (do (print "Sequence")
        (walk walker form))
    (print form)))

  (walk walker test-ast)

  (defn mapper 
    [form] 
  (if (or (indexed? form) (dictionary? form))
    (do (print "Sequence")
        (map mapper form))
    (print form)))
  
  (map mapper test-ast)
  )