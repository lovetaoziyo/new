# RustDesk Custom Windows Client Build Package

> **Target environment baked into this build:**
> - Server: `fxing.pathea.com` (rendezvous on default 21116)
> - API port: `21114` (auto-derived as `RENDEZVOUS_PORT - 2`)
> - Public key: `PqZllQRVMfX9tdfaQA+dfoXvBOkhuzPc30T0SijU2D0=`
> - RustDesk version: 1.4.9 (commit `f07b6e2338b03ef24e88d5063747da616c2c9f1c`)

> **TL;DR:** Push this directory to a GitHub repo, click "Run workflow", wait 30-60 min, download the .exe. See "Quick Start" below.

---

## Quick Start (GitHub Actions — no local toolchain needed)

1. **Create a new private GitHub repo** at https://github.com/new (name e.g. `rustdesk-custom`).
2. **Push this whole `rustdesk-build-package/` directory** to it:
   ```powershell
   cd "E:\path\to\rustdesk-build-package"
   git init
   git add .
   git commit -m "Custom RustDesk build"
   git remote add origin https://github.com/<your-username>/rustdesk-custom.git
   git branch -M main
   git push -u origin main
   ```
   First push asks for a Personal Access Token (not your password) — generate one at https://github.com/settings/tokens/new with `repo` scope.
3. **Open** `https://github.com/<your-username>/rustdesk-custom` → click **Actions** tab → click **"Build Custom RustDesk for Windows"** on the left → click **"Run workflow"** → green **Run workflow** button.
4. **Wait 30-60 minutes.** First run is slow; later runs use cache.
5. **Download** the artifact at the bottom of the completed run: `rustdesk-windows-installer.zip` → unzip → use `rustdesk_portable.exe` (or `rustdesk-1.4.9-install.exe` for the installer).
6. **Done.** No Visual Studio, no vcpkg, no Flutter SDK on your machine. GitHub's runner does everything.

---

## File layout

```
rustdesk-build-package/
├── README.md                          # this file
├── .github/workflows/
│   └── build-windows.yml              # GitHub Actions workflow
├── scripts/
│   └── build-windows.ps1              # OPTIONAL: build locally on Windows
└── rustdesk/                          # full RustDesk 1.4.9 source, server/key pre-configured
    ├── Cargo.toml
    ├── libs/hbb_common/src/config.rs  # RENDEZVOUS_SERVERS, RS_PUB_KEY edited here
    └── ...
```

---

## What was changed in the source

`rustdesk/libs/hbb_common/src/config.rs` (lines 117-123):
```rust
pub const RENDEZVOUS_SERVERS: &[&str] = &["fxing.pathea.com"];
pub const RS_PUB_KEY: &str = "PqZllQRVMfX9tdfaQA+dfoXvBOkhuzPc30T0SijU2D0=";

// Ports left at RustDesk defaults:
// 21116 = rendezvous (hbbs ID/heartbeat)  ← your client connects here
// 21117 = relay (hbbr)
// 21118 = ws rendezvous (web client)
// 21119 = ws relay
```

The API address `http://fxing.pathea.com:21114` is auto-derived by RustDesk's `get_api_server_` as `RENDEZVOUS_PORT - 2` (= 21116 - 2 = 21114), matching what you specified.

**Double-check your server** — `hbbs` must be listening on **21116** (TCP+UDP). If your hbbs is on a different port, edit `RENDEZVOUS_PORT` in `config.rs` and re-push/re-run the workflow.

| Service | Protocol | Port | Required |
|---------|----------|------|----------|
| hbbs | TCP+UDP | **21116** | yes |
| hbbr | TCP | 21117 | optional (relay) |
| hbbs | TCP | 21114 | API/Pro web console |

---

## Optional: Build locally on Windows

If you ever want to build without GitHub Actions, you need: VS 2022 Build Tools (with C++ workload + Win 11 SDK), Git, Python 3.11+, Rust 1.75, LLVM 15.0.6, Flutter 3.24.5. Total ~50GB disk. The `scripts/build-windows.ps1` walks you through it.

For most people, **just use GitHub Actions** — it's free (2,000 min/month for private repos), zero local setup, and the script is 5 lines.

---

## Troubleshooting

**Action fails at "Install vcpkg and dependencies"** — sometimes the GHA vcpkg cache is cold and a network blip fails the build. Just re-run the workflow.

**Action fails at "Build RustDesk" with linker errors** — usually means vcpkg didn't finish installing all 4 libs (libvpx, libyuv, opus, aom). Re-run.

**Client starts but says "key mismatch" or won't connect** — verify your `hbbs` server's printed public key matches the one in `config.rs`. Run `hbbs` once and look at the line `Public Key: ...`.

**Want to change server/key later** — edit `rustdesk/libs/hbb_common/src/config.rs`, `git add . && git commit -m "update" && git push`, then re-run the workflow.

---

## What's in the .exe

When you launch the compiled `rustdesk.exe`:
- Default ID/relay server = `fxing.pathea.com` (no manual config needed)
- Default key = your key
- API calls go to `http://fxing.pathea.com:21114`

The client behaves exactly like the official RustDesk client, just hardcoded to talk to your server.
