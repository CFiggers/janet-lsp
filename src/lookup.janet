(use judge)
(import ./logging)

(defn lookup [{:line line :character character} source]
  (string/from-bytes (((string/split "\n" source) line) character)))

(def word-peg
  (peg/compile
    ~{:s     (set " \t\0\f\v") :s* (any :s) :s+ (some :s)
      :paren (/ (* (column) (set "()") (constant "") (column)) ,|[(dec $0) $1 (- $2 2)])
      :ws    (/ (* (column) :s+ (constant "") (column)) ,|$&)
      :word  (/ (* (column) (<- (some (if-not (set " ()") 1))) (? (+ :s ")")) (column)) ,|[(dec $0) $1 (- $2 2)])
      :main  (some (+ :paren :ws :word -1))}))

(defmacro first-where [pred ds]
  (with-syms [$pred $ds]
    ~(let [,$pred ,pred ,$ds ,ds]
       (var ret nil)
       (for i 0 (length ,$ds)
         (when (,$pred (,$ds i))
           (set ret (,$ds i))
           (break)))
       ret)))

(defn word-at :tested [location source]
  (let [{:character character-pos :line line-pos} location
        line ((string/split "\n" source) line-pos)
        parsed (or (sort-by last (or (peg/match word-peg line) @[[0 "" 0]])))
        word (or (first-where |(>= ($ 2) character-pos) parsed) (last parsed))]
    {:range [(word 0) (word 2)] :word (word 1)}))

(def sexp-peg
  (peg/compile
    ~{:s-exp (group (* (position) (* "(" (any (+ (drop :s-exp) (to (set "()")))) ")") (position)))
      :main (some (+ (if :s-exp 1) 1))}))

(defn sexp-at [location source]
  (let [{:character character-pos :line line-pos} location
        idx (+ character-pos (sum (map (comp inc length) (array/slice (string/split "\n" source) 0 line-pos))))
        s-exps (or (peg/match sexp-peg source) @[])] 
    (if-let [sexp-range (last (filter |(< ($ 0) idx ($ 1)) s-exps))]
      {:source (string/slice source ;sexp-range) :range sexp-range}
      {:source "" :range @[line-pos character-pos]})))

(defn to-index [location source]
  (let [{:character character-pos :line line-pos} location
        lines (string/split "\n" source)
        pre-lines (array/slice lines 0 line-pos)
        pre-lengths (map (comp inc length) pre-lines)
        pre-length (sum pre-lengths)]
    (comment prin "pre-lines: ") (comment pp pre-lines)
    (comment prin "pre-lengths: ") (comment pp pre-lengths)
    (comment prin "pre-length: ") (comment pp pre-length)
    (comment prin "character-pos: ") (comment pp character-pos)
    (+ character-pos pre-length)))
