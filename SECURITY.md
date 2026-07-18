# Security Policy

## Reporting a vulnerability

Report privately via [GitHub Security Advisories](https://github.com/whuppi/adaptive_layouts/security/advisories/new). Do not open a public issue.

## What's in scope

- **Gesture or navigation behavior the caller didn't wire** — the layout attaches gestures (swipe-to-dismiss, divider drag) and back-interception only to the panes it owns. Any way to drive those handlers against content or navigation state the caller didn't opt into is a security report.

## What's NOT in scope

- **Content of the panes** — the package renders caller-provided builders verbatim; what they display is the app's concern.
- **Overlay stacking with other packages' overlay entries** — z-order interplay is a compatibility issue, not a vulnerability.

## Response

Valid reports are fixed and shipped as patch versions.
