---
name: pflow-commit
description: Анализирует изменения, формирует Conventional Commit на русском, коммитит и пушит. Вызывается только вручную.
license: MIT
allowed-tools:
  - Bash(.claude/skills/pflow-commit/scripts/git-commit-context.sh)
  - Bash(.claude/skills/pflow-commit/scripts/git-commit-push.sh:*)
---

При любой ошибке (ненулевой код Shell-команды ИЛИ поле `error` в JSON-выводе) выведи `⚠️ <сообщение ошибки>` и немедленно остановись.

## Шаги

1. Получи контекст: `.claude/skills/pflow-commit/scripts/git-commit-context.sh`. Если вывод — `No changes detected.`, сообщи, что коммитить нечего, и остановись.
2. Составь ТЕКСТ_СООБЩЕНИЯ (см. формат ниже).
3. Закоммить и запушь: `.claude/skills/pflow-commit/scripts/git-commit-push.sh --message "ТЕКСТ_СООБЩЕНИЯ"`. Скрипт печатает JSON: `{commit_hash, branch_name, push_status}` при успехе или `{…, error:{step, message}}` при сбое. Если есть `error` — выведи `⚠️ <error.message>` и остановись.
4. Ответь строго, подставив значения из JSON:

   ```text
   ✅ Сообщение коммита:
   ТЕКСТ_СООБЩЕНИЯ

   ✅ Закоммичено и запушено:
   Hash: <commit_hash> | Branch: <branch_name> | Status: <push_status>
   ```

## Gotchas

- `git-commit-push.sh` делает `git add -A` — в коммит попадут ВСЕ изменения рабочего дерева, а не только относящиеся к сообщению. Учитывай это при составлении текста.
- Контекст из шага 1 усечён: максимум 50 строк на файл и 600 строк суммарно. Большие диффы видны не полностью — не делай выводов об отрезанной части.
- `push_status`: `pushed` (upstream уже был) либо `pushed_with_upstream` (создан через `git push -u origin <branch>`).
- Ошибки git скрипт push не пишет в stderr — они попадают в JSON-поле `error`. Всегда проверяй его (шаг 3), иначе провал коммита/пуша останется незамеченным.

## Формат сообщения (Conventional Commits)

`<type>[(scope)][!]: <описание>` + опционально пустая строка, body, footer'ы.

- Типы: `feat` (MINOR), `fix` (PATCH), `build`, `chore`, `ci`, `docs`, `style`, `refactor`, `perf`, `test`, `revert`.
- Breaking change: `!` в заголовке или footer `BREAKING CHANGE: ...` (MAJOR).
- `scope` — только если полезен. Выбирай самый узкий корректный тип; разные типы → разные коммиты.
- Описание — кратко, на русском, в пассивной форме прошедшего времени.

Примеры: `feat: добавлена страница пользователя` · `fix(parser): обработан пустой ввод` · `feat!: удалён старый флоу авторизации`
