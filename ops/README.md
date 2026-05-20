# SlapShift release runbook

Three files in this directory:

- `release.sh` — end-to-end: archive → export → DMG → notarize → staple → verify
- `create-dmg.sh` — packages a `.app` into a compressed DMG with `/Applications` symlink
- `exportOptions.plist` — tells `xcodebuild -exportArchive` to use Developer ID signing

## One-time setup (do this once per machine)

### 1. Apple Developer Program

Enroll at https://developer.apple.com/programs/ ($99/yr). Wait for approval — can take
24 hours to a week. Required for Developer ID signing and notarization.

### 2. Developer ID certificate

In Xcode → Settings → Accounts → add your Apple ID → "Manage Certificates" →
`+` → "Developer ID Application". This creates the signing identity used by
`xcodebuild -exportArchive`.

### 3. Set your Team ID in project.yml

Open `app/project.yml`, find `DEVELOPMENT_TEAM` (or add it to `settings.base`),
set it to your 10-character Team ID from
https://developer.apple.com/account → Membership → Team ID.

```yaml
settings:
  base:
    DEVELOPMENT_TEAM: ABC123DEF4
    CODE_SIGN_STYLE: Automatic
```

Then regenerate the .xcodeproj:

```
cd app && xcodegen generate
```

### 4. Notary credentials

Create an app-specific password at https://appleid.apple.com → Sign-In and Security →
App-Specific Passwords → `+`. Name it "slapshift-notary".

Store it in the keychain so `notarytool` can use it non-interactively:

```
xcrun notarytool store-credentials "slapshift-notary" \
    --apple-id <your-apple-id-email> \
    --team-id <your-team-id> \
    --password <app-specific-password>
```

This writes a profile to the system keychain. `release.sh` references it by name
(`slapshift-notary`) — override with `NOTARY_PROFILE=<name> ./release.sh` if you
want a different profile.

## Cutting a release

```
cd /Users/matthewpark/Downloads/current-projects/slapshift
./ops/release.sh 0.1.0
```

(Version is optional — if omitted, reads `MARKETING_VERSION` from `app/project.yml`.)

Output lands in `build/SlapShift-0.1.0.dmg`. Notarization blocks for 2-5 minutes
while Apple's servers scan the binary.

## Verifying a build manually

```
xcrun stapler validate build/SlapShift-0.1.0.dmg
spctl --assess --type install --verbose build/SlapShift-0.1.0.dmg
codesign --verify --deep --strict --verbose=2 build/export/SlapShift.app
```

All three should pass before you publish the DMG.

## Publishing

v1 is manual:

1. Upload the DMG to your CDN of choice (Cloudflare R2, S3, Vercel Blob).
2. Update the download link on the marketing site.
3. Tweet the demo.

When this gets old, the GitHub Actions automation lives in `TODOS.md` under
"Phase B — automate notarization in CI".

## Troubleshooting

**`Developer ID Application: ... not found in keychain`**
The signing identity is missing. Re-do step 2 above (Xcode → Settings → Accounts →
Manage Certificates).

**Notarization fails with `Invalid` status**
Run `xcrun notarytool log <submission-id> --keychain-profile slapshift-notary`.
Common causes: Hardened Runtime disabled, unsigned helper binaries, missing
`com.apple.security.cs.allow-jit` (we don't need JIT — should not see this).

**`hdiutil: create failed`**
Usually means the target DMG already exists and is mounted. Run
`hdiutil detach /Volumes/SlapShift` and try again.

**Build fails with `No account for team`**
`DEVELOPMENT_TEAM` in project.yml doesn't match a team your Apple ID belongs to.
Check https://developer.apple.com/account → Membership for the right Team ID.
