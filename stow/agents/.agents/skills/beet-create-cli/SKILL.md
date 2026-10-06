---
name: beet-create-cli
description: Create a beet CLI, ie a CliServer root over a Router whose commands are routes, flags are request params and --help is middleware, authored as a main.bsx entry. Use when building or extending a CLI on beet.
---

# Create a beet CLI

A beet CLI is just a router: a [`CliServer`] reads the process args as a [`Request`], the [`Router`] dispatches it to a child route, and the route's response is written to stdout. There is no bespoke arg-parsing layer: a command is a route, its flags are request params, and `--help` is router middleware.

The canonical example is beet's own entry, `main.bsx` at the beet checkout root (`/home/pete/me/beet`), served by the `beet` binary (`crates/beet-cli`). Read it alongside this skill, with `crates/beet-cli/README.md` for entries and downstream binaries. Bare paths below are relative to the beet checkout.

## 1. The entry

A CLI is an entry document: a one-shot `CliServer` root with a `Router` child, each command a route action tag beneath it.

```bsx
<CliServer always=true {CallOnReady}>
<Router {HelpHandler}>
	<RunWasm/>
	<Check/>
	<QrCode/>
</Router>
</CliServer>
```

- `CallOnReady` calls the root with the process request once the entry builds; `CliServer` routes it into the `Router` and streams the response to stdout, mapping a non-OK status to a non-zero exit code.
- `always=true` dispatches on every boot regardless of `--server`, for a root that is purely a command dispatcher (see the `CliServer::always` docs).
- Each command tag is one command. Its `#[action(route = "...")]` attribute requires the path and dispatch components, so the tag alone is a self-describing route: `beet qrcode` hits the `qrcode` route.
- From Rust, `Router::with_defaults()` is the batteries-included bundle: `Router` plus `RequestLogger`, `HelpHandler`, `NavigateHandler` and the default app routes.

## 2. A command

A command is an `#[action(route = "...")]` async fn taking [`RequestParts`] and returning `Result<String>`, the string being the response body. Derive `Reflect` + `#[reflect(Component)]` and register the type in the crate's plugin (`app.register_type::<QrCode>()`, see `CliCommandsPlugin`) so an entry resolves it by tag.

```rust
#[action(route = "qrcode")]
#[derive(Component, Reflect)]
#[reflect(Component)]
#[require(ParamsPartial = ParamsPartial::new::<QrCodeParams>())]
pub async fn QrCode(parts: RequestParts) -> Result<String> {
	let params = parts.parse_params::<QrCodeParams>()?;
	let output = params.output.as_deref().unwrap_or("qrcode.png");
	// ..
	Ok(format!("wrote qr code to {output}"))
}
```

A command needing the world or a richer response takes `ActionContext<RequestParts>` and returns `Result<Response>` instead (see `RunWasm`).

## 3. Params: parse, never hand-roll

Define a `Reflect` struct for the flags. Do NOT pull values out one by one with `parts.get_param("..")`, which skips validation and drifts from the help listing. Read the whole struct in one call, `RequestParts::parse_params`, which walks the struct exactly as `ParamsPartial` does for `--help`, so what the help says a flag is, the parse enforces:

```rust
/// Request params for the [`QrCode`] command, surfaced in `--help`.
#[derive(Reflect)]
struct QrCodeParams {
	/// The text/url to encode.
	input: String,
	/// The output file path, defaults to `qrcode.png`.
	output: Option<String>,
}
```

```rust
// BAD: manual, unvalidated, invisible to --help
let input = parts.get_param("input").ok_or_else(|| bevyhow!(".."))?;

// GOOD: one typed read
let params = parts.parse_params::<QrCodeParams>()?;
```

Rules for the params struct:

- Field names are snake_case; the CLI flag is the kebab-case form, ie `out_dir` ↔ `--out-dir`. The normalisation is automatic.
- `bool` → a flag (`--release`), `false` when absent. `Option<T>` → optional, `None` when absent. `Vec<T>` → repeatable (`--tag=a --tag=b`), empty when absent. Any other field is required: parsing errors naming the flag when it is missing, and `--help` lists it as required.
- A default that is not "absent" is the handler's, not the struct's: declare `width: Option<u32>` and read `params.width.unwrap_or(1280)`. A bare `width: u32` would make the flag required.
- A value parses through its type's `LiteralParser`, the same table markup attributes use, so a field is typed as what it is: `store: Option<StoreUri>`, `timeout: Duration`, `created: Timestamp`, a numeric primitive, `String`/`SmolStr`. Nested and newtype structs flatten into the parent's flags.
- No `Default` or `#[reflect(Default)]` is needed, the read supplies every field.
- A markup-authored preset that flags override field-by-field reads through `parts.apply_params(&mut preset)` instead, which touches only the flags present (see `BuildWasm`).

## 4. `--help` is free

`#[require(ParamsPartial = ParamsPartial::new::<QrCodeParams>())]` registers the param metadata on the route. The router's `HelpHandler` intercepts `--help`, walks the [`RouteTree`], and renders the available routes and their params. Doc comments on the params fields become the flag descriptions, so document them. `beet --help` lists everything; `beet qrcode --help` scopes to that subtree.

## 5. Greedy routes and forwarding args

A trailing `*name` segment captures the rest of the args greedily, eg the `run-wasm/*run-wasm-args` cargo runner. To rebuild a forwardable arg vector from the request use [`RequestParts::to_cli_args`], whose [`CliArgs`] holds every path segment in `path` and the flags in `params`; mutate it, then [`CliArgs::into_args`] for the argv:

```rust
// `[run-wasm, <binary>, ..forwarded]`: drop the command segment consumed by
// the route, then forward the rest
let mut cli = parts.to_cli_args();
cli.path.remove(0);
let args = cli.into_args();
```

## 6. Output and content negotiation

The body is rendered per the `--accept` header (default: ansi-term, then text, markdown, json). A plain `Ok(String)` prints as text; a scene route (eg `render_action::async_route`) renders through the beet_ui pipeline, so `--accept=text/html` yields HTML and the default yields styled terminal output. Rendering requires `RouterPlugin`, part of `BeetPlugins` under the `router` feature.

## 7. Shipping the CLI

The `beet` binary links capabilities but ships no commands: on startup it discovers `main.bsx` by walking the cwd's ancestors (`--main=<path>` overrides), builds it, and the root's `CallOnReady` dispatches the process request. A command defined in beet itself is a tag any `beet` resolves once its plugin registers it (`CliCommandsPlugin`).

A command defined in a downstream crate is a type no beet build can know, so that crate builds its own binary: a thin `main` adding `(BeetPlugins, MyCratePlugin, LaunchPlugin)`, with the same entry resolution and lifecycle (`crates/beet-cli/README.md`, Downstream binaries). Its `main.bsx` declares `<RequireCfg cfg="feature:cli"/>` so the stock `beet` refuses the load rather than running a tree with the commands missing.

## Reference

- `main.bsx`: beet's own command entry
- `crates/beet-cli/README.md`: entries, downstream binaries
- `crates/beet-cli/src/main.rs`: the stock runner
- `crates/beet-cli/src/commands/mod.rs`: `CliCommandsPlugin`, registering every command
- `crates/beet-cli/src/commands/qrcode.rs`: params + `parse_params`
- `crates/beet-cli/src/commands/run_wasm.rs`: greedy route + `to_cli_args`
- `crates/beet_net/src/server/cli_server.rs`: `CliServer`
- `crates/beet_router/src/extra/default_router.rs`: `Router::with_defaults`
