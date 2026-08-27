# Contributing to ExDiag

## Setup

```sh
mix deps.get
```

This repo is the `ex_diag` library itself. `demo/` is a separate, full
Phoenix app (its own `mix.exs`, deps, and Tailwind/esbuild pipeline) used to
manually exercise the library — it isn't run by `mix test`.

## Making a change

- Run `mix precommit` before considering any change complete — it runs
  `format`, `compile --warnings-as-errors`, `credo --strict`, and `test`, in
  that order. Fix everything it flags; don't skip steps.
- Add or update tests under `test/`. Loader fixtures live in
  `test/support/fixtures/ex_diag/` — add a new fixture subdirectory there
  rather than inline `.exs`/`.mmd` files in test bodies.
- If you touch the `.exs` diagram-definition format, that's `lib/ex_diag/loader.ex`.
- If you touch markup/styling, verify in `demo/`:

  ```sh
  cd demo && mix phx.server
  ```

  Check `ss -tlnp | grep 4000` first — a server the user already has running
  will conflict. Since `demo/` uses JS hooks, a plain `curl` only shows
  server-rendered HTML before hooks run; use browser devtools against the
  running server to see actual post-hook DOM/rendering state.
- If you change `priv/static/ex_diag/` JS or CSS sources, rebuild the
  compiled output before committing:

  ```sh
  cd priv/static/ex_diag
  npm run build:css   # after editing input.css or DiagramLive's markup
  npm run build:js    # after editing mermaid_hook.js/plantuml_hook.js/download_hook.js
  ```

  Verify the rebuilt bundle parses before committing — `esbuild --minify`
  (full identifier renaming) corrupts `@plantuml/core`'s TeaVM output, so
  `build:js` deliberately uses `--minify-whitespace` only:

  ```sh
  node --input-type=module --check < priv/static/ex_diag/build/bundle.js
  ```

  Only `priv/static/ex_diag/build/app.css` and
  `priv/static/ex_diag/build/bundle.js` are packaged/served at runtime — the
  npm project itself (`node_modules`, `package-lock.json`) is dev-only and
  gitignored.

## Design principles to keep in mind

- **Zero host-asset coupling.** A host app must never need to edit its own
  `app.css`/`app.js` or add an npm dependency to use ExDiag. Styles are
  compiled here and inlined at render time; JS hooks are vendored and
  pre-bundled here.
- **Never crash the host page.** Malformed diagram definitions become inline
  error entries, not exceptions.
- **daisyUI for structure, not host theming.** Use daisyUI component classes;
  the library ships its own light/dark themes.
- **Target WCAG 2.1 AA.** Carry proper ARIA attributes and verify contrast
  and focus visibility manually in `demo/` — these aren't checkable from
  markup alone.

See `CLAUDE.md` for full architecture notes and known gotchas before
changing rendering, asset-serving, or LiveView-hook behavior — several of
those gotchas cost real debugging time to discover the first time around.

## Pull requests

- Keep changes scoped; don't mix unrelated refactors into a bugfix.
- Make sure `mix precommit` passes before opening a PR.
- Describe *why* the change is needed, not just what changed.
