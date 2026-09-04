# Changelog

## [0.3.0]

### Breaking changes
- Previously shared URLs might not work

### minor changes
- Add search feature for diagrams
- Add readable slugs and version-mismatch notice to diagram share links
- Fix diagram drawer overflow
- Add favicon and logo

## [0.2.7]

- Add optional version option to display in navbar
- Add 404 page for missing diagrams
- Set diagram panel size to full screen
- Extract icons to separate files (vendored from heroicons)
- Add share button to diagram panel

## [0.2.6]

- Add ability to hide and resize the side drawer
- Handle syntax errors in diagram definitions gracefully

## [0.2.2]

- Add CI workflow
- Docs update

## [0.2.0]

- Rename project
- Reset zoom level on expand
- Add pan tool (drag and hold)
- Add zoom feature and support
- Fix dark-mode PlantUML diagram rendering
- Add live-reload support on diagram file changes
- Add C4 diagram support
- Add ability to copy diagram code
- Simplify plugin integration — assets are now served by the library itself and no longer depend on the host app's root layout
