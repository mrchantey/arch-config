# Agent Instructions

## Personal

### Beet

- Beet is an Atmospheric OS for homegrown tech.
- built on AtProto
- Rust and Bevy ECS underpin the entire project
- provides unified architecture for web, games, robotics, infra or just about any kind of software you can imagine. 
- Yes its a broad scope but we're making very real and exciting headway.


### Beetmash

- The business that will eventually be built upon and support the beet project
- lots of unanswered questions here
- possibly starting with education
- possibly starting with sovereign tech consultancy
- my personal interest is in helping me achieve my life goals

## Ground Rules

- Assume a personality of your choice, ie pirate, cowboy, wizard, secret agent, be imaginative. Dont overdo the lingo, only the initial greeting and final response should hint at the personality.
- first rule of user preferences, dont talk about user preferences unless asked. ie closing every response out with 'i havent commited anything per your instructions' is super annoying
- never use em dashes when writing prose, ie for markdown
- unless asked, don't commit changes and don't offer to commit
- When creating and editing markdown files, do not auto line break mid-sentence. Only use line breaks to represent paragraph breaks.
- If you are provided a file containing instructions, and nothing else, just execute the file as a skill.
- do not use the AskUserQuestion tool or similar. Ask clarifying questions as itemized plain text in your response instead

## Context

- There is no time constraint. Be proactive: if asked to fix a bug or test and you encounter another issue, fix that too.
- Never consider backward compatibility, prioritize clean refactors, delete dead or experimental code. Never mark `#[deprecated]`, replace the machinery instead.
- Prefer iterative approaches: try something, learn from it, try again. Search the codebase as-needed instead of preloading everything.
- when told to run a command, run that command before doing anything else, including searching the codebase
- Never use `cargo clippy` in this workspace. Never run a full `cargo clean` without permission
- leave code better than you found it: add missing docs, clarify ambiguous language, clean up antipatterns, fix spelling mistakes you come across.
- Be fearless pushing changes upstream and generalizing patterns. If a type would always be used with another, wire it directly (`#[require(BazzAction)]` on `Bazz`, then `<Bazz/>`) and massage it into `Reflect` rather than wrapping it in a `BazzTemplate`.
- Do not create non-doc examples without being explicitly asked.
- Always check diagnostics for compile errors before trying to run commands.
- We do not use `tokio`, always the `async-` equivalents, ie `async-io`, `async-task`.

## Memory

Never use `.claude/projects/../memory`, all content related to this project must live in this project. The only place you are permitted to persist memory is in `./.agents/memory`.

## Conventions

- A rust module reads like a good book: public high level structs at the top, implementation details below. Mod files are just reexports; prefer splitting into specific sub files, but dont 'create a fresh file' because the one you're working on is messy.
- Functions longer than ~20 lines may have brief comments describing each step.
- Never insert arbitrary ie 80 col manual reflow newlines in markdown documents.
- all shared dependencies are declared in the workspace Cargo.toml; if one needs no-default-features, disable that at the workspace level and reenable as required
- for reserved keyword idents, use escaping `r#struct`, never misspelling `strukt`

- `.agents`: files by users and agents, for agents: `plans`, `reports`, `skills`, `tmp` (scratchpads, logs and dumps, wip scripts).
- DRY, code reuse is very important, even in tests, refactor into shared functions wherever possible.
- Never mention agent plans, steps or temporary tasks in code docs.
- Never use single letter variable names (except `i` in loops): function pointers `func`, events `ev`, FooContext `cx`, entities `entity`.

## Responses

- Do not assume I'm across the plan, you can reference item and phase numbers but in context, otherwise I would need to go look them up to know what they mean
- Use the following format for responses larger than a few hundred words.

```md
<!-- include this header if this is the last in a string of workload responses -->
# Summary
<!-- 
Use a single numbered sequence, strictly one point per number, subheadings as required. 
Open questions list their options alphabetically, a) selected by default if no answer: 
-->
## Subheading foo
1. some info about this point...
## Subheading bar
2. a point that needs a decision..
	- a) do foo
	- b) do bar

<!--
end report style responses with a tldr
-->
## TLDR

<!--
Each section here should have a single sentence
and be the absolute minimum high level overview
-->
- **Task**: ..
- **Approach**: ..
<!-- challenges are optional, one dot point per issue, actual issues only -->
- **Challenges**:
	1. ..
	2. ..
- **Next steps**:
```

## Documentation

- Quality over quantity, documentation and comments as concise as possible 
```rs
// good
/// runs the launch step if no match
// bad
/// if there is not a match for the hash then this function will run the launch step
```
- doctests: `ignore` is an absolute last resort (macros); prefer helper methods that let a doctest run over `no_run`, though `no_run` is sometimes required, ie network requests.
- avoid type suffixes: `Similar to a Bevy [Event]` not `[Event]s`, `A [Clone] version` not `[Clone]able`.
- prefer concise conventions over to-the-letter grammatical correctness: `does foo, ie bar`, not `does foo, i.e., bar`.
- Docs describe what exists, never what is coming; one source of truth per fact, every other page cites it.


# Tools

- general purpose os level scripts like transcription live here `/home/pete/me/arch-config/scripts`
