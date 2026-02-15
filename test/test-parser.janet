(use judge)

(use ../src/parser)

(test (get-syms-at-loc
        {:line 0 :character 1}
        "()")
      @[])

(test (get-syms-at-loc
        {:line 0 :character 2}
        "()")
      @[])

(test (get-syms-at-loc
        {:line 0 :character 3}
        "(def x 0) ")
      @[])

(test (get-syms-at-loc
        {:line 0 :character 10}
        "(def x 0) ")
      @[{:kind 12 :label x}])

(test (get-syms-at-loc
        {:line 0 :character 10}
        "(var x 0) ")
      @[{:kind 12 :label x}])

(test (get-syms-at-loc
        {:line 0 :character 11}
        "( def x 0) ")
      @[{:kind 12 :label x}])

(test (get-syms-at-loc
        {:line 0 :character 10}
        "(def 0 0) ")
      @[])

(test (get-syms-at-loc
        {:line 0 :character 12}
        "(def 3.4 0) ")
      @[])

(test (get-syms-at-loc
        {:line 0 :character 13}
        "(def +3.4 0) ")
      @[])

(test (get-syms-at-loc
        {:line 0 :character 13}
        "(def -3.4 0) ")
      @[])

(test (get-syms-at-loc
        {:line 0 :character 13}
        "(def _3 0) ")
      @[{:kind 12 :label _3}])

(test (get-syms-at-loc
        {:line 0 :character 13}
        "(def &7 0) ")
      @[{:kind 12 :label &7}])

(test (get-syms-at-loc
        {:line 0 :character 13}
        "(def 443.324e7 0) ")
      @[])

(test (get-syms-at-loc
        {:line 0 :character 13}
        "(def 443.e7 0) ")
      @[])

(test (get-syms-at-loc
        {:line 0 :character 13}
        "(def .43E7 0) ")
      @[])

(test (get-syms-at-loc
        {:line 0 :character 13}
        "(def 3_3.4_33e7 0) ")
      @[])

(test (get-syms-at-loc
        {:line 0 :character 13}
        "(def 3__3.4__33e-7 0) ")
      @[])

(test (get-syms-at-loc
        {:line 0 :character 30}
        "(def -1_234_567.89_01e-2_3 0)  ")
      @[])

(test (get-syms-at-loc
        {:line 0 :character 54}
        "(def my-var+extra*weird!_name$/foo:bar?baz@q^t&wow 0)  ")
      @[{:kind 12
         :label my-var+extra*weird!_name$/foo:bar?baz@q^t&wow}])

(test (get-syms-at-loc
        {:line 0 :character 15}
        "(def x (+ 1 1)) ")
      @[{:kind 12 :label x}])

(test (get-syms-at-loc
        {:line 0 :character 10}
        "(def x (+ 1 1))")
      @[])

(test (get-syms-at-loc
        {:line 0 :character 21}
        "(def (fi se) (:a :b)) ")
      @[{:kind 12 :label fi}
        {:kind 12 :label se}])

(test (get-syms-at-loc
        {:line 0 :character 23}
        "(def ( fi se ) (:a :b)) ")
      @[{:kind 12 :label fi}
        {:kind 12 :label se}])

(test (get-syms-at-loc
        {:line 0 :character 21}
        "(def [fi se] [:a :b]) ")
      @[{:kind 12 :label fi}
        {:kind 12 :label se}])

(test (get-syms-at-loc
        {:line 0 :character 24}
        "(def [ fi se ] @[:a :b]) ")
      @[{:kind 12 :label fi}
        {:kind 12 :label se}])

(test (get-syms-at-loc
        {:line 0 :character 52}
        "(def {:k1 td1 :k2 tdb} {:k1 (+ 3 4) :k2 7}) ")
      @[{:kind 12 :label td1}
        {:kind 12 :label tdb}])

(test (get-syms-at-loc
        {:line 0 :character 53}
        "(def {:k1 td1 :k2 tdb} @{:k1 (+ 3 4) :k2 7}) ")
      @[{:kind 12 :label td1}
        {:kind 12 :label tdb}])

(test (get-syms-at-loc
        {:line 0 :character 54}
        "(def { :k1 td1 :k2 tdb } {:k1 (+ 3 4) :k2 7}) ")
      @[{:kind 12 :label td1}
        {:kind 12 :label tdb}])

(test (get-syms-at-loc
        {:line 0 :character 26}
        "(def {:k1 td1 :k2 tdb :k3  } {:k1 (+ 3 4) :k2 7}) ")
      @[])

(test (get-syms-at-loc
        {:line 0 :character 3}
        "(let [x 0] )")
      @[])

(test (get-syms-at-loc
        {:line 0 :character 8}
        "(let [x 0] )")
      @[{:kind 12 :label x}])

(test (get-syms-at-loc
        {:line 0 :character 22}
        "(let [x y f g] (print x ))")
      @[{:kind 12 :label x}
        {:kind 12 :label f}])


(test (get-syms-at-loc
        {:line 0 :character 12}
        "( let [ x 0 ] )")
      @[{:kind 12 :label x}])

(test (get-syms-at-loc
        {:line 0 :character 12}
        "(let [x 0 y  ] )")
      @[{:kind 12 :label x}
        {:kind 12 :label y}])

(test (get-syms-at-loc
        {:line 1 :character 3}
        "(let [x 0 \n y  ] )")
      @[{:kind 12 :label x}
        {:kind 12 :label y}])

(test (get-syms-at-loc
        {:line 0 :character 18}
        "(let [(x1 x2) v y  ] )")
      @[{:kind 12 :label x1}
        {:kind 12 :label x2}
        {:kind 12 :label y}])

(test (get-syms-at-loc
        {:line 0 :character 17}
        "(let [(x1 _) v y]   )")
      @[{:kind 12 :label x1}
        {:kind 12 :label y}])

(test (get-syms-at-loc
        {:line 0 :character 17}
        "(let [(_ x2) v y]   )")
      @[{:kind 12 :label x2}
        {:kind 12 :label y}])

(test (get-syms-at-loc
        {:line 0 :character 17}
        "(let [[_ x2] v y]   )")
      @[{:kind 12 :label x2}
        {:kind 12 :label y}])

(test (get-syms-at-loc
        {:line 0 :character 18}
        "(let [(_v x2) v y]   )")
      @[{:kind 12 :label _v}
        {:kind 12 :label x2}
        {:kind 12 :label y}])

(test (get-syms-at-loc
        {:line 0 :character 18}
        "(let [(&v x2) v y]   )")
      @[{:kind 12 :label &v}
        {:kind 12 :label x2}
        {:kind 12 :label y}])

(test (get-syms-at-loc
        {:line 0 :character 35}
        "(let [(x1 x2) v {:aaa y1 :bbb y2}   ] )")
      @[{:kind 12 :label x1}
        {:kind 12 :label x2}
        {:kind 12 :label y1}
        {:kind 12 :label y2}])

(test (get-syms-at-loc
        {:line 0 :character 36}
        "(let [(x1 x2) v {:aaa y1 :bbb y2}]  )")
      @[{:kind 12 :label x1}
        {:kind 12 :label x2}
        {:kind 12 :label y1}
        {:kind 12 :label y2}])

(test (get-syms-at-loc
        {:line 0 :character 36}
        "(let [(x1 x2) v {:aaa y1 :bbb y2}])  ")
      @[])

(test (get-syms-at-loc
        {:line 0 :character 8}
        "(let [x] x)")
      @[{:kind 12 :label x}])


(test (get-syms-at-loc
        {:line 0 :character 24}
        "(let [x 1] (let [y 2] y  ))")
      @[{:kind 12 :label y}
        {:kind 12 :label x}])

(test (get-syms-at-loc
        {:line 0 :character 30}
        "(let [f (fn [a] a) x 5] (f x) )")
      @[{:kind 12 :label f}
        {:kind 12 :label x}])

(test (get-syms-at-loc
        {:line 0 :character 12}
        "(let [ x  1   y   2 ] x)")
      @[{:kind 12 :label x}
        {:kind 12 :label y}])

(test (get-syms-at-loc
        {:line 0 :character 10}
        "(let [x 1 y 2] x)")
      @[{:kind 12 :label x}])

(test (get-syms-at-loc
        {:line 0 :character 20}
        "(defn some-func [x]  )")
      @[{:kind 12 :label x}
        {:kind 3 :label some-func}])

(test (get-syms-at-loc
        {:line 0 :character 21}
        "(defn- some-func [x]  )")
      @[{:kind 12 :label x}
        {:kind 3 :label some-func}])

(test (get-syms-at-loc
        {:line 0 :character 25}
        "(defmacro some-macro [x]  )")
      @[{:kind 12 :label x}
        {:kind 3 :label some-macro}])

(test (get-syms-at-loc
        {:line 0 :character 26}
        "(defmacro- some-macro [x]  )")
      @[{:kind 12 :label x}
        {:kind 3 :label some-macro}])

(test (get-syms-at-loc
        {:line 0 :character 22}
        "(defn some-func [x]  (   ))")
      @[{:kind 12 :label x}
        {:kind 3 :label some-func}])

(test (get-syms-at-loc
        {:line 0 :character 21}
        "( defn some-func [x]  )")
      @[{:kind 12 :label x}
        {:kind 3 :label some-func}])

(test (get-syms-at-loc
        {:line 0 :character 22}
        "(defn some-func [ x ]  )")
      @[{:kind 12 :label x}
        {:kind 3 :label some-func}])

(test (get-syms-at-loc
        {:line 0 :character 25}
        "(defn some-func [x] nil)  ")
      @[{:kind 3 :label some-func}])

(test (get-syms-at-loc
        {:line 0 :character 34}
        "(defn some-func \"doc string\" [x]  )")
      @[{:kind 12 :label x}
        {:kind 3 :label some-func}])

(test (get-syms-at-loc
        {:line 0 :character 40}
        "(defn some-func \"doc string\" [x] nil)  ")
      @[{:kind 3 :label some-func}])

(test (get-syms-at-loc
        {:line 1 :character 16}
        "(defn some-func \"multiline doc \n string\" [x]    )")
      @[{:kind 12 :label x}
        {:kind 3 :label some-func}])

(test (get-syms-at-loc
        {:line 1 :character 20}
        "(defn some-func \"multiline doc \n string\" [x] nil)  ")
      @[{:kind 3 :label some-func}])

(test (get-syms-at-loc
        {:line 0 :character 21}
        "(defn some-func [x _]  )")
      @[{:kind 12 :label x}
        {:kind 3 :label some-func}])

(test (get-syms-at-loc
        {:line 0 :character 26}
        "(defn some-func [x & more]  )")
      @[{:kind 12 :label x}
        {:kind 12 :label more}
        {:kind 3 :label some-func}])

(test (get-syms-at-loc
        {:line 0 :character 24}
        "(defn some-func [(a b)]  )")
      @[{:kind 12 :label a}
        {:kind 12 :label b}
        {:kind 3 :label some-func}])

(test (get-syms-at-loc
        {:line 0 :character 34}
        "(defn some-func [{:val a :tag b}]  )")
      @[{:kind 12 :label a}
        {:kind 12 :label b}
        {:kind 3 :label some-func}])

(test (get-syms-at-loc
        {:line 0 :character 10}
        "(fn [par]  )")
      @[{:kind 12 :label par}])

(test (get-syms-at-loc
        {:line 0 :character 12}
        "(fn [ par ]  )")
      @[{:kind 12 :label par}])

(test (get-syms-at-loc
        {:line 0 :character 11}
        "( fn [par]  )")
      @[{:kind 12 :label par}])

(test (get-syms-at-loc
        {:line 0 :character 15}
        "(fn [par1 par2]  )")
      @[{:kind 12 :label par1}
        {:kind 12 :label par2}])

(test (get-syms-at-loc
        {:line 0 :character 13}
        "(fn [p] nil)  ")
      @[])

(test (get-syms-at-loc
        {:line 0 :character 18}
        "(fn [(head tail)]  )")
      @[{:kind 12 :label head}
        {:kind 12 :label tail}])

(test (get-syms-at-loc
        {:line 0 :character 18}
        "(fn [[head tail]]  )")
      @[{:kind 12 :label head}
        {:kind 12 :label tail}])

(test (get-syms-at-loc
        {:line 0 :character 30}
        "(fn [{:head head :tail tail}]  )")
      @[{:kind 12 :label head}
        {:kind 12 :label tail}])

(test (get-syms-at-loc
        {:line 0 :character 25}
        "(for iter 0 10 (+= total   ))")
      @[{:kind 12 :label iter}])

(test (get-syms-at-loc
        {:line 0 :character 18}
        "( for iter 0 10 (   ))")
      @[{:kind 12 :label iter}])

(test (get-syms-at-loc
        {:line 0 :character 18}
        "(each name names   )")
      @[{:kind 12 :label name}])

(test (get-syms-at-loc
        {:line 0 :character 40}
        "(loop [ index :range [0 10] ] (+= total   ))")
      @[{:kind 12 :label index}])

(test (get-syms-at-loc
        {:line 0 :character 40}
        "( loop [index :range [0 10] ] (+= total   ))")
      @[{:kind 12 :label index}])


(deftest "completions in source"
  (def source
    "(defn top-def [input]\n
(let [{:key1 k1 :key2 k2} input]\n
  (let [fixed-par 3]\n
    (    )\n
    # Comments \n
    (def some-bytes \"bytes\")\n
    (defn frob [x] (+   7))\n
    (        ))))")

  (test (get-syms-at-loc {:line 1 :character 0} source)
        @[{:kind 12 :label k1}
          {:kind 12 :label k2}
          {:kind 12 :label input}
          {:kind 3 :label top-def}])
  (test (get-syms-at-loc {:line 2 :character 0} source)
        @[{:kind 12 :label k1}
          {:kind 12 :label k2}
          {:kind 12 :label input}
          {:kind 3 :label top-def}])
  (test (get-syms-at-loc {:line 3 :character 8} source)
        @[{:kind 12 :label fixed-par}
          {:kind 12 :label k1}
          {:kind 12 :label k2}
          {:kind 12 :label input}
          {:kind 3 :label top-def}])
  (test (get-syms-at-loc {:line 4 :character 0} source)
        @[{:kind 12 :label fixed-par}
          {:kind 12 :label k1}
          {:kind 12 :label k2}
          {:kind 12 :label input}
          {:kind 3 :label top-def}])
  (test (get-syms-at-loc {:line 5 :character 0} source)
        @[{:kind 12 :label fixed-par}
          {:kind 12 :label k1}
          {:kind 12 :label k2}
          {:kind 12 :label input}
          {:kind 3 :label top-def}])
  (test (get-syms-at-loc {:line 6 :character 0} source)
        @[{:kind 12 :label fixed-par}
          {:kind 12 :label some-bytes}
          {:kind 12 :label k1}
          {:kind 12 :label k2}
          {:kind 12 :label input}
          {:kind 3 :label top-def}])
  (test (get-syms-at-loc {:line 6 :character 22} source)
        @[{:kind 12 :label x}
          {:kind 3 :label frob}
          {:kind 12 :label fixed-par}
          {:kind 12 :label some-bytes}
          {:kind 12 :label k1}
          {:kind 12 :label k2}
          {:kind 12 :label input}
          {:kind 3 :label top-def}])
  (test (get-syms-at-loc {:line 7 :character 8} source)
        @[{:kind 12 :label fixed-par}
          {:kind 12 :label some-bytes}
          {:kind 3 :label frob}
          {:kind 12 :label k1}
          {:kind 12 :label k2}
          {:kind 12 :label input}
          {:kind 3 :label top-def}]))
