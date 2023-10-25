(use judge)

(defmacro- letv [bindings & body]
  ~(do ,;(seq [[k v] :in (partition 2 bindings)] ['var k v]) ,;body))

(defn- read-hex [n] 
    (scan-number (string "0x" n)))

(defn- check-utf-16 [capture]
  (let [u (read-hex capture)]
    (if (and (>= u 0xD800)
             (<= u 0xDBFF))
      capture 
      false)))

(def- utf-8->bytes 
  (peg/compile
   ~{:double-u-esc (/ (* "\\u" (cmt (<- 4) ,|(check-utf-16 $)) "\\u" (<- 4))
                      ,|(+ (blshift (- (read-hex $0) 0xD800) 10)
                           (- (read-hex $1) 0xDC00) 0x10000))
     :single-u-esc (/ (* "\\u" (<- 4)) ,|(read-hex $))
     :unicode-esc  (/ (+ :double-u-esc :single-u-esc)
                      ,|(string/from-bytes
                         ;(cond
                           (<= $ 0x7f) [$]
                           (<= $ 0x7ff)
                           [(bor (band (brshift $  6) 0x1F) 0xC0)
                            (bor (band (brshift $  0) 0x3F) 0x80)]
                           (<= $ 0xffff)
                           [(bor (band (brshift $ 12) 0x0F) 0xE0)
                            (bor (band (brshift $  6) 0x3F) 0x80)
                            (bor (band (brshift $  0) 0x3F) 0x80)]
                             # Otherwise
                           [(bor (band (brshift $ 18) 0x07) 0xF0)
                            (bor (band (brshift $ 12) 0x3F) 0x80)
                            (bor (band (brshift $  6) 0x3F) 0x80)
                            (bor (band (brshift $  0) 0x3F) 0x80)])))
     :escape       (/ (* "\\" (<- (set "avbnfrt\"\\/")))
                      ,|(get {"a" "\a" "v" "\v" "b" "\b"
                              "n" "\n" "f" "\f" "r" "\r"
                              "t" "\t"} $ $))
     :main         (+ (some (+ :unicode-esc :escape (<- 1))) -1)}))

(comment
  
  "👎"
  (json/encode "👎")
  (json/decode (json/encode "👎"))
  
  (encode "👎")
  (decode (encode "👎"))
  )

(defn decode 
  ``
  Returns a janet object after parsing JSON. If keywords is truthy,
  string keys will be converted to keywords. If nils is truthy, null
  will become nil instead of the keyword :json/null.
  ``
  [json-source &opt keywords nils] 

  (def json-parser 
    {:null (if nils
             ~(/ (<- (+ "null" "Null")) nil)
             ~(/ (<- (+ "null" "Null")) :json/null))
     :bool-t ~(/ (<- (+ "true")) true)
     :bool-f ~(/ (<- (+ "false")) false)
     :number ~(/ (<- (* (? "-") :d+ (? (* "." :d+)))) ,|(scan-number $))
     :string ~(/ (* "\"" (<- (to (* (> -1 (not "\\")) "\"")))
                    (* (> -1 (not "\\")) "\""))
                 ,|(string/join (peg/match utf-8->bytes $))) 
     :array ~(/ (* "[" :s* (? (* :value (any (* :s* "," :value)))) "]") ,|(array ;$&))
     :key-value (if keywords
                  ~(* :s* (/ :string ,|(keyword $)) :s* ":" :value)
                  ~(* :s* :string :s* ":" :value))
     :object ~(/ (* "{" :s* (? (* :key-value (any (* :s* "," :key-value)))) "}")
                 ,|(from-pairs (partition 2 $&)))
     :value ~(* :s* (+ :null :bool-t :bool-f :number :string :array :object) :s*)
     :unmatched ~(/ (<- (to (+ :value -1))) ,|[:unmatched $])
     :main ~(some (+ :value "\n" :unmatched))})
  
  (first (peg/match (peg/compile json-parser) json-source)))

(def- bytes->utf-8
  (peg/compile
   ~{:four-byte  (/ (* (<- (range "\xf0\xff")) (<- 1) (<- 1) (<- 1))
                    ,|(bor (blshift (band (first $0) 0x07) 18)
                           (blshift (band (first $1) 0x3F) 12)
                           (blshift (band (first $2) 0x3F) 6)
                           (blshift (band (first $3) 0x3F) 0)))
     :three-byte (/ (* (<- (range "\xe0\xef")) (<- 1) (<- 1))
                    ,|(bor (blshift (band (first $0) 0x0F) 12)
                           (blshift (band (first $1) 0x3F) 6)
                           (blshift (band (first $2) 0x3F) 0)))
     :two-byte   (/ (* (<- (range "\x80\xdf")) (<- 1))
                    ,|(bor (blshift (band (first $0) 0x1F) 6)
                           (blshift (band (first $1) 0x3F) 0)))
     :multi-byte (/ (+ :two-byte :three-byte :four-byte)
                    ,|(if (< $ 0x10000) 
                        (string/format "\\u%04X" $)
                        (string/format "\\u%04X\\u%04X" 
                                       (+ (brshift (- $ 0x10000) 10) 0xD800) 
                                       (+ (band (- $ 0x10000) 0x3FF) 0xDC00))))
     :one-byte   (<- (range "\x20\x7f"))
     :0to31      (/ (<- (range "\0\x1F"))
                    ,|(or ({"\a" "\\u0007" "\b" "\\u0008"
                            "\t" "\\u0009" "\n" "\\u000A"
                            "\v" "\\u000B" "\f" "\\u000C"
                            "\r" "\\u000D"} $)
                          (string/format "\\u%04X" (first $))))
     :backslash  (/ (<- "\\") "\\\\")
     :quote      (/ (<- "\"") "\\\"")
     :main       (some (+ :0to31 :backslash :quote :one-byte :multi-byte))}))

(defn- encodeone [encoder x depth]
  (if (> depth 1024) (error "recurred too deeply"))
  (cond
    (= x :json/null) "null"
    (bytes? x) (string "\"" (string/join (peg/match bytes->utf-8 x)) "\"")
    (indexed? x) (string "[" (string/join (map |(encodeone encoder $ (inc depth)) x) ",") "]")
    (dictionary? x) (string "{" (string/join
                                 (seq [[k v] :in (pairs x)]
                                   (string (encodeone encoder k (inc depth)) ":" (encodeone encoder v (inc depth)))) ",") "}")
    (case (type x)
      :nil "null"
      :boolean (string x)
      :number (string x)
      (error "type not supported"))))

(defn encode 
  `` 
  Encodes a janet value in JSON (utf-8). `tab` and `newline` are optional byte sequence which are used 
  to format the output JSON. If `buf` is provided, the formated JSON is append to `buf` instead of a new buffer.
  Returns the modifed buffer.
  ``
  [x &opt tab newline buf]
  
  (letv [encoder {:indent 0
                  :buffer @""
                  :tab tab
                  :newline newline}
         ret (encodeone encoder x 0)]
        (if (and buf (buffer? buf))
          (buffer/push ret)
          (thaw ret))))
