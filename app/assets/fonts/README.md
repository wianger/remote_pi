# Bundled typography

All TTF files are unmodified upstream static releases under SIL OFL 1.1.
The corresponding copyright and license notices are shipped in the APK and
registered with Flutter's LicenseRegistry. These are open approximations of
the Claude-like typographic hierarchy, not Anthropic's proprietary fonts.

| Role | Family | Upstream |
| --- | --- | --- |
| Interface, input, wordmark | Geist | https://github.com/vercel/geist-font |
| Assistant prose | Source Serif 4 | https://github.com/adobe-fonts/source-serif |
| Code, commands, file paths | Geist Mono | https://github.com/vercel/geist-font |

`sources.json` pins each original URL to its commit and records SHA-256.
No subsetting, conversion or name-table edits were made. Include the matching
OFL notice when redistributing the font files. The interface and Markdown
styles fall back to installed Android sans fonts for CJK and other scripts.
Font size preferences continue to apply. No runtime font download is needed.
