# App Store submission: local-only hmux for iPhone

> **On hold (November 2026): wait for Manaflow's answer.** Permission to
> distribute through the App Store was requested by email in October 2026.
> Until Manaflow replies with written permission, don't upload or submit
> anything. The App Store Connect record is ready (texts, screenshots, price,
> age rating, review notes); only App Privacy, the review contact's phone
> number, the demo video and the upload are left. Meanwhile hmux is shared
> through GitHub Releases, which the GPL fully allows.

Everything needed to submit the local-only iPhone app to the App Store. The
rest of `ios/AppStoreReview/` is upstream's package for the account-based app
and doesn't apply to this build.

## Before anything else: the license

hmux for iOS is GPL-3.0, and most of its code belongs to Manaflow and the cmux
contributors. Apple's App Store terms add restrictions the GPL doesn't allow,
so **do not upload or submit this build, not even to TestFlight, until
Manaflow has granted written permission** (an additional permission under
GPL-3.0 section 7) to distribute it through the App Store. Store that
permission next to this file as `permission.md`.

Preparing the build and the App Store Connect record (steps 1–4) distributes
nothing and is fine without it.

## Checklist

1. **App ID.** In the Apple Developer portal (Certificates, Identifiers &
   Profiles → Identifiers), register an explicit App ID for the bundle ID in
   `.env-local` (for example `com.example.hmux`). It needs no extra
   capabilities.
2. **Distribution profile.** Under Profiles, create an **App Store Connect**
   distribution profile for that App ID with your Apple Distribution
   certificate. Download it and double-click it to install.
3. **App record.** In App Store Connect → Apps, create a new iOS app with that
   bundle ID. The name must be unique on the App Store. Then fill in:
   - the texts from [metadata.json](metadata.json)
   - the privacy policy URL: https://github.com/devicemanager/hmux/blob/main/docs/privacy.md
   - **App Privacy:** "Data Not Collected" (see [docs/privacy.md](../../../docs/privacy.md))
   - **Encryption:** the app declares `ITSAppUsesNonExemptEncryption = NO`, so
     no export documents are needed
   - **Age rating:** answer the questionnaire. The app can open web pages in
     its built-in browser, which Apple rates as unrestricted web access.
4. **Build.** Raise `CURRENT_PROJECT_VERSION` in `ios/Config/Shared.xcconfig`
   above every build uploaded before, then run:

   ```bash
   ios/scripts/build-local-only.sh --app-store build/app-store
   ```

   It writes `build/app-store/<name>-<version>-<build>-appstore.ipa`, signed
   with the App Store profile. It uploads nothing.
5. **Screenshots.** App Store Connect needs iPhone screenshots for the 6.9″
   display (1320 × 2868) and, because the app also runs on iPad, 13″ iPad
   screenshots (2064 × 2752). Take them on your devices with a paired Mac.
   Don't show hostnames, addresses or anything else private.
6. **Demo video.** Record a short screen video (1–2 minutes): show the pairing
   code on the Mac, scan it on the iPhone, open a workspace and type into a
   terminal. Upload it unlisted (for example on YouTube) and put the link in
   [review-notes.md](review-notes.md).
7. **Upload** (only with the permission from above): open the `.ipa` in
   Apple's [Transporter](https://apps.apple.com/app/transporter/id1450874784)
   app, or run

   ```bash
   xcrun altool --upload-package build/app-store/<file>.ipa --type ios \
     --apiKey <key-id> --apiIssuer <issuer-id>
   ```

   with the App Store Connect API key from `.env-local`.
8. **Submit.** In App Store Connect, pick the build, paste
   [review-notes.md](review-notes.md) into App Review Information, and submit.

## Review risks

- **Guideline 2.1 (the reviewer must be able to use the app).** The app needs a
  Mac running hmux on the same tailnet. The demo video and review notes are
  the usual answer for companion apps. If App Review asks for live access,
  you can share a test Mac with a reviewer's Tailscale account through
  Tailscale's node sharing.
- **Guideline 4.1 (copycats).** hmux looks like cmux, which is also on the App
  Store. Use your own name and icon, and say clearly in the description that
  hmux is an independent fork with credit to cmux. Manaflow's written
  permission helps here too.
