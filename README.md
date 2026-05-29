# pflow-skills

Каталог [Agent Skills](https://docs.claude.com/en/docs/claude-code/skills) для использования с [skills.sh](https://github.com/vercel-labs/skills) и любым совместимым агентом (Claude Code, Cursor, OpenCode и др.).

## Установка

Установить все скиллы из этого репозитория:

```bash
npx skills add phpinfo/pflow-skills
```

Установить конкретный скилл:

```bash
npx skills add phpinfo/pflow-skills -s pflow-commit
```

Флаги: `-g` — глобально (`~/.claude/skills/`), без флага — в проект (`.claude/skills/`); `--copy` — копировать файлы вместо симлинков.

## Скиллы

| Скилл | Описание |
| --- | --- |
| [pflow-commit](skills/pflow-commit) | Анализ изменений, Conventional Commit на русском, коммит и push. Вызывается вручную. |

## Структура

Каждый скилл — это каталог в `skills/` с файлом `SKILL.md` (YAML-фронтматтер: `name`, `description`, `allowed-tools`) и опциональной папкой `scripts/`.

```
skills/
  <skill-name>/
    SKILL.md
    scripts/
```

## Создание скилла

Добавьте каталог `skills/<name>/` с `SKILL.md`. Описание (`description`) должно ясно указывать, что скилл делает и когда срабатывает — по нему агент решает, применять ли скилл.
