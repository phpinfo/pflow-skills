---
name: pflow-commit
description: Анализирует изменения, формирует Conventional Commit на русском, коммитит и пушит. Вызывается только вручную.
allowed-tools:
  - Bash(.claude/skills/pflow-commit/scripts/git-commit-context.sh)
  - Bash(.claude/skills/pflow-commit/scripts/git-commit-push.sh:*)
---

При любой ошибке Shell-команды выведи `⚠️ ТЕКСТ_ОШИБКИ` и немедленно остановись.

## Шаги

1. Получи контекст: `.claude/skills/pflow-commit/scripts/git-commit-context.sh`
2. Составь ТЕКСТ_СООБЩЕНИЯ (см. формат ниже).
3. Закоммить и запушь: `.claude/skills/pflow-commit/scripts/git-commit-push.sh --message "ТЕКСТ_СООБЩЕНИЯ"` → вернёт `commit_hash`, `branch_name`, `push_status`.
4. Ответь строго:

   ```text
   ✅ Сообщение коммита:
   ТЕКСТ_СООБЩЕНИЯ

   ✅ Закоммичено и запушено:
   Hash: <commit_hash> | Branch: <branch_name> | Status: <push_status>
   ```

## Формат сообщения (Conventional Commits)

`<type>[(scope)][!]: <описание>` + опционально пустая строка, body, footer'ы.

- Типы: `feat` (MINOR), `fix` (PATCH), `build`, `chore`, `ci`, `docs`, `style`, `refactor`, `perf`, `test`, `revert`.
- Breaking change: `!` в заголовке или footer `BREAKING CHANGE: ...` (MAJOR).
- `scope` — только если полезен. Выбирай самый узкий корректный тип; разные типы → разные коммиты.
- Описание — кратко, на русском, в пассивной форме прошедшего времени.

Примеры: `feat: добавлена страница пользователя` · `fix(parser): обработан пустой ввод` · `feat!: удалён старый флоу авторизации`
