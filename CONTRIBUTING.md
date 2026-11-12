# Contributing

## Language policy

- English is the primary language. Every document must exist in `docs/en/` first.
- Chinese translations live in `docs/zh-CN/` with the same file names.
- Code comments, commit messages, and configuration examples are English.
- When a fact changes, update the English source and the Chinese translation in the
  same pull request, or mark the translation as stale.

## Evidence policy

Every non-obvious claim should point to a file under `inventory/` or to a command that
can be re-run. Prefer measured values over estimates. If a value is inferred, label it
as inferred.

## Redaction policy

Never commit:

- real credentials, tokens, UUIDs, private keys, or session IDs;
- real public IP addresses;
- cookies, local storage, or browsing history from a profile;
- screenshots that reveal account identifiers.

Use `REDACTED`, `203.0.113.10`, `198.51.100.x`, and `2001:db8::` placeholders.

Run the guard before committing:

```bash
./scripts/check-redaction.sh
```

## Documentation style

- One topic per file; keep tables narrow enough to read on GitHub.
- Use fenced code blocks with a language tag.
- Use Mermaid for diagrams; GitHub renders it natively.
- Date-stamp environment snapshots. A fingerprint inventory is only valid for the
  software versions it was captured from.
- Do not present a browser version as permanent; Chrome updates roughly every four weeks.

## Commit style

Conventional commits are preferred:

```text
docs: add proxy latency benchmark
feat(inventory): capture headful WebGL state
fix(scripts): redact hysteria obfs key
```
