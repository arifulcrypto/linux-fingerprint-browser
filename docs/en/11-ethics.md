# 11 — Ethics and Acceptable Use

Fingerprint isolation is dual-use. The same technology that protects a journalist from
cross-site correlation can be used to run fraudulent accounts. This project takes a clear
position.

---

## Intended uses

- **Privacy:** reduce cross-site and cross-profile linkability for legitimate users.
- **Multi-account operations where the platform permits them:** agency, e-commerce, ad
  operations, support desks, and QA.
- **Ad verification and market research:** see what a real user in a region sees.
- **Security research:** study fingerprinting, leak paths, and detection.
- **Testing:** reproduce regional bugs, layouts, and payment flows.
- **Automation:** run repetitive browser tasks with a coherent, auditable environment.

## Prohibited uses

- Fraud, scams, payment abuse, or money laundering.
- Evading lawful sanctions, law enforcement, or court orders.
- Bypassing platform bans or terms of service in ways that harm the platform or its users.
- Credential stuffing, account takeover, scraping behind authentication, or spam.
- Impersonating a real person or organisation to deceive.
- Circumventing age, identity, or eligibility checks.
- Distributing malware or coordinating abuse.

## Legal and platform compliance

- Fingerprint isolation is not itself illegal in most jurisdictions, but its application
  may be regulated (privacy, computer misuse, consumer protection, sanctions, export
  control).
- Platform terms of service may prohibit multi-accounting or automation. The operator is
  responsible for reading and following them.
- Proxy providers have acceptable-use policies. Residential proxies may prohibit fraud,
  spam, and certain high-risk categories.
- Data protection laws (GDPR, CCPA, and equivalents) apply to profile data, logs, and
  screenshots. Collect the minimum, retain it for a defined period, and support deletion.

## Privacy of third parties

A fingerprint profile is not a licence to collect personal data. Do not:

- scrape personal data at scale without a lawful basis;
- store passwords, payment data, or identity documents from a profile;
- publish screenshots that reveal another person's account or data;
- use another person's likeness or identity in a persona.

## Security and disclosure

- Report vulnerabilities in this project privately (see `SECURITY.md`).
- Do not publish exploits or credentials found in a live environment.
- If you discover a leak in a deployed profile, disable it, notify the operator, and
  document the fix.

## Enforcement

Contributors and operators are expected to follow this policy. The maintainers may
remove contributions, revoke access, or report abuse when there is credible evidence of
harm. This policy is not legal advice; consult counsel for your jurisdiction and use case.

## A note on "undetectable"

No browser is undetectable. This project aims for **coherence, isolation, and
measurement**, not a guarantee of bypassing any particular platform. Claims of
undetectability are marketing, not engineering.
