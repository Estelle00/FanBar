# Landing page events

Production uses the existing Umami website on `ana.jarin.me`. Tracking is limited
to `getfanbar.com` and `www.getfanbar.com`; local development does not load the tracker.

| Event | Properties | Meaning |
| --- | --- | --- |
| `download-dmg` | `location`, `locale`, `architecture`, `version` | User clicked a direct DMG link. Architecture is `arm64`, `x86_64`, or `universal`. |
| `view-source` | `location`, `locale` | User opened the GitHub source repository. |
| `view-release-notes` | `location`, `locale` | User opened release history or the latest release notes. |
| `change-language` | `location`, `locale`, `language` | User selected another language; `language` is the destination. |

Locations are `nav`, `hero`, `final-cta`, `footer`, `release-index`, and
`release-note`, where applicable. Version links in the release index also include
`version`; downloads on a version page report that page's version.
Download events measure clicks, not completed downloads or installations. There
is no hardware detection or personal information in event properties.

`DownloadPicker.astro` keeps native links and a native details menu. Analytics
never delays navigation: missing, rejected, or stalled tracking cannot prevent
a download. The main button downloads the Universal DMG; the menu offers all
three packages. URLs come from the latest stable release in the build-time
release snapshot, refreshed before every build.

The shared listener in `Analytics.astro` reads `data-track-*` attributes. Do not
also add `data-umami-event` to these elements, which would report each click twice.
See [Umami custom events](https://docs.umami.is/docs/track-events).

Verify generated links and event metadata with `npm run build && npm run test:landing`.
