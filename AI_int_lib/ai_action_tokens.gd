## Normalizes model completion text to a single legal action token for the AI driver.
## Unknown or empty input maps to "noop" (caller must ignore without changing virtual intent).
extends Object


const _LEGAL := {
  "UP": true,
  "DOWN": true,
  "LEFT": true,
  "RIGHT": true,
  "START": true,
}

static var _start_word_re: RegEx

## First whole-word UP/DOWN/LEFT/RIGHT in play-phase replies (models often wrap directions in prose).
static var _dir_word_re: RegEx

## Chat-style templates often append markers like `<|im_end|>` in the assistant string; removing them avoids
## spurious noop when START appears before the marker.
static var _chat_span_re: RegEx


static func _strip_chat_template_spans(s: String) -> String:
  if _chat_span_re == null:
    _chat_span_re = RegEx.new()
    _chat_span_re.compile("<\\|[^|]+\\|>")
  var cur := s
  var prev := ""
  while prev != cur:
    prev = cur
    cur = _chat_span_re.sub(prev, "").strip_edges()
  return cur.strip_edges()


## Same as [method normalize_completion_token], but for the ARMED handshake: accepts [code]START[/code] as a
## whole word anywhere in the reply (chat models rarely put only [code]START[/code] as the first token).
## Params:
## - raw: Model message content.
## Returns:
## - A legal token, or [code]noop[/code].
static func normalize_completion_token_armed_handshake(raw: Variant) -> String:
  if raw == null:
    return normalize_completion_token(raw)
  var s := _strip_chat_template_spans(str(raw).strip_edges())
  var strict := normalize_completion_token(s)
  if strict == "START":
    return "START"
  if s.is_empty():
    return "noop"
  if _start_word_re == null:
    _start_word_re = RegEx.new()
    _start_word_re.compile("(?i)\\bSTART\\b")
  if _start_word_re.search(s) != null:
    return "START"
  return strict


## Parses [param raw] per §4.2: strip chat markers, then first line / first token; if still unknown, first
## whole-word UP/DOWN/LEFT/RIGHT anywhere (play phase — does not search for START; that stays handshake-only).
## Returns one of [code]UP[/code], [code]DOWN[/code], [code]LEFT[/code], [code]RIGHT[/code], [code]START[/code],
## or [code]noop[/code] when the model output is not a recognized action.
static func normalize_completion_token(raw: Variant) -> String:
  if raw == null:
    return "noop"
  var s := _strip_chat_template_spans(str(raw).strip_edges())
  if s.is_empty():
    return "noop"
  var first_line := s.get_slice("\n", 0).strip_edges()
  var tok := first_line.get_slice(" ", 0).strip_edges().to_upper()
  if _LEGAL.has(tok):
    return tok
  if _dir_word_re == null:
    _dir_word_re = RegEx.new()
    _dir_word_re.compile("(?i)\\b(UP|DOWN|LEFT|RIGHT)\\b")
  var m := _dir_word_re.search(s)
  if m != null:
    var w := str(m.get_string(1)).strip_edges().to_upper()
    if _LEGAL.has(w) and w != "START":
      return w
  return "noop"
