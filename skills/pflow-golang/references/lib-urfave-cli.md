# urfave/cli — idioms (check `cli` in go-stack output for v2 vs v3)

## Structure

- One file per command; `main.go` only builds the root and calls `Run`. Register subcommands in the parent's `Commands` slice.
- Root holds global flags (`--config`, `--url`, `--verbose`); commands hold their own. Read global flags inside subcommands through the context/command, don't copy them.
- Every command has `Name`, `Usage` (one line, no period), `ArgsUsage` when it takes args, and an `Action` returning `error`. Long help goes in `Description`.
- `Before` on the root for setup shared by all commands (load config, build client); `After` for cleanup.
- Exit codes: return `cli.Exit("message", code)` from actions; let `Run` print it. Never `os.Exit` inside an action. Distinguish usage errors (2) from runtime failures (1).
- Output: human text to stdout, diagnostics/logs to stderr; offer `--json`/`--output` when scripts consume the tool. Pass writers (`cmd.Writer`/`app.Writer`) into functions, don't `fmt.Println` deep in logic — it's also what makes tests possible.
- Handle `SIGINT`: run with a `signal.NotifyContext` context so long RPCs stop cleanly.
- Business logic lives outside the command file (`internal/usecase`); the action parses flags, calls one function, prints. Tests target that function; a thin CLI test runs `app.Run([]string{"app", "cmd", "--flag"})` with a buffer writer.

## v2 (`github.com/urfave/cli/v2`)

```go
app := &cli.App{
    Name: "tool", Usage: "does things",
    Flags: []cli.Flag{
        &cli.StringFlag{Name: "config", Aliases: []string{"c"}, EnvVars: []string{"TOOL_CONFIG"}, Value: "~/.tool.yml", Usage: "config path"},
    },
    Commands: []*cli.Command{listCmd()},
}
if err := app.RunContext(ctx, os.Args); err != nil { fmt.Fprintln(os.Stderr, err); os.Exit(1) }

func listCmd() *cli.Command {
    return &cli.Command{
        Name: "list", Usage: "list items", ArgsUsage: "[filter]",
        Flags: []cli.Flag{&cli.BoolFlag{Name: "json"}},
        Action: func(c *cli.Context) error {
            cfg := c.String("config")            // global flag is visible via c.String
            return runList(c.Context, c.App.Writer, cfg, c.Bool("json"), c.Args().First())
        },
    }
}
```

- Access: `c.String/Int/Bool/Duration/StringSlice("name")`, `c.IsSet`, `c.Args().Slice()`, `c.NArg()`. Precedence: flag > env > default.
- `Required: true` on flags; `Destination: &var` binds directly. `Category` groups flags in help.
- `app.ExitErrHandler` to customize error printing; `cli.HandleExitCoder`. `app.EnableBashCompletion = true` for completions.

## v3 (`github.com/urfave/cli/v3`) — differences

- `cli.App` is gone; the root is a `*cli.Command`. `Subcommands` → `Commands`.
- Action signature: `func(ctx context.Context, cmd *cli.Command) error`. `cli.Context` removed: `cmd.String("x")`, `cmd.Args()`, `cmd.IsSet`, `cmd.Root()`, `cmd.Writer`.
- Run: `cmd.Run(ctx, os.Args)` (context required).
- Env/file sources: `EnvVars: []string{"X"}` → `Sources: cli.EnvVars("X")`; files via `cli.Files(...)`; alt sources (yaml/toml) moved to `github.com/urfave/cli-altsrc/v3`.
- `EnableBashCompletion` → `EnableShellCompletion`. `PathFlag` → `StringFlag{TakesFile: true}`. `TimestampFlag.Layout` → `Config: cli.TimestampConfig{Layouts: …}`.
- Flag types are generics-based (`cli.FlagBase`); custom flags implement `Get`/`Set` on a value type.
- `Before` returns `(context.Context, error)`; return the (possibly enriched) ctx.

## Gotchas

- Flags after positional args are not parsed by default; document `tool cmd --flag arg` order or enable `UseShortOptionHandling`/arg reordering deliberately.
- Default help/version commands are added automatically; set `HideHelpCommand` only for single-command tools.
- `EnvVars` values are strings — validate durations/ints as they arrive.
- Don't read `os.Args` or env directly in actions; everything comes through flags so `--help` stays truthful.
