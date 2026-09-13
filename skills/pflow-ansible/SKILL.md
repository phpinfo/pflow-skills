---
name: pflow-ansible
description: Ansible good practices — do/don't rules for playbooks, roles, tasks, handlers, inventories, variables, vault, ansible.cfg and Jinja2 templates. Use whenever a task adds, edits or reviews Ansible content or asks how to do something in Ansible.
license: MIT
---

Failing project commands (`ansible-lint`, `--syntax-check`) are findings — report and continue.

## Steps

1. Read the references matching the task (below) from `.agents/skills/pflow-ansible/references/`; skip the rest.
2. Follow project conventions (`ansible.cfg`, `.ansible-lint`, existing role/inventory layout) over these rules when they conflict — and say so.
3. Write or review the change. Twice-run must report `changed=0` and work under `--check`; anything else needs a comment saying why.
4. When available, run `ansible-lint` (project config, else `--profile production`) and `ansible-playbook --syntax-check`; for behavior changes also `--check --diff` on a non-prod inventory. Report results.

| Task | Read |
| --- | --- |
| Any task, play, handler, template | `tasks-style.md` |
| Role structure or variables | + `roles.md` |
| Inventory, group_vars/host_vars, ansible.cfg, requirements.yml, repo layout | + `inventory-layout.md` |
| Secrets, vault, become, file permissions | + `security.md` |
| Lint/CI config, molecule, rollout (serial, forks, strategy) | + `testing-run.md` |
| Review | `tasks-style.md`, `security.md`, then task-specific |

## Iron rules

- State is data: desired state in inventory (`group_vars`/`host_vars`), logic in roles, glue in playbooks. Never define state via `-e` or `set_fact` shadowing role vars.
- Role variables are role-prefixed (`nginx_port`), internals `__nginx_*`; every input has a default in `defaults/main.yml`.
- Secrets never plaintext in Git: vault-encrypted `vault_*` vars referenced from plain vars, `no_log: true` where they flow.
