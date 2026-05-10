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


## Same as [method normalize_completion_token], but for the ARMED handshake: accepts [code]START[/code] as a
## whole word anywhere in the reply (chat models rarely put only [code]START[/code] as the first token).
## Params:
## - raw: Model message content.
## Returns:
## - A legal token, or [code]noop[/code].
static func normalize_completion_token_armed_handshake(raw: Variant) -> String:
  var strict := normalize_completion_token(raw)
  if strict == "START":
    return "START"
  if raw == null:
    return "noop"
  var s := str(raw).strip_edges()
  if s.is_empty():
    return "noop"
  if _start_word_re == null:
    _start_word_re = RegEx.new()
    _start_word_re.compile("(?i)\\bSTART\\b")
  if _start_word_re.search(s) != null:
    return "START"
  return strict


## Parses [param raw] per §4.2: trim, first line, first token, ASCII upper-case; legal keys only.
## Returns one of [code]UP[/code], [code]DOWN[/code], [code]LEFT[/code], [code]RIGHT[/code], [code]START[/code],
## or [code]noop[/code] when the model output is not a recognized action.
static func normalize_completion_token(raw: Variant) -> String:
  if raw == null:
    return "noop"
  var s := str(raw).strip_edges()
  if s.is_empty():
    return "noop"
  var first_line := s.get_slice("\n", 0).strip_edges()
  var tok := first_line.get_slice(" ", 0).strip_edges().to_upper()
  if _LEGAL.has(tok):
    return tok
  return "noop"
