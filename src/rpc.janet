(import spork/json :as json)

(defn success-response [id result]
  (if (nil? result)
    (string "{\"id\":" id ",\"result\":null,\"jsonrpc\":\"2.0\"}")
    (json/encode {:jsonrpc "2.0"
                  :id id
                  :result result})))


