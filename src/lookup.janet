
(defn lookup [{:line line :character character} source]
	(string/from-bytes (((string/split "\n" source) line) character)))


(defn word-at [location source]
	(def {:character character-pos :line line-pos} location)
	
	(var line ((string/split "\n" source) line-pos))

	(var backward @[])
	(var forward @[])

	(var offset-backward 0)
	(var offset-forward 0)
	
	(var done false)
	(for i character-pos (length line)
		(var char (string/from-bytes (line i)))

		(if (and (not done) (not= char " ") (not= char "(") (not= char ")"))
			(array/push forward char)
			(do 
				(set done true)
				(set offset-forward (length forward)))
		)
	)

	(var done false)
	(for i (+ (- character-pos) 1) 1
		(var char (string/from-bytes (line (- i))))

		(if (and (not done) (not= char " ") (not= char "(") (not= char ")"))
			(array/insert backward 0 char)
			(do 
				(set done true)
				(set offset-backward (length backward)))
		)
	)

	(var offset-backward (- character-pos offset-backward))
	(var offset-forward (+ offset-forward character-pos))

	{
		:word (string/join (array/concat backward forward))
		:range [offset-backward offset-forward]
	}
)


#(pp (lookup {:line 0 :character 0} "1\n23\n45"))

# (pp (word-at {:line 0 :character 12} "word not a word\n23\n45"))

# (pp (word-at {:line 1 :character 6} "\nword not a word\n23\n45"))

# (pp (word-at {:line 0 :character 0} "word"))

# (pp (word-at {:line 0 :character 4} " word "))

# (pp (word-at {:line 0 :character 0} "  "))