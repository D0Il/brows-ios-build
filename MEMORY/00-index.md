# 00 — INDEX: WHERE EVERYTHING IS AND THE ORDER TO READ IT

## Read order (each file to its last line)

1. `../FAMEBROWZ.md` — the condensed chronological history (July 19–November 4, 2026): what was
   asked, built, broken and measured. History only; current state is `30-state.md`.
2. `../AGENTS.md` — the only rules file (recovery, clause ledger, honesty, project rules).
3. `00-index.md` — this map.
4. `20-domain-rules.md` — accumulated technical rules for Chromium, glass, rail, mojom, build.
5. `30-state.md` — where the work stands; the dated IN-FLIGHT block comes first.
6. `31-state-ui-passes-a.md` — dated design passes 1–13 (2026-11-10 → 11-12).
7. `32-state-ui-passes-b.md` — dated design passes 14–24 (2026-11-12), incl. the zoom cluster.
8. `33-state-site-release.md` — brows.dev, `publish-site.ps1`, the 156 installer.
9. `40-parity-ledger.md` — the equal-or-better audit: Chromium affordance vs Brows, with the
   evidence for each row (runtime, source `file:line`, or unverified).
10. `45-mobile-research.md` — how Safari/Chrome/Opera/Firefox arrange their phone chrome, and the
    arrangement that follows for the iOS app (bottom rail, tab gallery with search, one menu sheet).
11. `46-ios-build-recipe.md` — the verified GitHub-runner build/launch recipe for `ios/Brows`, the
    private build repo, and the four failures that each cost a run (scene manifest, simulator
    runtime, console-pty, YAML block scalars).
12. `34-state-ios.md` — the dated iOS passes, 2026-11-16 → 11-17 (split out of `30-state.md` when
    that file passed the 50 KB gate on 2026-11-17; the current line stays in `30-state.md`).
13. `47-ios-desktop-pairs.md` - which iOS surfaces were compared against a *rendered* desktop
   surface (`docs/parity/desktop/`), the verdict per surface, and what could not be paired.

## Where new knowledge goes (routing — mandatory, same pass as reading)

| What you recovered | Destination |
|---|---|
| A standing instruction/demand | `../AGENTS.md` §PROJECT RULES, quoted, with date |
| A correction of how a message was read | `72-instruction-misreads.md` (new row) |
| What a landing got wrong / what a compaction cut | `71-compaction-postmortems.md` |
| What shipped in a stretch, and was verified | the relevant dated section of `../FAMEBROWZ.md`; current status in `30-state.md` |
| A technical rule the subject cost you | `20-domain-rules.md` (numbered one-liner + `file:line`) |
| Where the work stands now | `30-state.md` IN-FLIGHT block, then a dated paragraph |
| How to run/verify | `05-run.md` |
| A stale name, or a claim proven false | this file §Stale names |

A fact with no destination has not been recovered. The full spec is
`C:\Users\xjpma\Desktop\CONTEXT-RECOVERY-PART-3-WHAT-COUNTS-AS-READING.md` §4.

Supporting files:
- `05-run.md` — how to build, launch, verify, and the traps.
- `71-compaction-postmortems.md` — what went wrong at each landing and what the user said.
- `72-instruction-misreads.md` — every time an explicit message was read wrongly.

## What this project is

A native Chromium fork at `D:\FAME-Chromium\checkout\src` (branch `fame-156-port`, HEAD `fb096c0011`, 156.0.8078.80; 152 fallback `fame-152-final` @ `6efc8b0312`) that
must be a complete, shipped browser in its own right, with working Google/YouTube sign-in. The port/notes repo is
`C:\Users\xjpma\Documents\FAMEBROWZ`. Product name **Brows**; company **Z7**.
The user calls it their product/business, not a demo.

## Stale names and false claims

- `npm run resume` **does exist** (`scripts/resume.js` → `scripts/recovery.mjs`, gate
  `scripts/memory_check.mjs`, wired in `package.json`). A previous version of this index claimed it did
  not; that was false and cost two skipped recoveries. Run the command.
- "Read `.freebuff/tmp/resume-tail.md` from its first line to its last line" was the old step 1. It is
  wrong after a compaction: the tail begins at the compaction marker and is the summary's own replay.
  The region to read starts **before** the marker, at the earliest turn the visible set cannot explain.
- `build-fix5 -j 10` "in flight" was stale on 2026-11-01: all builds had finished (green relink at
  `02:33:02`, export 88572) and no browser was running (export 88691).
- The old history set was removed on 2026-11-04: `FAMEBROWZ CHAT.txt`, the raw export attachments,
  `73-full-history-study.md`, the six `parts/study-*.md` files, and the 2026-07/10 study documents.
  `FAMEBROWZ.md` is the only chronology; do not recreate a second one.

## Deliberately not present
- `out\FameBaseline` (static 450 MB build) was deleted on purpose; do not propose rebuilding it.
- Installer/updater: the 156 branded build+installer completed 2026-11-10 17:26 — `Brows-156-Setup.exe` 685,621,248 B, `Brows Installer` / `Z7`, version 156.0.8078.80, SHA-256 `C657D701…640BDD`. **The updater IS delivered** (this line used to claim otherwise and cost a false
  statement on 2026-11-13): `brows::CheckForUpdate`/`brows::InstallUpdate` live in
  `chrome/browser/ui/views/toolbar/brows_updater.cc`, the feed default is
  `https://brows.dev/latest.json` (`browser_prefs.cc:1996`), Settings has
  `#check-updates` / `#install-update` / `#update-status`, and the install half downloads the
  installer through `InstallerDownloader(url, sha256, ...)` before `LaunchInstaller`.
  Measured 2026-11-13: clicking Check for updates in the running build answered
  "Brows is up to date (version 156.0.8078.80)." Open defect: the automatic check that is
  supposed to run when Settings opens does not fire (status stays "Updates have not been
  checked yet"), because the call runs at module scope before the handler is ready.
- `50-needs-audit.md` — every technical demand in the 286-message record, with its state.
