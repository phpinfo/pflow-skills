# Message format (Conventional Commits)

`<type>[(scope)][!]: <description>` plus an optional blank line, body, and footer(s).

- Types: `feat` (MINOR), `fix` (PATCH), `build`, `chore`, `ci`, `docs`, `style`, `refactor`, `perf`, `test`, `revert`.
- Breaking change: `!` in the header or a `BREAKING CHANGE: ...` footer (MAJOR).
- `scope` — only when it adds value. Pick the narrowest correct type; split unrelated types into separate commits.
- Description — short, in English, imperative mood ("add", not "added").

Examples: `feat: add user page` · `fix(parser): handle empty input` · `feat!: remove legacy auth flow`
