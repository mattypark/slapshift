# SlapShift — Next Steps (do these in order)

This is the path from "code works, tests pass" to "signed DMG you can post on Twitter."
Four phases. Don't skip ahead — each phase blocks the next.

1. [Phase 1 — Get the Developer ID cert from HMU, INC.'s Account Holder](#phase-1--developer-id-cert-option-b)
2. [Phase 2 — Export your three `.shortcut` files](#phase-2--export-your-three-shortcut-files)
3. [Phase 3 — Run the app locally and walk through onboarding](#phase-3--run-the-app-and-walk-through-onboarding)
4. [Phase 4 — Cut the signed, notarized release DMG](#phase-4--cut-the-signed-notarized-release-dmg)

---

## Phase 1 — Developer ID cert (Option B)

You can't create a Developer ID Application certificate yourself because you're not the
HMU, INC. Account Holder on the Apple Developer Program. So the Account Holder creates
it for you, and you import it. There are two ways. **B1 is more secure** (private key
never leaves your Mac). B2 is simpler but exposes the key. Pick one.

### Option B1 — CSR exchange (recommended)

The flow: **you** make a Certificate Signing Request, send the CSR file to the Account
Holder, they upload it on developer.apple.com, Apple gives them a `.cer` file back,
they send that to you, you install it. The private key stays on your Mac the whole time.

#### B1, your steps (part 1 — generate the CSR)

1. Open **Keychain Access** (Cmd+Space → "Keychain Access").
2. Menu bar: **Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority...**
   - ⚠️ NOT "Create a Certificate" and NOT "Create a Certificate Authority". The exact
     menu item is "Request a Certificate from a Certificate Authority..."
3. Fill in:
   - **User Email Address:** your Apple ID email
   - **Common Name:** your full name (e.g., "Matthew Park")
   - **CA Email Address:** leave blank
   - **Request is:** select **Saved to disk**
   - Check **Let me specify key pair information**
4. Click **Continue**. Save the file as `SlapShift.certSigningRequest` somewhere you'll find it (Desktop is fine).
5. Next screen: **Key Size: 2048 bits**, **Algorithm: RSA**. Click **Continue**.
6. Done. You now have `SlapShift.certSigningRequest` on disk. **Do not delete it** until
   the next steps are done — and more importantly, **do not lose your keychain**, because
   the matching private key was just stored there.

#### B1, Account Holder's steps

Send the Account Holder these instructions verbatim (along with the `.certSigningRequest` file):

> Hey — I need a Developer ID Application certificate generated under HMU, INC. for
> distribution. I've attached my CSR (Certificate Signing Request). Please:
>
> 1. Go to https://developer.apple.com/account → **Certificates, Identifiers & Profiles**
> 2. Click the **+** button to create a new certificate
> 3. Under **Software**, select **Developer ID Application** (NOT "Apple Development" or "Apple Distribution")
> 4. Click **Continue**
> 5. Upload the `.certSigningRequest` file I attached
> 6. Click **Continue** → **Download**
> 7. Send me back the `.cer` file that downloads (it'll be named something like `developerID_application.cer`)
>
> The CSR file contains only the public key, not the private key, so it's safe to share.
> Total time: about 2 minutes on your end.

#### B1, your steps (part 2 — install the .cer)

When the Account Holder sends you back the `.cer` file:

1. **Double-click the `.cer` file**. Keychain Access will open and ask which keychain to
   add it to. Choose **login**. Click **Add**.
2. Open Keychain Access → **login** keychain → **My Certificates** category.
3. You should now see **Developer ID Application: HMU, INC. (TEAMID)**. Expand it with
   the disclosure triangle — there should be a private key underneath. **If there's no
   private key, the CSR-to-cert match failed.** Redo step 1 (sometimes Keychain Access
   installs the cert in the wrong keychain).
4. Verify from Terminal:
   ```
   security find-identity -v -p codesigning
   ```
   You should see a line ending in `"Developer ID Application: HMU, INC. (TEAMID)"`.
5. Note the **TEAMID** (the 10-character code in parens) — you'll need it in Phase 4.

### Option B2 — `.p12` export (simpler but less secure)

The Account Holder generates the cert on their own Mac and exports the cert + private
key together as a `.p12` file with a password. They send you the `.p12` and the password
through separate channels. You import it. **Downside:** the Account Holder has a copy of
your signing key. **Upside:** zero work for you on the CSR side.

#### B2, Account Holder's steps

Send the Account Holder these instructions:

> Hey — I need to import a Developer ID Application certificate from you under HMU, INC.
> for code-signing. The fastest way is to export your existing one (or create a new one
> on your Mac) and send me the `.p12`. Please:
>
> 1. On your Mac, open **Keychain Access**
> 2. If you already have a "Developer ID Application: HMU, INC." cert under **My Certificates**,
>    skip to step 5. Otherwise, create one:
> 3. Keychain Access menu → **Certificate Assistant → Request a Certificate from a Certificate Authority** →
>    fill in your details, "Saved to disk", continue, save the CSR file
> 4. Go to https://developer.apple.com/account → Certificates → + → **Developer ID Application** →
>    upload the CSR → download the `.cer` → double-click to install
> 5. In Keychain Access → My Certificates → right-click **Developer ID Application: HMU, INC.** → **Export...**
> 6. Save as `slapshift-cert.p12`. When prompted, **set a strong password** — write it down separately.
> 7. Send me `slapshift-cert.p12` over a secure channel (1Password share, Signal, encrypted email)
>    and send me the **password in a different channel** (e.g., text message). Do not put
>    them in the same email.
>
> The `.p12` contains a private key, so treat the file like a password.

#### B2, your steps

When you have the `.p12` and the password:

1. Double-click the `.p12` file. Keychain Access opens and prompts for the password.
2. Enter the password. Choose **login** keychain. Click **OK**.
3. Verify from Terminal:
   ```
   security find-identity -v -p codesigning
   ```
   You should see `"Developer ID Application: HMU, INC. (TEAMID)"`.
4. Note the **TEAMID** — you'll need it in Phase 4.
5. **Delete the `.p12` file** from Downloads after import (it's already in your keychain). Empty trash.

---

## Phase 2 — Export your three `.shortcut` files

The app expects three Focus-helper shortcuts to live in `app/SlapShift/Resources/DefaultShortcuts/`.
You create them once in Shortcuts.app, export each as a `.shortcut` file, drop them in
that directory, and the build pipeline bundles them into `SlapShift.app/Contents/Resources/`.

### Create the shortcuts

Open **Shortcuts.app** on your Mac. For each of these three, create a new shortcut:

| Name (exactly as written)                  | Single action            | Action settings                |
|--------------------------------------------|--------------------------|--------------------------------|
| `SlapShift: Set Focus to Do Not Disturb`   | Set Focus                | Turn **Do Not Disturb** **On** |
| `SlapShift: Set Focus to Personal`         | Set Focus                | Turn **Personal** **On**       |
| `SlapShift: Set Focus to Sleep`            | Set Focus                | Turn **Sleep** **On**          |

The name must match exactly — `ShortcutCatalog.swift` filters on the
`SlapShift: Set Focus to ` prefix, and `ActionExecutor.swift` runs them by that exact name.

To create one:
1. Shortcuts.app → **+** (top right) → blank shortcut
2. Search the action library (right panel) for **"Set Focus"** → drag it in
3. Click the **focus name** in the action (e.g., "Do Not Disturb") and set the right one
4. Click the shortcut **name** at the top → rename to the exact name in the table above
5. Cmd+S (it auto-saves anyway, but doesn't hurt)

### Export each shortcut

For each of the three shortcuts you just made:

1. Right-click the shortcut tile → **Share** → **Save as File**
2. Save destination: `/Users/matthewpark/Downloads/current-projects/slapshift/app/SlapShift/Resources/DefaultShortcuts/`
3. The filename will be e.g. `SlapShift Set Focus to Do Not Disturb.shortcut`. Don't rename it.

Repeat for the other two. When done, that directory should contain:

```
SlapShift Set Focus to Do Not Disturb.shortcut
SlapShift Set Focus to Personal.shortcut
SlapShift Set Focus to Sleep.shortcut
README.md
```

### Regenerate the Xcode project

The `Resources/` directory is already wired into `project.yml` via copyFiles, but
xcodegen needs to see the new files:

```
cd /Users/matthewpark/Downloads/current-projects/slapshift/app
xcodegen generate
```

That's it. The files will now be copied into the app bundle on every build.

---

## Phase 3 — Run the app and walk through onboarding

This is the smoke test. You're verifying that everything compiles, the menu bar icon
appears, onboarding fires, you can grant Input Monitoring, install the shortcuts, and
land a real test slap.

### Build & launch

From Terminal:

```
cd /Users/matthewpark/Downloads/current-projects/slapshift/app
xcodebuild -project SlapShift.xcodeproj -scheme SlapShift -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/SlapShift-*/Build/Products/Debug/SlapShift.app
```

(If you'd rather use Xcode directly: `open SlapShift.xcodeproj`, then press **Cmd+R**.)

### Walk through onboarding

The app is `LSUIElement` (no Dock icon, menu-bar only). On first launch you'll see:

1. **Welcome step** — read the intro, click Continue.
2. **Input Monitoring step** — click "Open System Settings". macOS opens
   Privacy & Security → Input Monitoring. **Add SlapShift to the list** (toggle the
   switch on; you may need to drag the `.app` into the list using the **+** button).
   - Return to the SlapShift onboarding window. Within ~1.5s the "Waiting for
     permission..." line should flip to "✓ Permission granted". If it doesn't, click
     Open System Settings again — sometimes the toggle has to be flipped off then on.
3. **Shortcuts step** — click "Install Shortcuts". macOS will pop up an add-confirmation
   dialog for each `.shortcut` file (three of them). Click **Add Shortcut** for each.
4. **Test slap step** — give the palm rest one good slap. The icon flashes, the dialog
   shows "Got it." Click **Finish**.

After Finish, the window closes, the app stays running in the menu bar, and slaps now
fire real modes. The default mode bindings are:

- **1 slap → Coding** (opens VSCode, Terminal; quits Slack)
- **2 slaps → Apply** (opens Common App tabs in Chrome)
- **3 slaps → Wind Down** (closes everything except Spotify + Notes; enters Sleep focus)

Edit these via the menu bar icon → **Settings...**

### Sanity-check the Focus picker

1. Open Settings from the menu bar.
2. Pick any mode card → scroll to "Focus mode to enter (optional)".
3. The dropdown should now list the three Focus modes (Do Not Disturb, Personal, Sleep).
   If it shows "No Focus shortcuts found", the shortcut install in step 3 of onboarding
   didn't land — click the circular refresh icon next to the picker.

### Reset onboarding if you need to redo it

Onboarding is gated by a UserDefaults flag. To force it to show again:

```
defaults delete com.matthewpark.slapshift onboarding.complete
```

Then quit & relaunch the app.

---

## Phase 4 — Cut the signed, notarized release DMG

This is the part where you actually have something to ship. Notarization takes 2-5
minutes (Apple's servers scan the binary). The end product is `build/SlapShift-0.1.0.dmg`,
signed with the HMU, INC. Developer ID cert, notarized, and stapled — a `.dmg` any Mac
user can download and open without Gatekeeper screaming.

### One-time setup (do these before your first release)

**4a. Set the Team ID in project.yml**

Open `app/project.yml`. Find this line:

```yaml
    DEVELOPMENT_TEAM: "R43H5332KH"
```

`R43H5332KH` is your personal team. You need to change it to **HMU, INC.'s Team ID** —
the 10-character code you wrote down at the end of Phase 1 (it shows in parens after
"Developer ID Application: HMU, INC."). Update the line:

```yaml
    DEVELOPMENT_TEAM: "<HMU_TEAM_ID>"
```

Then regenerate:

```
cd app && xcodegen generate
```

**4b. Confirm notarytool credentials are stored**

You already did this. Verify with:

```
xcrun notarytool history --keychain-profile slapshift-notary
```

If that returns anything (even "no submissions"), credentials are good. If it errors,
re-run:

```
xcrun notarytool store-credentials slapshift-notary \
    --apple-id <your-apple-id-email> \
    --team-id <HMU_TEAM_ID> \
    --password <app-specific-password>
```

The `--team-id` here should match HMU, INC.'s Team ID. The Apple ID is yours.
The app-specific password is the `slapshift-notary` one you created at
appleid.apple.com.

### Cut the release

```
cd /Users/matthewpark/Downloads/current-projects/slapshift
./ops/release.sh 0.1.0
```

This single script does the entire pipeline:
1. `xcodebuild archive` — builds the signed Release `.xcarchive`
2. `xcodebuild -exportArchive` — exports the `.app` with the Developer ID cert
3. `create-dmg.sh` — packages the `.app` into a compressed DMG with `/Applications` symlink
4. `notarytool submit --wait` — uploads to Apple, blocks until scan completes (2-5 min)
5. `stapler staple` — attaches the notarization ticket to the DMG so it works offline
6. Verifies with `stapler validate` and `spctl --assess`

Output: `build/SlapShift-0.1.0.dmg`.

If any step fails, the script halts with a clear error. Common issues:
- **"Developer ID Application: ... not found in keychain"** → re-do Phase 1
- **`No account for team`** → `DEVELOPMENT_TEAM` in project.yml doesn't match a team your
  Apple ID is on. Confirm the Team ID with the Account Holder.
- **Notarization fails with `Invalid` status** → run
  `xcrun notarytool log <submission-id> --keychain-profile slapshift-notary`
  to see what Apple complained about. Usually a missing entitlement or unsigned helper.

### Verify the build by hand

After `release.sh` finishes, sanity-check:

```
cd /Users/matthewpark/Downloads/current-projects/slapshift
xcrun stapler validate build/SlapShift-0.1.0.dmg
spctl --assess --type install --verbose build/SlapShift-0.1.0.dmg
codesign --verify --deep --strict --verbose=2 build/export/SlapShift.app
```

All three should report success ("accepted", "valid on disk", "satisfies its Designated
Requirement"). If any of them fails, do not publish that DMG — investigate first.

### Test the DMG on a clean machine

The Mac you built on already trusts you. To verify a real user's experience:

1. Email/AirDrop the DMG to yourself on a different Mac (or a fresh user account).
2. Double-click the DMG → drag SlapShift to Applications.
3. First launch should show **no** Gatekeeper warning (just "SlapShift is from the
   internet — open?"). If you see "SlapShift can't be opened because Apple cannot check
   it for malicious software," notarization didn't staple. Re-cut the release.

### Ship it

Once the DMG passes the clean-machine test:

1. Upload `SlapShift-0.1.0.dmg` to your CDN (Cloudflare R2, Vercel Blob, S3 — pick one).
2. Put a download link on the marketing site.
3. Record the 6-second slap demo.
4. Post it.

---

## Where things live (quick reference)

- **Project root:** `/Users/matthewpark/Downloads/current-projects/slapshift/`
- **App source:** `app/SlapShift/Sources/SlapShift/`
- **Tests:** `app/SlapShift/Tests/SlapShiftTests/`
- **Bundled shortcuts:** `app/SlapShift/Resources/DefaultShortcuts/`
- **Release scripts:** `ops/`
- **Built DMG output:** `build/SlapShift-<version>.dmg`
- **Xcode DerivedData (debug builds):** `~/Library/Developer/Xcode/DerivedData/SlapShift-*/`
