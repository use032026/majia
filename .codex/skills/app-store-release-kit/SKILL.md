---
name: app-store-release-kit
description: Generate or refresh one app's App Store screenshots, English listing copy, static product website, and HTML privacy policy from repository evidence. Use for repeatable release-material work in an apps directory; do not use for uploading, publishing, or submitting without an explicit request.
---

# App Store Release Kit

Build a reviewable release-material package for exactly one target app. Treat the
target app's implementation as the source of truth; sibling apps provide layout
examples only.

## Boundaries

- Scope every read and write to the named app plus this skill. Preserve unrelated
  dirty worktree changes.
- Generate and validate by default. Do not deploy the website, upload metadata or
  media, start a signed build, or submit App Review unless the user explicitly asks.
- Do not invent product features, privacy behavior, legal identity, support contact,
  production domains, runtime screenshots, or device evidence.
- App Store screenshots must contain real target-app UI. Generated imagery may be
  used only for decorative backgrounds or non-functional illustration.
- A privacy policy is a product-specific draft, not legal advice. Derive every data,
  permission, storage, account, analytics, advertising, AI, network, backup, export,
  and sharing statement from evidence or an explicit user-provided fact.

## Start

1. Resolve the target app root. Support both `apps/name` and nested roots such as
   `apps/name/name` by locating the relevant `pubspec.yaml`, Xcode project, or app
   source. Stop on ambiguity instead of selecting a sibling.
2. Read [references/app-manifest.md](references/app-manifest.md). If the app has no
   `release-kit.yml`, run:

   ```bash
   python3 .codex/skills/app-store-release-kit/scripts/scaffold_release_kit.py <app-root>
   ```

   Fill inferable values. Ask once for missing material facts that cannot be safely
   inferred, especially operator, support email, production domain, and privacy
   effective date. Save confirmed values so later runs need only the app path.
3. Read [references/output-contract.md](references/output-contract.md). Read
   [references/apple-rules.md](references/apple-rules.md) when producing or validating
   store copy or screenshots, and refresh the linked official Apple rules if current
   limits or required screenshot slots may have changed.

## Evidence pass

Run the facts collector before drafting claims:

```bash
python3 .codex/skills/app-store-release-kit/scripts/collect_app_facts.py \
  <app-root> --output <app-root>/artifacts/release-kit/app-facts.json
```

Then inspect the cited source files. The collector reports signals, not legal
conclusions. Confirm important behavior through code, configuration, permissions,
privacy manifests, dependencies, and user-visible flows. Record unresolved facts in
`artifacts/release-kit/OPEN_ITEMS.md`; do not turn absence of evidence into a claim
such as "no data collection" or "fully offline."

## Generate the package

### English listing

- Write a plain-text English description to
  `artifacts/app-store-listing/description-en.txt`.
- Write comma-separated English keywords to
  `artifacts/app-store-listing/keywords-en.txt`.
- Keep claims repository-backed and user-focused. Avoid unprovable superlatives,
  competitor names, prices, rankings, and promises about future functionality.
- Measure the final description as Unicode characters and keywords as UTF-8 bytes.
  Do not target the exact maximum when natural copy is shorter.

### Website and privacy policy

- Adapt `assets/website/index.html.tmpl`, `privacy.html.tmpl`, and `styles.css` into
  `<app-root>/website/`. Replace every marker and remove inapplicable sections.
- Reuse structure and visual patterns, never another app's product or privacy claims.
- The product page must link to `privacy.html` and expose a real support contact.
- The privacy page must explain actual collection, storage, permissions, network
  services, retention/deletion, exports/sharing, children's handling when relevant,
  changes, and contact details. Phrase conditional OS or third-party processing
  precisely.
- Copy the target app's production icon and approved product images into
  `website/assets/`; do not silently substitute a sibling's branding.

### Store screenshots

1. Reuse existing real runtime captures or capture stable target-app states. If the
   repository lacks a repeatable demo state, seed or navigation contract, report the
   capture gap rather than fabricating UI or data.
2. Choose three to six scenes that cover distinct implemented value. Keep headlines
   short, factual, and readable at thumbnail size.
3. Create `artifacts/app-store-previews/preview-spec.json` from the schema in
   [references/output-contract.md](references/output-contract.md), then run:

   ```bash
   python3 .codex/skills/app-store-release-kit/scripts/render_previews.py \
     --spec <app-root>/artifacts/app-store-previews/preview-spec.json
   ```

4. Inspect the generated contact sheets and full-resolution output. Rendering success
   is not visual approval; check cropping, safe areas, text wrapping, contrast, scene
   order, real-data exposure, and consistency with the current app.

## Validate

Run the deterministic gate and save its report:

```bash
python3 .codex/skills/app-store-release-kit/scripts/validate_release_kit.py \
  <app-root> --report <app-root>/artifacts/release-kit/QA_REPORT.md
```

Resolve all errors. Review warnings instead of deleting them mechanically. Also open
the HTML pages locally and inspect the final screenshots visually. If runtime capture,
public URL reachability, legal review, or device proof was not performed, state that
boundary explicitly.

## Completion report

Report:

- exact target app and files created or changed;
- description character count and keyword UTF-8 byte count;
- screenshot count, device slot, dimensions, color mode, and visual-review status;
- website/privacy checks and any unconfirmed facts;
- what was not done: publishing, App Store Connect mutation, signed build, upload,
  processing, TestFlight, App Review submission, and device verification unless each
  is separately evidenced.
