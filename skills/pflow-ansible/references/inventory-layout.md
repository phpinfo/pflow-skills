# Inventory, variables, project layout

## Repository layout
```
ansible.cfg
requirements.yml            # pinned collections + roles
inventories/
  production/  hosts.yml  group_vars/  host_vars/
  staging/     hosts.yml  group_vars/  host_vars/
group_vars/all/             # only if truly site-wide across envs (else per inventory)
playbooks/  site.yml  webservers.yml  dbservers.yml
roles/                      # project-local roles
collections/                # optional, ansible-galaxy -p target (gitignored)
molecule/ .ansible-lint .yamllint .pre-commit-config.yaml
```
- One inventory directory per environment; never one file mixing prod and staging (a typo in `--limit` becomes an outage). Same group names in every environment so playbooks stay identical.
- `site.yml` only `import_playbook`s tier playbooks; tier playbooks map groups → roles, nothing else. Filenames `verb-noun.yml` (`deploy-webapp.yml`) or tier names.
- Custom plugins in `library/`, `filter_plugins/`, `module_utils/` next to playbooks, or inside a collection.
- Commit `requirements.yml` with pinned versions (`version: ">=3.0.0,<4.0.0"` or exact); install with `ansible-galaxy install -r requirements.yml`. Never vendor Galaxy roles into `roles/`. Gitignore `collections/ansible_collections/` and `*.retry`.

## Inventory
- Directory inventories (`hosts.yml` + `group_vars/` + `host_vars/` + plugin configs) over one giant file; YAML over INI. Multiple sources are merged, so a dynamic plugin (`amazon.aws.aws_ec2`, `community.general.proxmox`, `constructed`) can sit next to static groups.
- Group by function (`webservers`, `dbservers`), and separately by environment/location (`prod`, `eu_west`); use `children:` to compose. Every host in exactly one "type" group that has exactly one playbook.
- Loop over inventory groups, never over a hand-maintained host list in vars; `--limit`, `serial`, throttling and inheritance all depend on it.
- Inventory is the single source of truth for *desired* state; discovered (as-is) data comes from facts and must not be hand-copied into inventory.
- Connection settings (`ansible_user`, `ansible_become`, `ansible_python_interpreter`, `ansible_host`) live in `group_vars/<group>/ansible.yml` or `host_vars`, not in playbooks.
- Host/group names: `snake_case` or DNS names; no spaces or dashes in group names (Jinja can't address them).

## Where a variable lives
Precedence (low→high, abbreviated): role defaults < inventory group_vars/all < group_vars/* < host_vars < facts/cached set_fact < play `vars`/`vars_files` < role `vars/` < block/task vars < `include_vars` < `set_fact`/`register` < role params < `-e` extra vars.
- Role defaults: shareable, overridable base values.
- `group_vars/all`: site-wide settings. `group_vars/<group>`: per-function/per-env. `host_vars`: exceptions only.
- Split `group_vars/<group>/` into files named after the role they configure (`nginx.yml`, `postgresql.yml`) plus `ansible.yml` for connection vars and `vault.yml` for secrets; a role's `defaults/main.yml` can then be dropped in as-is.
- Avoid play-level `vars:`, `vars_files`, `vars_prompt` and `include_vars` for state — they beat all inventory and blur code/data. Reserve for runtime/computed values.
- `-e` extra vars only for debugging, dry-run switches, or one-off targets; never for desired state (they vanish with the run).
- Using two mechanisms for the same variable (e.g. group_vars *and* role params) is a bug waiting to happen; pick one.
- Variable names: `snake_case`, letters/digits/underscore, no leading digit, not a Python or playbook keyword, not `lookup`/`query`/`now`. Leading `_` is convention only, not privacy.
- Duplicated hard-coded values across group_vars → move to a higher group or role default. Environment differences belong in `inventories/<env>/group_vars`, not in `when: env == 'prod'` branches.

## ansible.cfg (project-local, committed)
```ini
[defaults]
inventory = inventories/staging      # safe default; prod passed explicitly with -i
roles_path = roles
collections_path = collections
interpreter_python = auto_silent
forks = 20
gathering = smart
fact_caching = jsonfile
fact_caching_connection = .facts_cache
fact_caching_timeout = 3600
retry_files_enabled = false
stdout_callback = ansible.builtin.default
callback_result_format = yaml
timeout = 30
[ssh_connection]
pipelining = true                    # needs !requiretty in sudoers on targets
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
```
- Search order: `ANSIBLE_CONFIG` → `./ansible.cfg` → `~/.ansible.cfg` → `/etc/ansible/ansible.cfg`; only the first found is used, no merging. Ansible refuses `./ansible.cfg` in a world-writable cwd.
- Never `host_key_checking = False` in a committed config; manage known_hosts instead (or scope it to ephemeral test inventories).
- `vault_password_file` may point to a `*-client` script; never to a file in the repo.
