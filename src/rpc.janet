# (import spork/json)
(import ../libs/jayson)
(import ./logging)

(defn success-response [id result &keys opts]
  (def rpc 
    (if (opts :notify)
      (merge {:jsonrpc "2.0"}
             result)
      {:jsonrpc "2.0"
       :id id
       :result result}))
  (logging/info (string/format "sending: %m" rpc) [:rpc] 2)
  (jayson/encode rpc))
