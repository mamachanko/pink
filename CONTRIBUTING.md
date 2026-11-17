# Contributing

Use a feature branch and Conventional Commits: `fix:`, `feat:`, `perf:`, `docs:`, `test:`, `chore:`, `ci:`. Breaking changes use `!` or a `BREAKING CHANGE:` footer. Run `make bootstrap lint test`; on macOS run `make verify`. Follow AGENTS.md and scoped instructions. Submit real outcomes and unavailable native checks; don't substitute cross-compilation for execution. Use synthetic public URLs in bug reports and unique named pasteboards in tests. Never change the user's clipboard, permissions or login registration in tests.

Squash PR titles must carry the intended release signal, and breaking details must reach the final commit body. Releases are automated; contributors do not publish or update tracked versions/changelogs. See docs/repository-setup.md for maintainer configuration.

When updating a lint-tool version in `scripts/lint-tools.sh`, refresh its checked-in checksum manifest in `tools/` in the same PR, including macOS and Linux archives for both supported architectures. Obtain checksums from the official release and verify the manifest against its published asset digest where available. `node --test scripts/tool-pins.test.mjs` checks version/manifest consistency even when local tool caches hide a stale pin. Run a fresh `make bootstrap` to verify the downloaded archive against the new pin.
