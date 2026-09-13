# Role design

## Skeleton
```
roles/nginx/
  defaults/main.yml      # every user-facing variable, documented, with a default (or commented out)
  vars/main.yml          # constants, package/service names — NOT tunables (precedence too high)
  vars/RedHat.yml …      # per-platform constants, loaded via first_found
  tasks/main.yml         # thin: include_vars → validate → install.yml → configure.yml → service.yml
  handlers/main.yml
  templates/*.j2  files/
  meta/main.yml          # galaxy_info, min_ansible_version, platforms; avoid dependencies
  meta/argument_specs.yml
  molecule/default/
  README.md
```
- Role name: `snake_case`, no dashes (breaks collections). Pattern `object[_feature]`; never numbered.
- One role = one function (nginx, postgresql, app_deploy). Sub-parts as task files; promote to a separate role only when reused.

## Variables
- Prefix every variable with the role name: `nginx_port`, `nginx_packages`. Internal/computed: `__nginx_config_path`. Custom modules/plugins/tags also role-prefixed.
- `defaults/main.yml` is the public API: one default per input, grouped, commented. Inputs without a sane default go in commented out so the file lists all inputs.
- `vars/main.yml` holds facts-of-the-role (`nginx_packages: [nginx]`), never user tunables — role vars beat inventory group/host vars.
- Extension pattern: required list in `vars/` (`nginx_packages`), optional additions in defaults (`nginx_extra_packages: []`), then `{{ nginx_packages + nginx_extra_packages }}`.
- Validate inputs at the top of `tasks/main.yml` with `meta/argument_specs.yml` (auto-validated on `include_role`/`import_role`/`roles:`) or `ansible.builtin.assert` with `fail_msg`. Fail fast, before changing anything.
- Never `set_fact` a variable that shadows a default/var of the role; compute into a `__nginx_*` name.

## Platform handling
```yaml
- name: Load OS-specific vars
  ansible.builtin.include_vars: "{{ lookup('first_found', __nginx_vars_files) }}"
  vars:
    __nginx_vars_files:
      - "{{ role_path }}/vars/{{ ansible_facts['distribution'] }}_{{ ansible_facts['distribution_major_version'] }}.yml"
      - "{{ role_path }}/vars/{{ ansible_facts['distribution'] }}.yml"
      - "{{ role_path }}/vars/{{ ansible_facts['os_family'] }}.yml"
      - "{{ role_path }}/vars/default.yml"
```
- Most-specific first for tasks/vars via `first_found`, with a `default.yml` fallback. Use `ansible_facts['x']`, not `ansible_x` injected vars.
- Needs facts? Don't assume `gather_facts`; when it may be off run `ansible.builtin.setup: gather_subset: [min]` (or `'!all,!min,distribution'`) inside the role.

## Idempotence and check mode
- Second run with same inputs: `changed=0`, no failures. Molecule's `idempotence` step enforces it.
- `command`-based reads: prefer modules (`slurp`, `stat`, `find`); else `changed_when: false` + `check_mode: false` so check runs still get data.
- Tasks that must run in check mode to register data: `check_mode: false`. Tasks that cannot work under `--check` (e.g. depend on a package just "installed"): `when: not ansible_check_mode` and document.
- Handlers reload/restart services; tasks only notify. Never restart unconditionally.

## Coupling
- No hard `dependencies:` in `meta/main.yml` unless the role is useless without them; prefer the playbook composing roles, or a `common` role in the collection.
- Public interface is variables; consumers should never need to know task names. Wrapper "entry" roles for complex collections.
- Role has no knowledge of inventory groups (`groups['db']` inside a role is a smell); pass hosts/values as variables.
- Tags inside a role: role-prefixed; the whole role must be runnable with one tag.

## Documentation and meta
- `README.md`: purpose, every variable with default and meaning, example play, supported platforms (matches `meta/main.yml` `platforms`).
- `meta/main.yml`: `galaxy_info` with `author`, `description`, `license`, `min_ansible_version`, `platforms`, `galaxy_tags` (lint `meta-*` rules). Bump `version` on change.
- One molecule scenario per supported OS family; test converge → idempotence → verify.
