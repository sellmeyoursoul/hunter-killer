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
