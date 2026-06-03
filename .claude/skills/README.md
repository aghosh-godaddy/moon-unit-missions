# `.claude/skills/`

Project-level Claude Code skills for this repo. Each subdirectory is a
single skill with a `SKILL.md` describing when it activates and what it
does. Skills here are auto-discovered when working anywhere in this repo.

## Naming convention

```
.claude/skills/
├── <mission-name>-<purpose>/    ← mission-scoped skill
└── <purpose>/                   ← cross-mission skill (no prefix)
```

- **Mission-scoped skills** prefix with the mission directory name. The
  prefix matches `missions/<name>/`, making the scope obvious at a glance.
 - `column-comments-config` → for the `missions/column-comments/` mission.
 - `table-metadata-config` → for the `missions/table-metadata/` mission.
 - `semantic-model-config` → for the `missions/semantic-model/` mission.

- **Cross-mission skills** use a generic verb-or-noun name with no prefix.
  Reach across missions or operate on shared infrastructure.
  - Example future skills: `moonunit-lint-manifest`, `inspect-mu-log`.

## Why everything lives here, not under each mission

Claude Code loads skills from `.claude/skills/` directories that sit on
the path between cwd and the filesystem root — it does **not** recurse
into subdirectories looking for nested skill folders. A skill at
`missions/foo/.claude/skills/` would only load when cwd is inside
`missions/foo/`, which makes mission-scoped skills invisible from the
repo root. Centralizing here ensures consistent discovery regardless of
cwd, at the cost of one shared namespace (handled by the prefix above).

## Skill contents

Each `<skill-name>/SKILL.md` should:
- Open with YAML frontmatter (`name`, `description`) — the description is
  what Claude matches against to decide whether to activate the skill.
- Point at the authoritative playbook (don't duplicate; link to a doc
  under the mission's `docs/`). Skills are pointers + activation rules,
  not the source of truth.
- List the helper scripts it chains, with one-line purpose each.
- Note non-obvious gotchas a fresh agent would otherwise re-discover.

Keep `SKILL.md` under ~100 lines. If it grows beyond that, the content
probably belongs in a mission doc that the skill links to.

## Adding a new skill

1. Create `.claude/skills/<name>/SKILL.md` with the frontmatter + body.
2. If the skill is mission-scoped, mention it from that mission's
   `CLAUDE.md` so future agents working in that subtree know to use it.
3. If the skill chains scripts, those scripts go under
   `missions/<mission>/scripts/` (or a shared location for cross-mission
   skills) — the skill should not contain the script logic itself.
