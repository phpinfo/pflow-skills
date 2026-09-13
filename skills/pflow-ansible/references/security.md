# Security and secrets

## Secrets
- Plaintext secrets never enter Git — history is forever. Pre-commit `gitleaks`/`detect-secrets`; push protection on the forge.
- Vault indirection pattern, per group:
  ```
  group_vars/dbservers/vars.yml    db_password: "{{ vault_db_password }}"
  group_vars/dbservers/vault.yml   vault_db_password: s3cret     # ansible-vault encrypt vault.yml
  ```
  Plain file stays greppable; only `vault.yml` is encrypted. Never encrypt entire `group_vars/all` (kills reviewability, `--diff`).
- Prefer `ansible-vault encrypt_string --vault-id prod@prompt 'value' --name 'vault_db_password'` for single values inside YAML when a whole file is overkill.
- One vault ID per environment/trust level (`dev@`, `prod@`), `--vault-id prod@~/.vault/prod-client.sh`; set `vault_id_match = True` so a dev password can't silently "decrypt" prod. Password source: prompt, a `*-client` script pulling from a keyring/secret manager, or CI secret — never a file in the repo. Rotate with `ansible-vault rekey`.
- Alternatives when a secret manager exists: `lookup('community.hashi_vault.hashi_vault', …)`, `lookup('env', 'TOKEN')` in CI, AAP credential objects. Fetch at runtime; don't persist into facts or files.
- `no_log: true` on every task that receives, prints or registers a secret (`uri` with auth headers, `user` with `password`, `mysql_user`, `set_fact` of tokens, `debug` of registered results). Lint `no-log-password` catches only obvious `password:` args.
- `no_log` limits: hides the task result, not `-vvv` connection debug, not the `debug` module's own output, not `loop` labels — add `loop_control: label:`. A `debug: var: result` of a `no_log` task prints nothing useful; remove it before commit.
- `diff: false` on templates/copies of secret-bearing files, or `--diff` prints the secret.
- Registered results that carry secrets should be `set_fact`-ed only for what is needed, or consumed immediately.

## Privilege escalation
- `become: true` at the smallest scope that needs it: task or block, not a blanket play-level default when only half the tasks require root. Never `become` in `ansible.cfg` for the whole project.
- `become_user` without `become: true` does nothing (`partial-become`). Never `become_user: root` redundantly.
- Becoming an *unprivileged* user from an unprivileged connection user needs ACL support on the target, else module tmp files may end up world-readable; enable `pipelining` or set `ansible_common_remote_group`. Don't set `allow_world_readable_tmpfiles`.
- `become_password` via `--ask-become-pass` or vault; sudoers should grant `NOPASSWD` for the automation user rather than shipping the password.
- Don't run everything as root and then `chown`; create files as the right owner (`owner:`/`group:`/`mode:`).

## Files and transport
- Every file-producing task sets `mode:` explicitly (`"0600"` for secrets, `"0644"` configs, `"0755"` executables) and `owner`/`group` where it matters. Default umask-dependent modes differ between hosts and lint flags them (`risky-file-permissions`).
- `validate_certs: false` is a finding, not a default; fix the CA bundle (`ca_path`) instead. Same for `ansible_ssh_common_args: -o StrictHostKeyChecking=no` outside ephemeral test inventories.
- `get_url`/`unarchive` from the internet: pin `checksum: sha256:...`. `git:` pin a tag/commit, `version: main` only for dev.
- `template`/`copy` `validate: /usr/sbin/nginx -t -c %s` before overwriting critical configs; `backup: true` for hand-edited legacy files.
- `ansible.builtin.shell` with user-supplied variables is injection: use `command` with argv list (`argv: [cmd, "{{ var }}"]`) or `| quote`.
- `ansible.cfg` in a world-writable directory is ignored by design; keep repo perms sane, set `ANSIBLE_CONFIG` in CI.

## Least privilege and audit
- Automation accounts, CI tokens, AAP/AWX credentials get only the rights the playbook uses; rotate tokens ~90 days, SSH keys yearly.
- Environments isolated by inventory *and* by credentials — a prod vault ID must not open in a staging run.
- All changes via Git (GitOps): no manual UI/host edits; the commit is the audit trail.
