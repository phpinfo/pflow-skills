# Tasks, plays, handlers, style

## YAML and Jinja2
- 2-space indent; list items indented under their key. `---` at top. `.yml` extension; templates end in `.j2`, named after their destination (`nginx.conf.j2`).
- YAML-style module args (key: value), never `key=value` free-form.
- Booleans `true`/`false` only (not `yes`/`no`/`True`). Positive names (`nginx_enabled`, not `nginx_disabled`).
- Single space inside `{{ }}`. Quote any value that *starts* with `{{`. Double quotes for YAML strings, single quotes inside Jinja (`"{{ item['name'] }}"`).
- `>-` for folded long strings (no trailing newline); break long `when` into a list (implicit AND).
- Bracket access `item['key']`, not dot notation (collides with dict methods; lint `avoid-dot-notation`).
- Cast user input: `| int`, `| bool`, `| float` before comparing. Bare var in `when` needs `| bool`.
- `when:` is already Jinja — no `{{ }}` inside it (`no-jinja-when`).
- `default(omit)` to skip an optional module parameter; `default('x')` for values. `is defined` / `is not none` before use.
- Strings containing literal `{`/`}` that must not be templated: `!unsafe`.
- Prefer filter plugins over long inline Jinja; extract repeated sub-expressions into a single `set_fact` or `vars:` on the block.

## Tasks
- FQCN always. Name every task/play/block; imperative; variables only at the end of a task name, never in play names, never in handler names or loop vars in names.
- `state: present|absent|started` explicit. `mode` for every file/copy/template/lineinfile/get_url (`risky-file-permissions`); quoted `"0644"` or `u=rw,go=r` (`risky-octal`).
- No `latest` for packages in convergence code (`package-latest`); pin versions or use `present`.
- `ansible.builtin.package`/`service` meta-modules over distro-specific ones unless a specific option is needed. Pass the whole list to `package`, never loop it.
- `template` over `copy` for config files; `copy` only for static binaries/certs. Avoid `lineinfile`/`blockinfile` for files a template can own — they drift.
- `command`/`shell`: last resort, comment why. Add `changed_when:` (often `false`) or `creates:`/`removes:`; never `shell` unless pipes/redirects/env expansion needed; with pipes set `set -o pipefail` and `executable: /bin/bash` (`risky-shell-pipe`). Never inline `FOO=bar cmd` — use `environment:`.
- No `ignore_errors: true` as flow control; use `failed_when:`, `block/rescue`, or `register` + `when`. Never `ignore_errors` on a block that contains `assert`.
- `failed_when`/`changed_when` on registered results, checking `rc`/`stdout`, not string equality of the whole output.
- `when: result is changed` → use a handler instead. `when: var == ""` → `when: var | length == 0`. Compare with `is`/`match`/`search`, not `== True`.
- `meta: end_host` over `meta: end_play`. `run_once` + `serial` runs once per batch — use `when: inventory_hostname == ansible_play_hosts_all[0]` for truly-once.
- `debug` messages get `verbosity: 1+` unless they are the deliverable.
- Minimise scope: `vars:` on task/block beats `set_fact` (facts persist for the whole play and outrank inventory).

## Loops
- `loop:` over `with_*` (keep `with_fileglob`/`with_first_found` lookups). `with_items` flattened one level — migrate with `| flatten(levels=1)`.
- Dicts: `loop: "{{ mydict | dict2items }}"` → `item.key`/`item.value`. Nested: `subelements`, `product`.
- Always `loop_control: label:` when items are big or secret-bearing (label is cosmetic, not `no_log`). `loop_var:` when an included file loops inside a loop (inner `item` would shadow outer).
- Registered loop result is `.results[]`; `changed`/`failed` is true if *any* item was.
- `until: cond` + `retries:` + `delay:` for eventual consistency; the condition is per item.

## Blocks and error handling
- `block:` groups tasks and shares `when`/`become`/`vars`/`tags`; a block cannot `loop`.
- `rescue:` runs on task failure (not on unreachable hosts or parse errors); `always:` always. Inside rescue use `ansible_failed_task.name` / `ansible_failed_result`; end with `meta: flush_handlers` so notified handlers still run, or re-fail deliberately.
- A rescued failure still counts in stats and is not a success — don't hide real errors.
- Keep nesting shallow (lint `max-block-depth`); a block with >1 level of nesting belongs in a task file.

## Handlers
- Handlers restart/reload; tasks notify. Name uniquely across the play (last definition wins on collision). Prefer `listen: "restart nginx"` topics so roles stay decoupled; role-qualified `role_name : handler name` when needed.
- No variables in handler names; put them in the handler's params. Handlers ignore tags and run once per play regardless of notify count, in *definition* order, at play end (or at `meta: flush_handlers`).
- `include_role`/`import_role` inside handlers is not allowed. Notifying an `include_tasks` name runs all its tasks; `import_tasks` rewrites into individual handlers.
- Use `force_handlers: true` (play or cfg) when a failed host must still get its restarts.

## Reuse: import vs include
- `import_*` static: parsed up front, tags and `--list-tasks` see inside, cheap. Cannot loop; filenames only templated from extra-vars/play vars. `when` on `import_tasks` applies to every task inside (`import-task-no-when`) — prefer `include_tasks` there.
- `include_*` dynamic: runtime; supports `loop` and inventory-var filenames; tags don't propagate into it (tag the include itself); can't `--start-at-task` inside.
- Don't mix `roles:` and `tasks:` in one play — ordering is non-obvious; pick `roles:` or `import_role`/`include_role` under `tasks:`.
- Playbook-level reuse only via `import_playbook`.
- Absolute paths for includes: `"{{ role_path }}/tasks/{{ ansible_os_family }}.yml"`; never rely on relative paths (`no-relative-paths`).

## Tags
- Tag whole roles/purposes, one tag per meaningful unit; prefix role tags with the role name. Every tag must be safe to run alone. `never`/`always` sparingly; document all tags.
