// Simple ReScript syntax highlighter
open Xote

let keywords = [
  "let",
  "type",
  "module",
  "open",
  "switch",
  "if",
  "else",
  "true",
  "false",
  "and",
  "or",
  "rec",
  "external",
  "include",
  "when",
]

let types = ["int", "string", "bool", "float", "array", "option", "unit"]

let highlight = (code: string): View.node => {
  let lines = code->String.split("\n")

  let highlightLine = (line: string, lineNumber: int): View.node => {
    let lineNum = (lineNumber + 1)->Int.toString

    // Check if line is a comment
    let lineContent = if line->String.trim->String.startsWith("//") {
      View.element(
        "span",
        ~attrs=[View.attr("class", "syntax-comment")],
        ~children=[View.text(line)],
        (),
      )
    } else {
      // Simple word-based highlighting
      let words = line->String.split(" ")
      let highlightedWords = words->Array.mapWithIndex((word, idx) => {
        let trimmed = word->String.trim

        let isKeyword = keywords->Array.some(k => trimmed == k || trimmed->String.startsWith(k ++ "("))
        let isType = types->Array.some(t => trimmed == t)
        let isString = trimmed->String.startsWith("\"") || trimmed->String.startsWith("`")
        let isNumber =
          trimmed->String.match(%re("/^[0-9]+$/")) != None ||
            trimmed->String.match(%re("/^[0-9]+\.[0-9]+$/")) != None

        let className = if isKeyword {
          "syntax-keyword"
        } else if isType {
          "syntax-type"
        } else if isString {
          "syntax-string"
        } else if isNumber {
          "syntax-number"
        } else {
          "syntax-text"
        }

        View.fragment([
          View.element(
            "span",
            ~attrs=[View.attr("class", className)],
            ~children=[View.text(word)],
            (),
          ),
          idx < Array.length(words) - 1
            ? View.text(" ")
            : View.fragment([]),
        ])
      })

      View.fragment(highlightedWords)
    }

    View.element(
      "div",
      ~attrs=[View.attr("class", "syntax-line")],
      ~children=[
        View.element(
          "span",
          ~attrs=[View.attr("class", "syntax-line-number")],
          ~children=[View.text(lineNum)],
          (),
        ),
        View.element(
          "span",
          ~attrs=[View.attr("class", "syntax-line-content")],
          ~children=[lineContent],
          (),
        ),
      ],
      (),
    )
  }

  View.fragment(lines->Array.mapWithIndex((line, idx) => highlightLine(line, idx)))
}
