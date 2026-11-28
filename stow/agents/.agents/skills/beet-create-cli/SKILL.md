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
- A `CliServer` is strict by requirement: a flag nothing on the dispatched route's path takes is refused rather than ignored, see section 5.
- Each command tag is one command. Its `#[action(route = "...")]` attribute requires the path and dispatch components, so the tag alone is a self-describing route: `beet qrcode` hits the `qrcode` route.
- From Rust, `Router::with_defaults()` is the batteries-included bundle: `Router` plus `RequestLogger`, `HelpHandler`, `NavigateHandler` and the default app routes.

## 2. A command

A command is an `#[action(route = "...")]` async fn returning `Result<String>`, the string being the response body, with its flags taken in its signature (section 3). Derive `Reflect` + `#[reflect(Component)]` and register the type in the crate's plugin (`app.register_type::<QrCode>()`, see `CliCommandsPlugin`) so an entry resolves it by tag.

```rust
#[action(route = "qrcode")]
#[derive(Component, Reflect)]
#[reflect(Component)]
pub async fn QrCode(
	/// The text/url to encode.
	#[param]
	input: String,
	/// The output file path, defaults to `qrcode.png`.
	#[param]
	output: Option<String>,
) -> Result<String> {
	let output = output.as_deref().unwrap_or("qrcode.png");
	// ..
	Ok(format!("wrote qr code to {output}"))
}
```

An action taking params returns `Result`, so a bad param is the caller's `400` (exit `64`). It reads them off its request: one naming no input of its own takes the `RequestParts`, and a command needing the world, the path or a richer response takes `cx: ActionContext<RequestParts>` (or `Request`) and returns `Result<Response>` (see `Check`).

## 3. Params: declare by taking

An extractor declares a param by taking it: one argument is both the `--help` entry and the typed read, parsed off the request before the body runs. Never pull values out one by one with `parts.get_param("..")`, which skips validation and is invisible to `--help` and to the strict refusal.

- `#[param] name: T` takes one flag. Its doc comment is the description and `#[param(short = 'm')]` adds `-m`; the macro collects the inline params into a hidden `{Action}Params` struct. This is the default, however many flags a command takes.
- `name: Params<T>` takes a whole `Reflect` group, read through `Deref`. A named group exists only when more than one extractor takes it (`EntryParams`, shared by `check`, `export-static` and `export-pdf`), or when its extractor is hand written and declares through a type.
- `any: AnyParams` takes every param the request carries, so a strict server refuses nothing on that route (section 5).

Both kinds may sit in one action, as in `Check`:

```rust
#[action(route = "check/*entry")]
#[derive(Component, Reflect)]
#[reflect(Component)]
pub async fn Check(
	/// Also write a JSON diagnostics manifest to this path, or `-` for stdout.
	#[param]
	manifest: Option<String>,
	entry_params: Params<EntryParams>,
	cx: ActionContext<RequestParts>,
) -> Result<Response> {
	// ..
}
```

A group is a plain `Reflect` struct whose doc comments are the flag descriptions:

```rust
/// The package store selector every entry-loading command shares.
#[derive(Reflect)]
pub(crate) struct EntryParams {
	/// The package store the entry argument loads through, eg
	/// `--entry-package=s3://my-bucket`.
	entry_package: Option<StoreUri>,
}
```

Rules for a param's type, the same for a `#[param]` and a field of a `Params<T>` group:

- The flag is the kebab-case name, ie `out_dir` ↔ `--out-dir`, and the snake_case spelling matches too.
- `bool` → a flag (`--release`), `false` when absent. `Option<T>` → optional, `None` when absent. `Vec<T>` → repeatable (`--tag=a --tag=b`), empty when absent. Anything else is required: a missing one answers `400` naming the flag, and `--help` lists it as required.
- A default that is not "absent" is the handler's: take `width: Option<u32>` and read `width.unwrap_or(1280)`. A bare `width: u32` makes the flag required.
- A value parses through its type's `LiteralParser`, the same table markup attributes use, so a param is typed as what it is: `store: Option<StoreUri>`, `timeout: Duration`, `created: Timestamp`, a unit enum named by its variant, a numeric primitive, `String`/`SmolStr`.
- A nested struct with no authored form flattens into its parent's flags, declared and parsed alike.
- A group needs no `Default` or `#[reflect(Default)]`, the read supplies every field.
- No param takes a launch only knob's name (`--entry`, `--package`, `--required-features`, `--stage`, ..): the launch strips those from the request before the `CliServer` sees it, so the route tree refuses to build. The entry commands take `--entry-package` for this reason.
- A markup-authored preset that flags override field by field is declared by hook and read with `apply_params`, which touches only the flags present: `#[component(on_add = RouteParams::declare::<Self, BuildWasm>)]`, then `cx.input.apply_params(&mut preset)?` (see `BuildWasmAction`).

## 4. `--help` is free

`HelpHandler` intercepts `--help`, walks the [`RouteTree`] and renders each route with the params it takes, the same set the strict refusal reads, so the help lists exactly what is accepted. Doc comments on the params become the flag descriptions, so document them. `beet --help` lists everything; `beet qrcode --help` scopes to that subtree. Each route lists its own params beneath it; the middleware and server params at or above the router are listed once under "Inherited params", grouped by extractor; the root help adds "Launch" (the launch only knobs) and "Before the build" (the prescans).

## 5. Unknown flags are refused

Every `CliServer` is strict by requirement: a request carrying a flag nothing on its route's path takes answers `400` (exit `64`) naming it and the closest one taken, so `deploy --elevate` asks `did you mean --elevated?` instead of running a plain deploy, and a misspelt command (`serv`) asks `did you mean serve?`. A nested `Router` is its own url space and is not governed, so a site a CLI serves over http still accepts `?utm_source`.

What a route takes is the union over everything that runs for it: its own action, its steps (the non-route children an `ExchangeSequence` runs, and the members of a group a `RunGroup` runs), and the middleware and servers on it and every ancestor. So a middleware reading a param takes it the same way; the macro infers subtree scope from the `Next` in its input, and the param reaches every route beneath it:

```rust
#[action]
#[derive(Default, Clone, Component, Reflect)]
#[reflect(Component)]
#[component(on_add = MiddlewareList::<Request, Response>::on_add::<Self>)]
pub async fn VerboseLogger(
	/// Log the path of every request beneath this router.
	#[param]
	verbose: bool,
	cx: ActionContext<(Request, Next<Request, Response>)>,
) -> Result<Response> {
	let (request, next) = cx.take();
	if verbose {
		info!("{:?}", request.path());
	}
	next.call(request).await
}
```

A hand written extractor that is not an `#[action]` (a server, a `Layout`) declares from the plugin registering it, `app.install(SubtreeParams::declare_on::<MyServer, MyParams>())` (see `ServerPlugin`), or with a `SubtreeParams::declare::<Self, MyParams>` `on_add` hook.

Never allow-list a flag by name. A command handing the params it does not name to a program it runs takes `any: AnyParams` and forwards `any.undeclared(&pattern)` (see `RunWasm`), and a command line rebuilt from a request keeps only `pattern.recognised(..)`, never a typo the request carried (see `DeployGate`), the pattern being the route's own: `cx.caller.with_state::<ParamsQuery, _>(|entity, query| query.of(entity))`. The full rule: `crates/beet_router/README.md`, Params.

## 6. Greedy routes and forwarding args

A trailing `*name` segment captures the rest of the args greedily, eg the `run-wasm/*run-wasm-args` cargo runner. To rebuild a forwardable arg vector from the request use [`RequestParts::to_cli_args`], whose [`CliArgs`] holds every path segment in `path` and the flags in `params`; mutate it, then [`CliArgs::into_args`] for the argv:

```rust
// `[run-wasm, <binary>, ..forwarded]`: drop the command segment consumed by
// the route, then forward the rest
let mut cli = parts.to_cli_args();
cli.path.remove(0);
let args = cli.into_args();
```

## 7. Output and content negotiation

The body is rendered per the `--accept` header (default: ansi-term, then text, markdown, json). A plain `Ok(String)` prints as text; a scene route (eg `render_action::async_route`) renders through the beet_ui pipeline, so `--accept=text/html` yields HTML and the default yields styled terminal output. Rendering requires `RouterPlugin`, part of `BeetPlugins` under the `router` feature.

## 8. Shipping the CLI

The `beet` binary links capabilities but ships no commands: on startup it discovers `main.bsx` by walking the cwd's ancestors (`--entry=<path>` overrides), builds it, and the root's `CallOnReady` dispatches the process request. A command defined in beet itself is a tag any `beet` resolves once its plugin registers it (`CliCommandsPlugin`).

A command defined in a downstream crate is a type no beet build can know, so that crate builds its own binary: a thin `main` adding `(BeetPlugins, MyCratePlugin, LaunchPlugin)`, with the same entry resolution and lifecycle (`crates/beet-cli/README.md`, Downstream binaries). Its `main.bsx` declares `<RequireCfg cfg="feature:cli"/>` so the stock `beet` refuses the load rather than running a tree with the commands missing.

## Reference

- `main.bsx`: beet's own command entry
- `crates/beet-cli/README.md`: entries, downstream binaries
- `crates/beet-cli/src/main.rs`: the stock runner
- `crates/beet-cli/src/commands/mod.rs`: `CliCommandsPlugin`, registering every command
- `crates/beet-cli/src/commands/qrcode.rs`: a command taking inline `#[param]`s
- `crates/beet-cli/src/commands/check.rs`: an inline `#[param]` beside the shared `Params<EntryParams>`
- `crates/beet-cli/src/commands/run_wasm.rs`: greedy route, `AnyParams` + `to_cli_args`
- `crates/beet_router/src/router/site/help.rs`: `HelpHandler`, middleware taking `#[param] help`
- `crates/beet_net/src/types/route_params.rs`: `Params<T>`, `AnyParams`, the two scopes, `SubtreeParams::declare_on`
- `crates/beet_net/src/server/cli_server.rs`: `CliServer`; `server_plugin.rs` declares what each server reads
- `crates/beet_net/src/server/reject_unknown_params.rs`: the `RejectUnknownParams` marker every `CliServer` requires
- `crates/beet_router/src/router/policy/reject_unknown_params.rs`: the router side refusal and the misspelt route
- `crates/beet_router/src/router/model/params_query.rs`: `ParamsQuery`, the one collector of a route's params
- `crates/beet_infra/src/wasm/build_wasm.rs`: a markup preset declared by hook and read with `apply_params`
- `crates/beet_router/src/extra/default_router.rs`: `Router::with_defaults`
