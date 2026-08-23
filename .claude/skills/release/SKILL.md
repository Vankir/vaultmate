---
name: release
description: Cut a VaultMate Android release per RELEASE_PROCESS.md — bump version, tag, wait for CI to build the AAB, download it, and hand off local signing.
metadata:
  author: vaultmate
---

# VaultMate Release

Executes the release flow documented in `RELEASE_PROCESS.md`, end to end through downloading the
unsigned bundle. Signing is always a manual hand-off (see Step 6) — never automate entering the
keystore passphrase.

## Preconditions

1. Confirm the working tree is on `main` and up to date:
   ```sh
   git checkout main
   git pull origin main
   ```
2. Run `git status --porcelain`. If there are unrelated uncommitted changes (e.g. an in-progress
   edit to `.specify/memory/constitution.md` or anything not meant for this release), leave them
   alone — stage and commit only `pubspec.yaml` in Step 2. Never `git add -A`/`git add .` here.
3. Confirm `flutter test` is green on `main` before releasing (CI will also verify this, but don't
   tag a known-broken `main`).

## Step 1: Decide the version bump

Look at what actually landed since the last tag (`git log $(git describe --tags --abbrev=0)..HEAD --oneline`)
to judge the bump, then read the current version from `pubspec.yaml` (`version: X.Y.Z+B`):

- **MAJOR**: breaking change to the vault/markdown format or user-facing behavior.
- **MINOR**: a new user-facing feature (e.g. a new screen, a new interaction like the swipe
  gestures added in 1.7.0). This is the common case for feature work.
- **PATCH**: bug fixes / internal cleanup only, no new user-facing capability.
- Build number (`+B`) MUST increase monotonically regardless of bump type — just increment by 1
  (or more) from the current value; it does not need to relate to the semantic version.

State the version you're about to release and the reasoning in one sentence before proceeding. If
the user's request didn't already clearly ask for a release to be cut and pushed (e.g. they only
asked to check something), confirm before continuing — Step 2 onward pushes to `main` and creates
a public tag/release, which are not easily reversible.

## Step 2: Bump, commit, push

```sh
# edit pubspec.yaml: version: X.Y.Z+B
git add pubspec.yaml
git commit -m "chore: release X.Y.Z"
git push origin main
```

## Step 3: Tag and push the tag

```sh
git tag vX.Y.Z
git push origin vX.Y.Z
```

This triggers `.github/workflows/main.yml` on the tag: `run_tests` → `build_android` (unsigned
AAB) → `release` (creates a GitHub Release `vX.Y.Z` with the `.aab` attached, only runs if the
prior two jobs succeed).

## Step 4: Watch CI

Find the run triggered by the tag push (not the `main` push — both fire; the tag one is what runs
the `release` job):

```sh
gh run list --limit 5
gh run view <run-id> --json status,conclusion,jobs \
  -q '.status, .conclusion, (.jobs[] | "\(.name): \(.status) \(.conclusion)")'
```

Poll (don't busy-loop with short sleeps in the foreground — use a background command with a
`sleep`-based wait loop, e.g. `until [ "$(gh run view <id> --json status -q .status)" != "in_progress" ]; do sleep 15; done`)
until `status` is no longer `in_progress`. A full run (tests + AAB build) has taken ~8-9 minutes in
this repo. Report failures immediately with the failing job's log rather than proceeding.

## Step 5: Download the bundle

Once the `release` job succeeds, download the AAB from the GitHub Release (preferred — it's the
canonical published artifact) rather than the raw workflow artifact:

```sh
gh release download vX.Y.Z --pattern "*.aab" --dir /tmp/vaultmate-release --clobber
```

If the release job hasn't run yet (e.g. checking mid-build) or you need the raw CI artifact
instead, fall back to:

```sh
gh run download <run-id> --name android-bundle --dir /tmp/vaultmate-release
```

## Step 6: Hand off signing — do not automate this

Copy the downloaded `.aab` into the sibling signing folder as `app-release.aab`, overwriting any
stale copy (check both `../vaultmate_sign` relative to this repo and, if that doesn't exist, the
absolute path `/Users/kirill/Projects/vaultmate_sign`):

```sh
cp /tmp/vaultmate-release/*.aab ../vaultmate_sign/app-release.aab
```

Then **stop and tell the user the bundle is ready to sign**. `../vaultmate_sign/sign_bundle.sh`
(a `jarsigner` wrapper) prompts interactively for the keystore and key passphrase — it does not
read a password from any file, and neither `key.properties` nor any other file in that folder
should be used to script around that prompt. Ask the user to run it themselves:

```sh
cd ../vaultmate_sign && ./sign_bundle.sh
```

Do not read, print, or transmit the keystore passphrase under any circumstance, and do not attempt
to pipe a guessed or stored password into `jarsigner`. If the user wants the output verified after
they've signed it, `jarsigner -verify -verbose -certs app-release-signed.aab` is safe to run (it
takes no secret input).

## Step 7: After signing (manual, outside this skill)

Uploading the signed `.aab` to Google Play Console is a manual step (see `RELEASE_PROCESS.md` §6)
— it requires interactive login to Play Console and is out of scope for this skill.
