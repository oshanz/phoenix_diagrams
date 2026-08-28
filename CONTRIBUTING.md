# Contributing to PhoenixDiagrams

## Setup

```sh
mix deps.get
```

`demo/` is a separate Phoenix app for manual testing — not covered by `mix test`.

## Making a change

- Run `mix precommit` before you're done — format, compile with warnings-as-errors, credo --strict, test. Fix everything it flags.
- Add/update tests in `test/`; loader fixtures go in `test/support/fixtures/phoenix_diagrams/`.
- Diagram-definition format lives in `lib/phoenix_diagrams/loader.ex`.
- Markup/styling changes: check them via `cd demo && mix phx.server` (check `ss -tlnp | grep 4000` first; use devtools, not curl — JS hooks won't show).
- JS/CSS changes under `priv/static/phoenix_diagrams/`: run `npm run build:css`/`build:js`, then verify with `node --input-type=module --check < priv/static/phoenix_diagrams/build/bundle.js` before committing. Only `build/app.css` and `build/bundle.js` ship.

## Principles

- No host-asset coupling — styles/hooks ship self-contained.
- Never crash the host page — bad diagrams become inline errors.
- daisyUI for structure, not host theming.
- Aim for WCAG 2.1 AA — check contrast/focus by hand in `demo/`.

See `CLAUDE.md` for architecture notes and gotchas.

## Pull requests

- Keep changes scoped.
- `mix precommit` must pass.
- Explain why, not just what.
