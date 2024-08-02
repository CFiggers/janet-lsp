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
  (logging/log (string/format "sending: %m" rpc))
  (jayson/encode rpc))
