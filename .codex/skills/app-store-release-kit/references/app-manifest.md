# Per-app manifest

`<app-root>/release-kit.yml` stores the small set of durable facts and creative
choices that cannot be rediscovered safely on every run. It is input to the agent;
the deterministic scripts do not require a YAML parser.

Use the scaffold script to create it from `assets/release-kit.yml.tmpl`. Preserve
confirmed values on later runs. Do not replace a non-empty value with a guess.

## Required before a complete package

- `identity.app_name`
- `identity.operator`
- `contact.support_email`
- `contact.production_domain`
- `privacy.effective_date`
- `platforms.iphone` and `platforms.ipad`

Bundle identifiers and versions should normally be extracted from project files and
recorded only when multiple targets make selection ambiguous.

## Screenshot scenes

Each scene describes a real, reproducible app state. `source` is relative to
`artifacts/app-store-previews/preview-spec.json` unless absolute.

```yaml
screenshots:
  locale: en-US
  scenes:
    - id: home
      source: source/01-home.png
      headline: Plan With Clarity
      subheadline: See today's work and what comes next.
    - id: detail
      source: source/02-detail.png
      headline: Keep Every Detail Together
      subheadline: Notes, status, and history in one focused view.
```

Headlines are creative direction, not evidence. Verify them against the app before
using them. A missing source capture is an open item, not permission to synthesize UI.

## Privacy review

Use `privacy.confirmed` only for facts supported by code or the user. Keep uncertain
items under `privacy.open_questions`. Typical review topics include:

- account and authentication;
- local and remote storage;
- analytics, diagnostics, advertising, attribution, and tracking;
- camera, photos, microphone, speech, location, contacts, notifications, and files;
- API hosts, cloud sync, AI services, payments, backups, exports, and sharing;
- retention and user-controlled deletion.
