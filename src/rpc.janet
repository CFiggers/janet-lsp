# (import spork/json)
(import ../libs/jayson)

(defn success-response [id result &keys opts]
  (def rpc 
    (if (opts :notify)
      (merge {:jsonrpc "2.0"}
             result)
      {:jsonrpc "2.0"
       :id id
       :result result}))
  (jayson/encode rpc))
