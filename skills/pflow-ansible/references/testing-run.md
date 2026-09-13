# Testing, linting, execution

## Local gate (fastest first)
1. `yamllint .` — `.yamllint` extending `default` with `line-length: {max: 160}`, `truthy: {allowed-values: ['true','false']}`, `comments-indentation: false`.
2. `ansible-lint` — `.ansible-lint` with `profile: production`; `exclude_paths` for `.cache/`, `collections/`; `skip_list` only with a comment why; `warn_list` for gradual adoption. Both in `.pre-commit-config.yaml` and CI.
3. `ansible-playbook --syntax-check -i inventories/staging playbooks/site.yml`.
4. `ansible-playbook -i inventories/staging playbooks/site.yml --check --diff --limit one_host` before touching prod; check mode is only meaningful if tasks are check-mode-safe (`roles.md`).
5. Real run twice against a throwaway host: second run must be `changed=0`.

## ansible-lint profiles (cumulative)
- `min`: loads. `basic`: FQCN-less deprecated syntax, `key-order`, `name`, `var-naming`, `no-free-form`, `no-jinja-when`, `partial-become`, `yaml`.
- `moderate`: `name[casing|imperative|template]`, `spell-var-name`. `safety`: `latest`, `package-latest`, `risky-file-permissions`, `risky-octal`, `risky-shell-pipe`, `avoid-implicit`.
- `shared`: `no-changed-when`, `no-handler`, `ignore-errors`, `no-relative-paths`, `meta-*`, `galaxy`, `max-block-depth`, `max-tasks`, `unsafe-loop`.
- `production`: `fqcn`, `avoid-dot-notation`, `import-task-no-when`, `meta-no-dependencies`, `single-entry-point`, `use-loop`, `sanity`.
- Fix the rule, don't `# noqa` it. If you must: `# noqa: rule-id` on the exact line with reason.

## Molecule (roles and collections)
- One scenario per supported OS family, container driver (`podman`/`docker`) for speed, VM driver only when systemd/kernel matters.
- Sequence to keep: `dependency → lint → create → prepare → converge → idempotence → verify → destroy`. `verify` with `ansible.builtin.assert`/`uri`/`command` checks (or testinfra) that the *outcome* holds, not that tasks ran.
- Test vars live in `molecule/<scenario>/converge.yml` or `group_vars`; reuse the role's `defaults`, don't duplicate them.
- Custom modules/filters/plugins: `pytest` unit tests (Arrange-Act-Assert), `ansible-test sanity` in collections.

## CI
- Pipeline: pre-commit (yamllint, ansible-lint, gitleaks) → syntax-check every playbook → molecule matrix → optional `--check --diff` against staging on merge → promotion to prod via tag/approval. Same execution environment (container image with pinned `ansible-core` + `requirements.yml`) locally and in CI.
- Pin `ansible-core`, collections (`requirements.yml`), Python deps (`requirements.txt`) — reproducibility beats "latest".

## Rollout controls
- `serial: 1` / `serial: ["10%", "50%", "100%"]` for rolling changes; a failure stops after the current batch. Combine with `max_fail_percentage` and `any_errors_fatal: true` for fail-fast fleets.
- `forks` (cfg/CLI) is the parallelism ceiling; `throttle:` lowers it per task (API rate limits); `strategy: free` when hosts are independent and slow ones shouldn't block. `order: sorted|shuffle` for predictable or load-spread batches.
- `run_once` + `delegate_to: localhost` for control-node steps (API calls, template rendering to local files); remember `run_once` is per `serial` batch. `delegate_facts: true` when the delegated result must belong to the delegate.
- `gather_facts: false` + explicit `setup: gather_subset:` on fact-free plays (API/network/localhost) saves seconds per host; `gathering = smart` + `fact_caching` for repeated runs.
- Long operations: `async: 600` + `poll: 10` (or `poll: 0` + `async_status` loop) so SSH timeouts don't kill upgrades. `wait_for`/`wait_for_connection` after reboots (`ansible.builtin.reboot` does it).
- `--limit`, `--tags`, `--start-at-task`, `--step` are debugging tools; production runs execute the whole playbook so state converges — partial runs breed drift.
- Callback: `callback_result_format = yaml` for readable diffs; `ansible.posix.profile_tasks` to find slow tasks. Never leave `ANSIBLE_DEBUG`/`-vvvv` output in CI logs when secrets are in play.
