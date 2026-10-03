# Hymn

A simple, native client for TrueNAS SCALE. Point it at your server, paste an
API key, and manage your NAS from your phone or desktop — no browser tabs,
no side server, no config files.

![CI](https://gitlab.com/HttpAnimations/hymn/badges/main/pipeline.svg)

<p>
  <img src="test/goldens/shell.png" alt="Dashboard" width="640">
  <br><br>
  <img src="test/goldens/onboarding.png" alt="Setup" width="215">
  <img src="test/goldens/storage.png" alt="Storage" width="215">
</p>

## What it does

- **Dashboard** — pools, shares, uptime, live CPU/memory/network at a glance
- **Storage** — create pools with guided RAID layouts, datasets from
  templates (media, backups, apps, VMs), quotas, scrubs
- **Shares** — SMB and NFS exports with the options that matter
- **Snapshots** — one-tap snapshots, grouped history, rollback
- **Apps** — installed catalog apps: start, stop, open their UIs
- **Stats** — realtime CPU, memory, network and disk I/O graphs
- **Settings** — services on/off, reboot/shutdown, theme

## Getting started

1. In TrueNAS, open the user menu (top right) → **My API Keys** →
   **Add API Key**, name it `hymn`, copy the key.
2. Open Hymn and enter your server URL (e.g. `https://truenas.local`)
   and the key.
3. Done. Everything is stored on the device; the app talks directly to
   the TrueNAS API.

The web build at `https://hymn-38b0ca.gitlab.io/` is a landing
page — the app itself targets Android, iOS, Linux, Windows and macOS.

## Install

Grab binaries from [Releases](https://gitlab.com/HttpAnimations/hymn/-/releases):

| Platform | Format |
|---|---|
| Android | Signed APK / AAB |
| iOS | Unsigned IPA (add the [AltStore source](https://hymn-38b0ca.gitlab.io/altstore/apps.json)) |
| Linux | tar.gz, deb, rpm, AppImage — x86_64 and arm64 |
| Windows | zip — x86_64 and arm64 |
| macOS | dmg and zip — Apple Silicon |

## Development

```
flutter pub get
flutter test
flutter run -d linux   # or windows / macos / android
```

Commits use Conventional Commits (`feat: …`, `fix: …`); cocogitto drives
versions and the changelog. See `.gitlab-ci.yml` for the
GitLab → GitHub → GitLab release pipeline.

## License

AGPL-3.0 — see [LICENSE](LICENSE).
