# Contributing to PhoenixDiagrams

## Setup

```sh
mix deps.get
```

`demo/` is a separate Phoenix app for manual testing — not covered by `mix test`.

## Making a change

- Run `mix precommit` before you're done.
- JS/CSS changes under `priv/static/phoenix_diagrams/`: run `npm run build:css`/`build:js`, then verify with `node --input-type=module --check < priv/static/phoenix_diagrams/build/bundle.js` before committing. Only `build/app.css` and `build/bundle.js` ship.

## Principles

- No host-asset coupling — styles/hooks ship self-contained.

See `CLAUDE.md` for architecture notes and gotchas.

## Pull requests

- Keep changes scoped and small — merge requests under ~400 lines are highly appreciated.
