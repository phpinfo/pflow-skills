# Style and naming

Priority order when rules collide: clarity > simplicity > concision > maintainability > consistency. Always `gofmt`/`goimports`; no line-length limit, but break long calls after the open paren.

## Naming

- `MixedCaps` everywhere; never underscores (except `_test.go` files and generated code). Initialisms keep case: `userID`, `HTTPClient`, `xmlAPI`.
- Name length scales with scope: `i`, `r`, `buf` for short locals; descriptive for package-level and exported names.
- Do not encode the type: `users` not `userSlice`, `count` not `countInt`. Do not repeat the package: `zip.Reader` not `zip.ZipReader`; `http.Client` not `http.HTTPClient`.
- Package names: short, lowercase, singular, one word, no `util`/`common`/`base`/`helpers`/`models`. Name after what it provides, not what it contains.
- Getters have no `Get`: `u.Name()`, setter `u.SetName()`. Booleans read as predicates: `isReady`, `hasNext`, `IsValid()`.
- One-method interfaces end in `-er`: `Reader`, `Closer`, `Validator`. Avoid `I`-prefix and `Interface`/`Impl` suffixes.
- Constructors: `New()` when the package has one main type, `NewClient()` otherwise. Return the concrete type.
- Errors: variables `ErrNotFound`, types `NotFoundError`. Messages lowercase, no trailing punctuation, no "failed to" chains.
- Receivers: 1–2 letters, consistent across all methods of the type (`c *Client` everywhere), never `this`/`self`.
- Enums start at 1 (`iota + 1`) unless zero is a meaningful default; type them: `type Level int`.
- Test names: `TestType_Method_case`; subtests `"empty input"`, `"nil receiver"` — readable, no underscores needed.
- Unexported globals get an `_` prefix only in Uber style; otherwise avoid globals entirely.

## Layout of a function

- Happy path stays at the lowest indentation; error paths return early. Prefer `if err != nil { return }` over `else`.
- No naked returns in functions longer than a few lines; named results only to document meaning or for `defer` mutation.
- Keep functions short enough to read without scrolling; extract when a comment starts to describe "step 2".
- Group declarations: `const`, `var`, types, then functions ordered by call sequence (exported first per type).
- Declare variables close to first use; use `:=` unless the zero value is intended (`var buf bytes.Buffer`).
- `var s []string` (nil) over `s := []string{}` unless JSON must render `[]`. `nil` slices and maps are fine to read and `range`.
- Reduce nesting: invert conditions, `continue` early inside loops, use `switch` over long `if/else if` chains.

## Comments

- Doc comment on every exported symbol. Full sentence, starts with the name: `// Parse parses …`, `// ErrClosed is returned when …`. Package comment `// Package x …` in one file only.
- Comments say *why*, not *what*. Delete a comment that restates the code. `// TODO(name): …` with an owner.
- `Deprecated:` paragraph on its own line; point to the replacement.

## Imports

- Three groups separated by blank lines: stdlib, third-party, this module. Let `goimports`/`gci` sort them.
- Alias only on collision or when the last path element is not the package name. No dot imports; blank imports only in `main` or tests, with a comment.

## Misc

- Use `time.Duration`, never `int` seconds. Use `any`, not `interface{}`.
- Avoid `init()`; do explicit setup in `main` or constructors. `os.Exit` and `log.Fatal` only in `main`, once, after cleanup.
- Format strings as constants when reused: `const msgFmt = "…"`. Prefer raw strings for regexes and multi-line text.
- Don't shadow `err` inside `if`/`for` when the outer one is read later; don't shadow imports (`url`, `len`).
- Struct literals with field names for any struct you don't own or with >2 fields; positional only for tiny local pairs.
