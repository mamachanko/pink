# RefPaste operations
- Run `make lint test` before committing; macOS: `make verify`.
- Core is Foundation-only. Platform owns AppKit. App owns UI and ServiceManagement.
- Never log/persist clipboard contents or private hostnames. Use named pasteboards in tests.
- Keep original text exact; baseline on activation. No hooks or destination detection.
- Use Conventional Commits on feature branches. Never merge or publish manually.
- Release only through semantic-release after verification. Never silently downgrade signing.
