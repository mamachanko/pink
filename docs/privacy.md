# Privacy

Pink operates locally without network requests. Explicit About buttons may open repository/release pages in the browser. No clipboard bytes, URLs, labels, private hosts, credentials, hashes or snapshots are logged/persisted. Diagnostics contain fixed categories and state transitions only. Settings necessarily store configured hostnames locally in UserDefaults. No analytics/crash-upload service.

Reads are limited to one eligible item with known types after consent. Unknown types and community sensitive/transient/generated/remote markers prevent data reads. Missing markers do not establish that data is safe. Existing HTML is skipped without importing it, preventing resource fetching. No destination app inspection or keyboard hook.

Prose formatting processes at most 8 KiB of text per item. Unsupported URLs remain unchanged. A single item may contain multiple supported links, but all original prose remains the plain representation. Matching and RTF generation stay local; existing named links, HTML and attachment-bearing RTF remain ineligible.

One original snapshot (<=64 KiB) exists in memory only while restoration may be safe. External change, pause and exit invalidate ownership. A restore cannot retract text already pasted. Memory isn't cryptographically erased. OS clipboard and other clipboard tools remain outside Pink's control.

No Accessibility, Input Monitoring or Screen Recording permissions are needed. Clipboard policy is preflighted on macOS 15.4+; Ask/Deny requires user settings action. Do not repeatedly retry reads after failure. Earlier systems may not expose denial as a distinct category; failed reads show Error. Platform behavior remains NOT RUN until tested on macOS.
