(import spork/json :as json)

(defn success-response [id result]
	(json/encode {
		:jsonrpc "2.0"
		:id id
		:result result
	}))


