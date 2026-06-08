---
name: pflow-changelog
description: Generates a Keep a Changelog entry for the current feature version, prepends it to CHANGELOG.md, then commits and pushes. Requires clean working tree on the dev branch. Invoked manually only.
license: MIT
allowed-tools:
  - Bash(.agents/skills/pflow-changelog/scripts/changelog-context.sh)
  - Bash(.agents/skills/pflow-changelog/scripts/changelog-commit-push.sh:*)
---

On any failure (non-zero exit or `error` field in JSON) print `⚠️ <error message>` and stop.

## Steps

1. Get context: `.agents/skills/pflow-changelog/scripts/changelog-context.sh`. It returns JSON `{feature:{title,version}, tasks:[…], commits:"…"}` or `{error:{…}}`.
2. Analyze the context (tasks + commit messages). Summarize what was done in product terms — no tech internals, no process/dev meta. Then compose a changelog entry using the format below and **prepend** it to the existing `CHANGELOG.md` (create the file if absent, starting with the standard header: `# Changelog\n\nAll notable changes to this project will be documented in this file.`).
3. Commit and push: `.agents/skills/pflow-changelog/scripts/changelog-commit-push.sh`. It prints `{commit_hash, branch_name, push_status}` or `{…, error:{…}}`. If `error` is present, print `⚠️ <error.message>` and stop.
4. Reply exactly:

   ```text
   ✅ Changelog updated for <feature_title> (<feature_version>).
   ```

## Changelog format (Keep a Changelog)

Each version entry follows this structure:

```markdown
## [<version>] - YYYY-MM-DD

### Added
- for new features.

### Changed
- for changes in existing functionality.

### Deprecated
- for soon-to-be removed features.

### Removed
- for now-removed features.

### Fixed
- for any bug fixes.

### Security
- in case of vulnerabilities.
```

Rules:
- Use today's date (ISO 8601: `YYYY-MM-DD`).
- Omit empty sections (e.g., skip `### Deprecated` if nothing was deprecated).
- Group changes under the most fitting category. Prefer `### Added` / `### Changed` / `### Fixed`.
- One bullet per notable change, concise, user-facing.
- The changelog is for people, not machines. Focus on what changed and why from the user's perspective.
