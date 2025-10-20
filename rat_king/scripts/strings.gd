class_name Strings

###

# the same as text.lstrip(chars).rstrip(chars) I guess
static func strip(text: String, chars := " \t\n\r") -> String:
	var s_idx := 0
	var l_idx := text.length()
	for t: String in text:
		if not chars.contains(t): break
		s_idx += 1
	for i: int in range(l_idx - 1, -1, -1):
		if not chars.contains(text[i]): break
		l_idx -= 1
	return text.substr(s_idx, l_idx - s_idx)

static func get_lines(text: String, omit_empty := false, strip_edges := true) -> Array[String]:
	if not text: return []
	var res: Array[String] = []
	for line: String in text.split("\n", false): 
		for l: String in line.split("\r", false):
			l = l.strip_edges()
			if omit_empty and not l: continue
			res.append(l if strip_edges else l)
	return res

static func get_words(text: String) -> Array[String]:
	if not text: return []
	var regex := RegEx.new()
	regex.compile("\"[^\"]+\"|[\\S]+") # Negated whitespace character class.
	var res: Array[String] = []
	for rm : RegExMatch in regex.search_all(text): res.push_back(rm.get_string())
	return res

static func join(texts: Array, joiner: String, start_idx := 0) -> String:
	if not texts: return ""
	var res := ""
	for i: int in range(start_idx, texts.size()):
		if i != start_idx: res += joiner
		res += str(texts[i])
	return res

static func random_id(count := 8, items := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcedfghijklmnopqrstuvwxyz") -> String:
	var res := ""
	for i in count:
		res += items[randi_range(0, items.length() - 1)]
	return res

static func tagify(text: String, marker := "**", start_tag := "[color=green]", end_tag := "[/color]") -> String:
	if not text.contains(marker): return text
	var t := text
	var ml := marker.length()
	while t.contains(marker):
		var a := text.find(marker)
		var b := text.find(marker, a + ml)
		if b == -1: break
		t = text.substr(b + ml)
		text = text.substr(0, a) + start_tag + text.substr(a + ml, b - a - ml) + end_tag + text.substr(b + ml)
	return text
