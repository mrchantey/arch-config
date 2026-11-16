# agents

Global instructions and user skills for every agent runtime on the machine. Stow skips this README, as it does any `README.*` at a package's top level.

## One set of instructions

Every agent reads `.agents/AGENTS.md`, stowed to `~/.agents/AGENTS.md`, which is where Zed reads it. Claude Code and Codex each insist on their own path, so this package also stows `.claude/CLAUDE.md` and `.codex/AGENTS.md` as links back to it. Edit the one file; never give a tool its own copy. `just stow-symlinks` keeps `~/.codex` a real dir before stowing, since folded it would take `codex login`'s `auth.json` into the repo.

## Skills

User skills live in `.agents/skills`, which `just stow-symlinks` links to `~/.agents/skills` by hand, since Omarchy pre-creates that path as a real dir and stow cannot fold it. Zed's own agent and Codex read `~/.agents/skills`; Claude Code reads only `~/.claude/skills`, so this package also stows `.claude/skills -> ../.agents/skills`. That covers both the `claude` CLI and Zed's Claude agent, whose ACP adapter bundles its own Claude Code. Omarchy pre-creates `~/.claude/skills` as a real dir too, so the recipe clears it first: stow cannot replace a real dir with a link, and one conflict aborts every package.

Omarchy's migrations `ln -sfn` their skills (`omarchy`, `diagnose-crash`) into both dirs. With the links in place those writes land in the repo, so they are gitignored and re-dropped by `stow-symlinks` from `$OMARCHY_PATH/default/agents/skills/*`. Claude Code also writes its claude.ai skill sync to `~/.claude/skills/synced/`, which likewise lands in the repo, is gitignored, and is visible to every other agent reading the dir.

Project skills follow the same pattern: they live in a repo's `.agents/skills`, with a `.claude/skills -> ../.agents/skills` link beside it.
