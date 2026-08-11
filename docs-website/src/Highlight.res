open Xote

/* A small tokenizer for the snippets on this page.
 *
 * It replaces highlight.js, which was being asked for a `rescript` grammar it
 * does not have — so it threw and every block rendered unhighlighted.
 *
 * This is deliberately not a parser. It recognises comments, strings and
 * keywords, and calls everything else plain text. Being pure, it runs during
 * SSR and hydrates to identical markup, so blocks arrive highlighted in the
 * HTML rather than being patched in afterwards. When a construct is ambiguous
 * the tokenizer emits plain text: unstyled is fine, wrongly styled is not.
 */

type token =
  | Plain(string)
  | Comment(string)
  | Str(string)
  | Keyword(string)

type language = ReScript | Json | Shell

let languageOfString = (name: string): language =>
  switch name {
  | "json" => Json
  | "bash" | "sh" | "shell" => Shell
  | _ => ReScript
  }

let keywords = [
  "and",
  "as",
  "assert",
  "else",
  "exception",
  "external",
  "false",
  "for",
  "if",
  "in",
  "include",
  "let",
  "module",
  "mutable",
  "of",
  "open",
  "rec",
  "switch",
  "true",
  "try",
  "type",
  "when",
  "while",
]

let isKeyword = (word: string): bool => keywords->Array.includes(word)

let isIdentChar = (char: string): bool =>
  switch char {
  | "_" | "'" => true
  | _ =>
    let code = char->String.charCodeAt(0)->Float.toInt
    (code >= 48 && code <= 57) || (code >= 65 && code <= 90) || (code >= 97 && code <= 122)
  }

/* Appends `text` to the run of plain text being accumulated, so consecutive
   plain characters become one token instead of one per character. */
let flushPlain = (tokens: array<token>, pending: ref<string>): unit =>
  if pending.contents != "" {
    tokens->Array.push(Plain(pending.contents))
    pending := ""
  }

/* Scans forward from `start` (the opening quote) to the matching close, honouring
   backslash escapes. Returns the index just past the closing quote, or the end of
   the input for an unterminated string. */
let scanString = (source: string, start: int, quote: string): int => {
  let length = source->String.length
  let index = ref(start + 1)
  let closed = ref(false)

  while !closed.contents && index.contents < length {
    let char = source->String.charAt(index.contents)
    if char == "\\" {
      index := index.contents + 2
    } else if char == quote {
      index := index.contents + 1
      closed := true
    } else {
      index := index.contents + 1
    }
  }

  index.contents > length ? length : index.contents
}

/* Scans an identifier or number starting at `start`. */
let scanWord = (source: string, start: int): int => {
  let length = source->String.length
  let index = ref(start)
  while index.contents < length && isIdentChar(source->String.charAt(index.contents)) {
    index := index.contents + 1
  }
  index.contents
}

let tokenizeReScript = (source: string): array<token> => {
  let length = source->String.length
  let tokens: array<token> = []
  let pending = ref("")
  let index = ref(0)

  while index.contents < length {
    let char = source->String.charAt(index.contents)
    let next = index.contents + 1 < length ? source->String.charAt(index.contents + 1) : ""

    if char == "/" && next == "/" {
      // Line comment, to the end of the line.
      flushPlain(tokens, pending)
      let stop = switch source->String.indexOfFrom("\n", index.contents) {
      | -1 => length
      | at => at
      }
      tokens->Array.push(Comment(source->String.slice(~start=index.contents, ~end=stop)))
      index := stop
    } else if char == "\"" || char == "`" {
      flushPlain(tokens, pending)
      let stop = scanString(source, index.contents, char)
      tokens->Array.push(Str(source->String.slice(~start=index.contents, ~end=stop)))
      index := stop
    } else if isIdentChar(char) {
      let stop = scanWord(source, index.contents)
      let word = source->String.slice(~start=index.contents, ~end=stop)
      if isKeyword(word) {
        flushPlain(tokens, pending)
        tokens->Array.push(Keyword(word))
      } else {
        pending := pending.contents ++ word
      }
      index := stop
    } else {
      pending := pending.contents ++ char
      index := index.contents + 1
    }
  }

  flushPlain(tokens, pending)
  tokens
}

/* JSON needs only strings; `//` never appears and the keyword list would be
   misleading. */
let tokenizeJson = (source: string): array<token> => {
  let length = source->String.length
  let tokens: array<token> = []
  let pending = ref("")
  let index = ref(0)

  while index.contents < length {
    let char = source->String.charAt(index.contents)
    if char == "\"" {
      flushPlain(tokens, pending)
      let stop = scanString(source, index.contents, "\"")
      tokens->Array.push(Str(source->String.slice(~start=index.contents, ~end=stop)))
      index := stop
    } else {
      pending := pending.contents ++ char
      index := index.contents + 1
    }
  }

  flushPlain(tokens, pending)
  tokens
}

/* Shell snippets here are single commands. The command name reads as the one
   meaningful token; the rest is arguments. */
let tokenizeShell = (source: string): array<token> =>
  source
  ->String.split("\n")
  ->Array.mapWithIndex((line, lineIndex) => {
    let separator = lineIndex == 0 ? [] : [Plain("\n")]
    let trimmed = line->String.trim
    if trimmed->String.startsWith("#") {
      Array.concat(separator, [Comment(line)])
    } else {
      switch line->String.indexOf(" ") {
      | -1 => Array.concat(separator, [Keyword(line)])
      | at =>
        Array.concat(
          separator,
          [
            Keyword(line->String.slice(~start=0, ~end=at)),
            Plain(line->String.sliceToEnd(~start=at)),
          ],
        )
      }
    }
  })
  ->Array.flat

let tokenize = (source: string, language: language): array<token> =>
  switch language {
  | ReScript => tokenizeReScript(source)
  | Json => tokenizeJson(source)
  | Shell => tokenizeShell(source)
  }

let renderToken = (token: token): View.node =>
  switch token {
  | Plain(text) => View.text(text)
  | Comment(text) =>
    View.element("span", ~attrs=[View.attr("class", "tok-comment")], ~children=[View.text(text)], ())
  | Str(text) =>
    View.element("span", ~attrs=[View.attr("class", "tok-string")], ~children=[View.text(text)], ())
  | Keyword(text) =>
    View.element("span", ~attrs=[View.attr("class", "tok-keyword")], ~children=[View.text(text)], ())
  }

let render = (source: string, ~language: string="rescript"): View.node =>
  tokenize(source, languageOfString(language))->Array.map(renderToken)->View.fragment
