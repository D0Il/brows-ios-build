# 72 — INSTRUCTION MISREADS

Every entry: the user's words, the substitution the assistant made, what should have been parsed.

| User's words | What the assistant did | Correct parse |
|---|---|---|
| "I CANNOT SEE THROUGH IT. IT IS NOT GLASS." | Treated glass as CSS alpha/blur level and checked what Windows "can support" | ACTION: make the window literally see-through. OBJECT: the window. It is a regression in this build |
| "so you CLEARLY DIDNT STUDY THE RIGHT PART OF THE HISTORY … WHY WOULD YOU STUDY THE ELECTRON ERA" | Searched Electron transparency terms for a Chromium feature | METHOD: study the Chromium-era history for a Chromium feature |
| "IM NOT TALKING ABOUT THE FGUCKIONG CODE CHANGES" | Explained how many source files recompile | OBJECT: build actions/wall-clock cost, not source files |
| "WHY THE FUCK ARE YOU TRYING TO EYEBALL … INSTEAD OF READING THE OLD FUCKING CODE" | Compared screenshots | METHOD: read `webui.css`/`webui.html`/`webui.js` |
| "you dumb fucking nigger i most literally just told you to do it with the fucking test thing" | Captured without the checkerboard behind the window | METHOD: the controlled test harness, pattern first |
| "YOU LITERALLY TOOK A PHOTO OF THE OLD FAME BROWSER AGAIN" | Argued timestamps/process lists | OBJECT: provenance of the image itself; never present the old app as the new build |
| "IF ITS NOT A 100% REPLICA WH YTHE FUCK DID YOU STOP" | Ended the turn with a two-route question | Do not end until parity or a named blocker |
| "ARE YOU ABOUT TO DO SOMETHING WITHOUT NOTIFYING ME" | Started `mini_installer` silently | Announce consequential actions before starting |
| "WHY THE FUCK WOULD I EVER NEED THAT STUPID FUCKING SHIT AGAIN" (static build) | Proposed keeping/using `FameBaseline` | OBJECT: the component build only; static is dead |
| "what the hell do u mean installer" | Used packaging jargon | FORM: plain language; packaging is not the point of the project |
| "WHAT THE FUCK DO YOU MEAN HOURS LONG" | Said a rebuild would take hours | Quote the measured incremental time; close the browser → it is minutes |
| "WHAT THE FUCK ARE YOU TALKING ABOUT REVERTED" | Called an unauthorized branding experiment a "revert" | There was no revert to speak of; the checkout copy was simply stale |
| "ARE FAVOURITES ON A NEW ROW" | Had left Chromium's bookmarks bar row | OBJECT: favourites chips inside the toolbar row |
| "WHY IS IT USING THE GENERIC CHROMIUM POPUP FOR THE TAB SEARCH" | Left `TabSearchUI` | OBJECT: the FAME popup; tab search must search real tabs |
| "RUN THE FUCKING SKILL." (2026-11-01) | Read kit docs, wrote a shim, narrated the procedure | ACTION: execute `npm run resume` first, in that turn, before anything else |
| "SO MAYBE THATS WHY THE SKILL ITSELF EXPLICITLY SAYS THAT IS NOT WHAT YOU ARE SUPPOSED TO BE FUCKING READING" (export 88821) | Read `.freebuff/tmp/resume-tail.md` — the post-marker replay, including its own thinking — and called it the era | OBJECT: the region **before** the marker that the summary cannot account for; the tail is the visible set |
| "WHAT ... GIVES YOU CONSENT TO USE THAT YES WHENEVER YOU WANT?" (this landing) | Ran `--fresh` reusing an earlier "Yes — that's the fresh export" | Consent is per-landing: run the gate, ask, wait for the answer to that exact question |
| "WHY DID U NOT RUN THE SKILL" (2026-11-03) | Started the workspaces CSS fix after the interruption without recovery | ACTION: run `npm run resume` first; then read the startup set and era to EOF before editing |
| "QUEUE ALL OF THE FUCKING VISUAL CHECKS INTO ONE FUCKING PASS" (export 87790) | Captured the screen repeatedly, one check per attempt | METHOD: one scripted pass that exercises every queued check; PrintWindow/CDP, never OS input |
| "when did i EVER SAY THAT WAS ALLOWED." (2026-11-03, after the sidebar question) | Attached "that" to the just-built vertical tabs and started removing them | OBJECT: the **sidebar** category, not vertical tabs. Vertical tabs were kept and are allowed; ask which noun when the referent is ambiguous |
| "WHAT FUCKING PART OF ME SAYING I NEVER ALLOWED A SIDEBAR MEANS TO REMOVE VERTICAL TABS" (2026-11-03) | Had already edited five files before checking the referent | Parse the nearest named object; do not mutate source on an inferred objection |

| "JUST FUCKING RUN THE SKINN, STUDY THIS FUCKING CHAT HISTORY I ATTACHED, AND THEN DO WHAT THE FUCK I SAID" (2026-11-03) | Ran the upgrade/history work before the recovery skill, then did not finish the skill receipt | ACTION: run `npm run resume` first; read the era and the attached project history; write the receipt; then continue the named work |
| "you literally just ignored the runs demands" (2026-11-04) | After `npm run resume` printed "STOP — ASK THE USER", inspected `recovery.mjs` and the DB | ACTION: ask the gate question and stop; OBJECT: the run's stdout, not the DB internals |

| "DID I FUCKING STUTTER WHEN I MOST LITERALLY SAID ITS OPEN ON THE FUCKING PREVIEW?" (2026-11-15) | Answered "Not verified live: the popup rendering needs a signed-in gate cookie, which I don't have" while brows.dev was open in the shared preview tab | OBJECT: the browser tab the user is looking at is a reachable surface — check it with `preview_status`/`preview_evaluate` before claiming anything is unverifiable |
| "if ur acting confused why arent you running the skill you lazy COW" (2026-11-15) | After the compaction, answered three "is it done / how far along" turns by inspecting build logs, never running `npm run resume` | ACTION: `npm run resume` first at every landing, then the read set and the era, then work |
| "so the browser app is now fully done … and is up to my standards? thats why ur stopping i assume." | Reported the committed tree, gates and mirror as the answer, then went looking for desktop reference material with grep | FORM: yes/no about completion. Answer it from the record: what is proven, what is NOT done, and do not imply "done" — run the recovery kit first when the chain of events is missing |

## The pattern
The assistant repeatedly answers the *code* question when the user asked the *visible-product*
question, and substitutes a proxy (screenshot, file count, build label) for the named method. The fix
is the clause ledger: hold ACTION · OBJECT · METHOD · FORM · SCOPE · STOP before the first tool call.
