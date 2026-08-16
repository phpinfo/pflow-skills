[README.md#D72C]
1:# pflow-skills
2:
3:[![skills.sh](https://skills.sh/b/phpinfo/pflow-skills)](https://skills.sh/phpinfo/pflow-skills)
4:
5:A curated catalog of [Agent Skills](https://docs.claude.com/en/docs/claude-code/skills) for everyday development workflows — installable into Claude Code, Cursor, OpenCode, and any [skills.sh](https://www.skills.sh/docs)-compatible agent.
6:
7:Skills are small, composable folders of instructions and scripts that teach your agent to do one task well. No application code here — just the skills.
8:
9:## Quickstart
10:
11:Install the whole catalog into the current project (30 seconds):
12:
13:```bash
14:npx skills add phpinfo/pflow-skills
15:```
16:
17:Or pick a single skill:
18:
19:```bash
20:npx skills add phpinfo/pflow-skills -s pflow-commit
21:```
22:
23:| Flag | Effect |
24:| --- | --- |
25:| _(default)_ | Install into the project (`.agents/skills/`) |
26:| `-g`, `--global` | Install for every project (`~/.agents/skills/`) |
27:| `--copy` | Copy files instead of symlinking |
28:
29:## Skills
30:
31:| Skill | What it does |
32:| --- | --- |
33:| [`pflow-commit`](skills/pflow-commit) | Analyzes your working tree, writes a [Conventional Commit](https://www.conventionalcommits.org/) message, then commits and pushes. Invoked manually. |
34:| [`pflow-task-add`](skills/pflow-task-add) | Adds a new task to the `mdtodo` task list. The agent clarifies the task's essence, formulates a concise title and description with expected result, then adds it via `mdtodo`. Invoked manually. |
35:| [`pflow-task-plan`](skills/pflow-task-plan) | Builds a concrete implementation plan for the current active `mdtodo` task. The agent clarifies open questions, analyzes the codebase and docs, decomposes the work into small steps, and saves the plan to a file. Plans only — does not implement. Invoked manually. |
36:| [`pflow-task-implement`](skills/pflow-task-implement) | Implements the saved plan for the current active `mdtodo` task. The agent reads the plan from `PFLOW_TASKS_PLAN_FILE`, reviews it critically, decomposes it into todos, then executes each step in order with verification. Implements only — does not plan, commit, or close the task. Invoked manually. |
37:| [`pflow-task-next`](skills/pflow-task-next) | Takes the next `mdtodo` task into progress and creates a git branch named for it (`feature/`, `fix/`, `chore/`). Requires a clean working tree on the dev branch. Invoked manually. |
38:| [`pflow-task-finish`](skills/pflow-task-finish) | Closes the current `mdtodo` task; when `pflow-commit` is installed, branches the work, commits it, and merges into `dev`. Degrades to mdtodo-only with a warning otherwise. Invoked manually. |
39:| [`pflow-changelog`](skills/pflow-changelog) | Generates a [Keep a Changelog](https://keepachangelog.com/) entry for the current feature version based on completed tasks and git commits, prepends it to `CHANGELOG.md`, then commits and pushes. Requires a clean working tree on the dev branch. Invoked manually. |
40:| [`pflow-refactor`](skills/pflow-refactor) | Performs evidence-based refactoring research for a code, component, or subsystem. Produces an As Is analysis and a minimal, justified To Be proposal with naming, dependency, migration, and trade-off recommendations. Applies SOLID, KISS, YAGNI, DRY, Law of Demeter, and composition over inheritance. Analysis only — does not implement changes. Invoked manually. |
41:| [`pflow-grill`](skills/pflow-grill) | Grills you relentlessly about a plan, decision, or idea until you reach a shared understanding. Maps the subject as a design tree and interviews in rounds — each round asks every question whose prerequisites are settled, with lettered answer options and a recommendation. Adapted from [mattpocock/skills `grilling`](https://github.com/mattpocock/skills/blob/main/skills/productivity/grilling/SKILL.md). Fires on "grill" trigger phrases. |
| [`pflow-bro`](skills/pflow-bro) | Re-explains the previous assistant message in plain language when the last reply was too dense, jargon-heavy, or formal. No new information, no tools — same facts, said so they're impossible to misunderstand. Adapted from [luchasarie/bro-skill](https://github.com/luchasarie/bro-skill/blob/main/SKILL.md). Fires on `/bro`. |
42:
43:## Configuration
44:
45:Most skills work with zero configuration. `pflow-task-finish` accepts optional settings, supplied as **CLI arguments** (passed by the agent to its script) or as **environment variables** — either exported in your shell or placed in a `.env` file at the project root, which the script loads automatically (parsed, never executed; values already set in the real environment take precedence).
46:
47:### `pflow-commit`
48:
49:**Requires:** none.
50:
51:### `pflow-task-finish`
52:
53:**Requires:** `pflow-commit` (optional — without it, the task is closed via `mdtodo` but all git steps are skipped with a warning).
54:
55:**CLI arguments** (`task-finish.sh`):
56:
57:| Argument | Required | Description |
58:| --- | --- | --- |
59:| `--message "<msg>"` | yes (when committing) | Conventional Commit message for the finished work. Ignored in fallback mode (no `pflow-commit`), where no commit happens. |
60:| `--slug "<slug>"` | no | Kebab-case name for the task branch (`task/<slug>`). Defaults to a slug derived from the current task title. Ignored when finishing from a non-dev branch (see below). |
61:| `--dev "<branch>"` | no | Branch to merge the task branch into. Highest-priority override of the dev branch (see below). |
62:
63:**Environment variables** (env or `.env`):
64:
65:| Variable | Default | Description |
66:| --- | --- | --- |
67:| `PFLOW_TASKS_MDTODO_FILE` | _(mdtodo's own default, `todo.md`)_ | Path to the Markdown todo list. Exported as `MDTODO_FILE` once before any `mdtodo` call, so the whole flow operates on this file. |
68:| `PFLOW_GIT_DEV_BRANCH` | `dev` | Branch the task branch is merged into. If the chosen branch does not exist, the work merges into the branch you started on. |
69:| `MDTODO_FILE` | `todo.md` | Read directly by the `mdtodo` CLI. `PFLOW_TASKS_MDTODO_FILE` sets this for you; set it yourself if you prefer. |
70:
71:**Dev-branch precedence:** `--dev` flag → `PFLOW_GIT_DEV_BRANCH` → autodetected `dev`/`develop` → default `dev`. If the resolved branch is absent, the merge target falls back to the branch you started on.
72:
73:**Branch reuse:** when run from a non-dev branch (e.g. one created by `pflow-task-next`), it commits and merges THAT branch instead of creating `task/<slug>`. Creating `task/<slug>` only happens when finishing straight from the dev branch.
74:
75:### `pflow-task-add`
76:
77:**Requires:** none.
78:
79:**CLI arguments** (`task-add-run.sh`):
80:
81:| Argument | Required | Description |
82:| --- | --- | --- |
83:| `--title "<title>"` | yes | Concise task name (single line). |
84:| `--description "<desc>"` | no | Expected result and key details. Inserted as indented lines under the task in the markdown file. |
85:| `--version "<version>"` | no | Version tag in `vX.Y.Z` format, only when the user specifies one. |
86:
87:**Environment variables** (env or `.env`):
88:
89:| Variable | Default | Description |
90:| --- | --- | --- |
91:| `PFLOW_TASKS_MDTODO_FILE` | _(mdtodo's own default, `todo.md`)_ | Path to the Markdown todo list. Exported as `MDTODO_FILE` before any `mdtodo` call. |
92:
93:### `pflow-task-plan`
94:
95:**Requires:** `mdtodo` CLI.
96:
97:**Scripts:** `plan-context.sh` (resolves the tasks file and reads the active task), `plan-save.sh` (reads the plan Markdown from stdin and writes it to `PFLOW_TASKS_PLAN_FILE`).
98:
99:**Environment variables** (env or `.env`):
100:
101:| Variable | Default | Description |
102:| --- | --- | --- |
103:| `PFLOW_TASKS_MDTODO_FILE` | _(mdtodo's own default, `todo.md`)_ | Path to the Markdown todo list. Used to read the current active task. |
104:| `PFLOW_TASKS_PLAN_FILE` | `./tmp/pflow-tasks-plan.md` | Path the generated plan is written to. Parent directories are created automatically. |
105:
106:### `pflow-task-implement`
107:
108:**Requires:** `mdtodo` CLI; a plan file produced by `pflow-task-plan`.
109:
110:**Scripts:** `implement-context.sh` (resolves the tasks file, reads the active task, and verifies the plan file exists and is non-empty).
111:
112:**Environment variables** (env or `.env`):
113:
114:| Variable | Default | Description |
115:| --- | --- | --- |
116:| `PFLOW_TASKS_MDTODO_FILE` | _(mdtodo's own default, `todo.md`)_ | Path to the Markdown todo list. Used to read the current active task. |
117:| `PFLOW_TASKS_PLAN_FILE` | `./tmp/pflow-tasks-plan.md` | Path the plan is read from. Must match the value used by `pflow-task-plan`. |
118:
119:### `pflow-task-next`
120:
121:**Requires:** none.
122:
123:**CLI arguments** (`task-next-branch.sh`):
124:
125:| Argument | Required | Description |
126:| --- | --- | --- |
127:| `--branch "<type/slug>"` | yes | Name of the branch to create and switch to (e.g. `feature/login-form`). Composed by the agent from the task. |
128:
129:**Environment variables** (env or `.env`):
130:
131:| Variable | Default | Description |
132:| --- | --- | --- |
133:| `PFLOW_TASKS_MDTODO_FILE` | _(mdtodo's own default, `todo.md`)_ | Path to the Markdown todo list. Exported as `MDTODO_FILE` before any `mdtodo` call. |
134:| `PFLOW_GIT_DEV_BRANCH` | `dev` | Branch the new task branch must be created from. The skill errors unless you are on this branch with a clean working tree. |
135:
136:### `pflow-changelog`
137:
138:**Requires:** `pflow-commit` (reuses `git-lib.sh` for commit/push).
139:
140:**Environment variables** (env or `.env`):
141:
142:| Variable | Default | Description |
143:| --- | --- | --- |
144:| `PFLOW_FEATURES_MDTODO_FILE` | _(required)_ | Path to the Markdown features list. Used to determine the current feature and its version. |
145:| `PFLOW_TASKS_MDTODO_FILE` | _(mdtodo's own default, `todo.md`)_ | Path to the Markdown tasks list. Used to list completed tasks. |
146:| `PFLOW_GIT_DEV_BRANCH` | `dev` | Branch the skill must run on. Errors if current branch differs. |
147:
148:## How it works
149:
150:Each skill is a self-contained folder under `skills/`:
151:
152:```
153:skills/
154:└── <name>/
155:    ├── SKILL.md        # frontmatter (name, description, allowed-tools) + instructions
156:    └── scripts/        # executable helpers the skill calls
157:```
158:
159:The agent reads every `SKILL.md` description up front and triggers the matching skill when the task fits. Heavy logic lives in `scripts/` so the prompt stays short and reliable.
160:
161:## Creating a skill
162:
163:1. Add `skills/<name>/SKILL.md` with YAML frontmatter (`name`, `description`, and `allowed-tools` for any scripts).
164:2. Make scripts executable and reference them by their **installed** path — `.agents/skills/<name>/scripts/...`.
165:3. Add a row to the [Skills](#skills) table above.
166:
167:Write the `description` to say plainly *what the skill does and when it fires* — it's the signal the agent uses to decide whether to reach for it.
168:
169:## License
170:
171:MIT