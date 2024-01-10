(use judge)

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