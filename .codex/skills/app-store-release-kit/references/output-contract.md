# Output contract

Use these paths unless the target app already has an equivalent established layout.
Do not create duplicate copies only to satisfy naming.

```text
<app-root>/
├── release-kit.yml
├── website/
│   ├── index.html
│   ├── privacy.html
│   ├── styles.css
│   └── assets/
├── app-store/
│   └── metadata.yml                 optional upload manifest; disabled by default
└── artifacts/
    ├── release-kit/
    │   ├── app-facts.json
    │   ├── OPEN_ITEMS.md             only when facts remain unresolved
    │   └── QA_REPORT.md
    ├── app-store-listing/
    │   ├── description-en.txt
    │   └── keywords-en.txt
    └── app-store-previews/
        ├── preview-spec.json
        ├── source/                   real target-app runtime captures
        ├── final/                    RGB JPEG or PNG submission images
        └── qa/                       contact sheets
```

## Preview specification

`render_previews.py` accepts JSON so rendering remains dependency-free apart from
Pillow. Paths are relative to the JSON file.

```json
{
  "schema_version": 1,
  "app_name": "Example App",
  "font_path": "/absolute/path/to/a/font.ttf",
  "defaults": {
    "background_top": "#0B6B63",
    "background_bottom": "#17312E",
    "text_color": "#FFFFFF",
    "muted_text_color": "#DCE9E6"
  },
  "items": [
    {
      "source": "source/01-home.png",
      "output": "final/iphone/01-home.png",
      "size": [1206, 2622],
      "headline": "Plan With Clarity",
      "subheadline": "See today's work and what comes next.",
      "icon": "../../assets/branding/app-icon.png"
    },
    {
      "source": "source/ipad-01-home.png",
      "output": "final/ipad/01-home.png",
      "size": [2752, 2064],
      "headline": "Everything In View",
      "subheadline": "A spacious workspace for the whole plan."
    }
  ]
}
```

Supported item overrides: `background_top`, `background_bottom`, `text_color`,
`muted_text_color`, `font_path`, `icon`, `app_name`, `headline`, `subheadline`,
`source`, `output`, and `size`.

## Definition of done

- All material facts are confirmed or listed as open.
- Description and keywords pass the deterministic limits.
- Website and privacy pages contain no template markers and include working local
  navigation plus real contact information.
- Every final store image uses a real UI capture, has a current accepted dimension,
  contains no alpha channel, and has passed visual inspection.
- `QA_REPORT.md` contains no errors.
- The final report distinguishes generated/static validation from runtime capture,
  public hosting, upload, processing, TestFlight, submission, review, and device proof.
