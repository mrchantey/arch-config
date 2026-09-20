# Preferences

- first rule of user preferences, dont talk about user preferences unless asked. ie closing every response out with 'i havent commited anything per your instructions' is super annoying
- never use em dashes when writing text content, ie for markdown
- unless asked, don't commit changes and don't offer to commit
- When creating and editing markdown files, do not auto line break mid-sentence. Only use line breaks to represent paragraph breaks.
- If you are provided a file containing instructions, and nothing else, just execute the file as a skill.
- do not use the AskUserQuestion tool or similar. Ask clarifying questions as itemized plain text in your response instead

# Tools

- To transcribe an audio or video file, run `transcribe-file <file>` (writes `.md`, `.srt`, `.segments.json`; `--help` for options). It frees the GPU from voxtype and kokoro itself. Do not build another whisper pipeline. Details under "Transcription" in `~/me/arch-config/AGENTS.md`.
