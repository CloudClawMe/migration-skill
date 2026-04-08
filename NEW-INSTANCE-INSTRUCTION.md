# Instruction for the new managed OpenClaw instance

Use the `openclaw-import` skill from `import-skill/SKILL.md`.

## Inputs provided by backend

- archive download URL, or
- migration id resolvable to archive download URL

## What the new instance should do

1. Confirm that this instance is a fresh target for full restore
2. Download the archive
3. Validate archive structure and manifest
4. Restore `openclaw-export/workspace/` into the current workspace
5. Avoid exposing secret values
6. Report success or failure briefly

## Suggested user-facing phrasing

- `Архив найден, начинаю импорт.`
- `Проверил структуру архива.`
- `Восстановил рабочее пространство.`
- `Импорт завершён.`

If something is wrong:
- `Не смог импортировать архив. Нужна новая ссылка или новый экспорт.`
