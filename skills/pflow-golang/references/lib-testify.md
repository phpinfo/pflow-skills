# stretchr/testify — idioms

Enforce with the `testifylint` linter (golangci-lint). Project convention wins: if AGENTS.md says `assert.New(t)` per subtest, follow it.

## assert vs require

- `require` when the test cannot continue: setup, `NoError` on the call under test, `NotNil` before dereferencing, `Len` before indexing. It calls `t.FailNow` — never use it from a goroutine other than the test's.
- `assert` for the checks after that; multiple failures are reported together.
- Per-subtest instances (`a := assert.New(t); r := require.New(t)`) keep call sites short; in table tests create them inside `t.Run`.

## Correct assertion shapes

| Instead of | Use |
| --- | --- |
| `assert.Equal(t, nil, err)` / `assert.Nil(t, err)` | `require.NoError(t, err)` |
| `assert.Equal(t, ErrX, err)` / `assert.EqualError` with a string | `assert.ErrorIs(t, err, ErrX)`; `assert.ErrorAs(t, err, &target)` |
| `assert.True(t, a == b)` | `assert.Equal(t, a, b)` |
| `assert.Equal(t, 3, len(s))` | `assert.Len(t, s, 3)` |
| `assert.Equal(t, 0, len(s))` / `Len(0)` | `assert.Empty(t, s)` |
| `assert.True(t, strings.Contains(s, x))` | `assert.Contains(t, s, x)` |
| `assert.Equal(t, 1.0, f)` | `assert.InDelta(t, 1.0, f, 1e-9)` |
| `assert.Equal(t, t1, t2)` (time) | `assert.True(t, t1.Equal(t2))` or `WithinDuration` |
| `assert.Equal(t, expected, actual)` swapped | expected first, actual second — always |
| `assert.Equal(t, &a, &b)` | `assert.Equal(t, a, b)` (compares pointees via ObjectsAreEqual) or `assert.Same` for identity |
| `assert.Equal` on JSON strings | `assert.JSONEq(t, want, got)` |
| `assert.Nil(t, ptrInsideInterface)` | check the concrete pointer, typed-nil trap |
| `time.Sleep` then assert | `require.Eventually(t, cond, 2*time.Second, 10*time.Millisecond)` |
| `assert.Error(t, err)` then `err.Error()` compare | `ErrorIs`/`ErrorAs`; `ErrorContains` only for messages you own |

- Add a message only when it adds information: `assert.Equal(t, want, got, "user %d", id)`. Don't `assert.X(t, …, fmt.Sprintf(...))` — pass format args directly (`assertf` forms are legacy).
- `assert.Equal` uses `ObjectsAreEqual` (reflect.DeepEqual with `[]byte` special case); it distinguishes `int` from `int64` — cast expected values. Use `EqualValues` only when the type difference is intentional.
- `assert.Exactly` when the type must match. `assert.ElementsMatch` for order-independent slices. `assert.Subset`, `assert.EqualExportedValues`.
- `assert.Panics`/`PanicsWithError` for panic contracts; `assert.Implements` compile-time is better (`var _ I = (*T)(nil)`).

## mock package

- Prefer generated mocks (mockery) over hand-written `mock.Mock` embedding; see `lib-mockery.md`. Hand-written only for one-off tiny interfaces.
- Setup: `m.On("Get", ctx, "id").Return(user, nil).Once()`; matchers `mock.Anything`, `mock.AnythingOfType("string")`, `mock.MatchedBy(func(u User) bool {…})`.
- Always verify: `m.AssertExpectations(t)` — generated constructors `NewX(t)` register this in `t.Cleanup` automatically.
- `Maybe()` for optional calls; `Times(n)`; `.Run(func(args mock.Arguments) {…})` for side effects; `.RunAndReturn` (typed, mockery expecter).
- Don't assert on unexported behavior through mocks; mock at boundaries only.

## suite package

- `suite.Suite` when many tests share heavy setup (DB, server): `SetupSuite`, `SetupTest`, `TearDownTest`, `TearDownSuite`; run with `func TestX(t *testing.T) { suite.Run(t, new(XSuite)) }`.
- Suites don't support `t.Parallel()` across methods; use plain table tests when parallelism matters. Access the test via `s.T()`; assertions via `s.Require()` / `s.Assert()`.
- Keep suite fields for shared fixtures only; per-test state goes into locals.

## Misc

- Version: testify stays at v1.x; no v2. Go ≥ 1.19.
- `assert.NoError` on `defer` cleanup: `t.Cleanup(func() { assert.NoError(t, c.Close()) })`.
- `require.NoError(t, err)` reports only the error message — wrap errors with context in production code so failures are readable.
