# Chrome profiles — sanitised summary

Captured 2026-11-12 from `c4-desktop`. Profile directories are under `/root/.config/`.
No cookies, history, passwords, or local storage are included.

## Profile inventory

| Directory | Size | Purpose | Proxy | `variations_country` | Extensions | Mode |
|---|---:|---|---|---|---:|---|
| `google-chrome` | 177 MB | default / ad-hoc | none | `jp` | 5 | `0700` |
| `chrome-residential` | 20 MB | PH rotating residential | `127.0.0.1:18080` | `ph` | 5 | `0755` |
| `chrome-tr-proxy` | 175 MB | TR 24h sticky residential | `127.0.0.1:18081` | `tr` | 6 | `0755` |
| `chrome-us-proxy` | 313 MB | US VLESS line | `127.0.0.1:2080` | `cn` | 6 | `0755` |
| `google-chrome-headless` | 4 KB | headless probe only | none | absent | 0 | `0700` |

## Preferences

| Key | Value |
|---|---|
| `profile.name` | `Your Chrome` (all profiles) |
| `profile.avatar_index` | `26` |
| `profile.exit_type` | `Normal` |
| `intl.accept_languages` | absent (system fallback) |
| `signin.allowed` | `true` |
| `sync.requested` | absent |
| `download.default_directory` | absent |
| `media.autoplay_policy` | absent |
| `hardware_acceleration_mode` | absent (default enabled, GPU is software) |

## Local State

Sanitised excerpts:

```json
// chrome-tr-proxy
{
  "variations_country": "tr",
  "variations_permanent_consistency_country": ["156.0.8078.79", "tr"]
}
```

```json
// chrome-us-proxy
{
  "variations_country": "cn",
  "variations_permanent_consistency_country": ["156.0.8078.79", "cn"]
}
```

The country is derived from where the variations seed was fetched. It is not exposed to
JavaScript, but it persists across profile copies and affects feature rollout.

## Extensions

All are component or external-component extensions; there are no third-party installs.

| Extension | Version | Profiles |
|---|---|---|
| Chrome PDF Viewer | 1 | all |
| Chrome Web Store Payments | 1.0.0.6 | all |
| Google Docs Offline | 1.111.1 | all |
| Google Hangouts | 1.3.26 / 1.4.5 | all |
| Google Network Speech | 1.0 | all |
| Gemini in Chrome | 1.2 | TR, US |

## Notes

- `google-chrome` and `google-chrome-headless` are mode `0700`; the three `chrome-*`
  profiles are `0755`, readable by any local user.
- Crashpad writes to `/root/.config/google-chrome/Crash Reports` for all profiles.
- All profiles share the same display, fonts, timezone, locale, and Chrome binary.
- Profile size includes cache and service-worker storage; it is not a measure of account
  activity.

Raw parsed summary: [`06b-chrome-profile-summary.json`](06b-chrome-profile-summary.json).
