# (import spork/json)
(import ../libs/jayson)

(defn success-response [id result]
  (jayson/encode {:jsonrpc "2.0"
                  :id id
                  :result result}))
