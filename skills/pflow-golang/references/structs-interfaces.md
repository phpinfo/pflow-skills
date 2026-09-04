# Structs and interfaces

## Interfaces

- Define interfaces in the **consuming** package, sized to what that consumer calls (1–3 methods). Producers export concrete types.
- Accept interfaces, return structs. Returning an interface hides methods and forces type assertions downstream.
- Don't create an interface for a single implementation "for testing" unless a test really needs a fake; a small interface at the boundary (DB, HTTP, clock, filesystem) is the right place.
- Compile-time compliance check next to the type: `var _ Store = (*PgStore)(nil)`.
- Compose from small interfaces: `type ReadWriteCloser interface { Reader; Writer; Closer }`.
- Never use pointers to interfaces. An interface holding a pointer is already indirect.
- `any` is not an abstraction. Prefer generics with a constraint or a concrete type. Type switches are for a closed, known set of types.
- Method sets: a `*T` satisfies interfaces with value and pointer receivers; a `T` only value receivers. Store `*T` in interfaces when methods mutate.

## Receivers

- Pointer receiver when the method mutates, when the struct is large, or contains a mutex/slice/map you mutate. Value receiver for small immutable values (`time.Time`, coordinates).
- All methods of one type use the same receiver kind. Don't mix.
- Don't define methods on maps, slices, or funcs unless you own the behavior (e.g. `sort.Interface`-style helpers).

## Structs

- Group fields by meaning; put the mutex right above the fields it guards with a comment. Exported fields first.
- Zero value must be usable or the constructor must be the only way to build it (unexported fields + `New…`).
- Prefer composition via a named field over embedding. Embed only to promote a whole interface (`io.Reader`) or to implement an interface by default; never embed in exported structs to save typing — it leaks the embedded API and breaks on upgrades.
- Never embed `sync.Mutex` in an exported struct; `Lock()` becomes public API. Use an unexported field `mu sync.Mutex`.
- Field tags are data, not logic: `json:"user_id,omitempty"`, `yaml:"url"`. Keep tag names snake_case and stable; one struct per wire format when shapes differ (`UserDTO` vs domain `User`).
- Don't store `context.Context` in a struct. Don't store loggers in every struct; pass `*slog.Logger` to constructors that need one.
- Copying: structs with slices/maps/pointers are shallow copies. Provide `Clone()` when deep copy is a real need.
- Sort large structs into pointers when passed around; pass small structs (≤ 3 words) by value.

## Type assertions and switches

- Two-value form always: `s, ok := v.(fmt.Stringer)`. Single-value only when a panic is the intent.
- Type switch on the interface variable; bind the typed value: `switch x := v.(type) { case *A: … case B: … }`. Add `default` that returns an error.
- Prefer behavior checks over type checks: `if c, ok := w.(io.Closer); ok { c.Close() }`.

## Generics

- Use generics for containers and algorithms independent of element type (`Map[K comparable, V any]`, `Filter[T any]`). Don't use them to avoid writing two small functions or when an interface expresses the behavior better.
- Constraints from `cmp` (`cmp.Ordered`) and `constraints`-style local interfaces; keep type parameters few and named `T`, `K`, `V`.
- Let inference work: don't spell type arguments at call sites unless required.
- Methods can't have type parameters; put generic algorithms in functions.
- Generic type aliases are available since Go 1.24.

## Enums

```go
type Status int

const (
    StatusUnknown Status = iota // zero value stays "unknown"
    StatusActive
    StatusDisabled
)

func (s Status) String() string { … }   // or `go tool stringer`
```

- Give enums a `String()`, and `MarshalText`/`UnmarshalText` when serialized. Validate on parse; never trust ints from the wire.
- Use `exhaustive` linter; handle `default` explicitly.
