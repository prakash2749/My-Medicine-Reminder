# MED-034 implementation review and QA handoff

Issue: [#44](https://github.com/prakash2749/My-Medicine-Reminder/issues/44). Engineering self-review, 18 October 2026. The user confirmed that developer/legal name, support email and public website are currently unavailable. The work is prepared for review; public pages and Console declarations are not published/submitted or approved.

## Delivered

[Design](MED-034-DESIGN.md) was written before implementation. A versioned English/Hindi asset (`assets/policies.json`) now supplies both the offline Flutter notice and local static privacy/support pages. Entry points appear on the guest welcome, login, first account-profile collection, final signup and Settings. The notice distinguishes local encrypted medicine records from optional Supabase auth/profile/routine/purpose/contact processing, explains sharing/clipboard and retention, separates local erasure from online account deletion and states intended-use/non-device limits.

The offline view uses semantic headings, persistent privacy/support selectors, scrolling and safe failure/retry. Opening and returning preserves an entered profile name and does not accept the notice, create an account, change medicines or request permissions. Language comes from the existing app locale; prescription content is not translated. The splash/pubspec delivery guarantee is removed. Signup acknowledges the actual privacy notice instead of agreeing to unavailable terms, while the existing provider field is retained for compatibility. Care-circle copy now describes stored contact preferences and discloses inactive invitations/alerts rather than promising delivery or nonexistent Settings editing.

`scripts/render_policy_site.py` creates standalone HTML with shared local CSS, correct language, section links, a visible draft banner and no script/analytics/external fonts. It never publishes or sends messages. Non-draft rendering refuses missing contacts/HTTPS details, unresolved account-deletion configuration, unreviewed draft revisions and pending shared-content release statements before writing output. Configuration values alone cannot manufacture reviewed content. [The launch workbook](PLAY-LAUNCH-REVIEW.md) records proposed form answers, actual source paths, direct current primary policy links and release dependencies.

## Review findings

| Finding | Disposition |
| --- | --- |
| On-device medicine data does not make the entire app local-only | Privacy content and declaration workbook include reachable Supabase account/profile/contact processing and unknown deployment/server retention behavior. No blanket “no collection/no sharing” form answer is asserted. |
| Account creation exists without online account deletion | Explicitly disclosed as a test-build limitation and a public-release gate. #58 must be brought forward if signup remains; local reset cannot satisfy it. No fake support/deletion URL was added. |
| Failed asset load could remain cached | Retry uses `cache: false`, handles load/decode failures without raw exception disclosure, and has a failure/recovery widget regression. |
| Long policy page made navigation inconvenient at large text | Privacy/support selection remains above the scrolling document, reachable after reading to the end; both languages pass narrow 200% layouts. |
| Source manifest omits transitive declarations | APK badging/merged-manifest inventory covers WorkManager/AndroidX permissions. Target API observation is separated from policy requirements and signed release validation. |
| Guarantee and inactive caregiver claims | Removed from relevant app copy. Existing brand aliases Notify/Medicine Reminder are documented for #45 consistency/trademark review. |
| Another draft asserts empirical/legal completion from fixture tests | Added provenance notes to MED-028-EVIDENCE.md and privacy_security_audit.dart without discarding the user's draft or fixtures. Serialization tests are not legal classification, zero-risk assurance, fluent review, staffing or measured network/device evidence. |
| Unavailable identity/contact/hosting | User-directed unpublished drafts with empty example config and visible pending text. No deployed URL or staffed support is claimed. |

## Validation

Environment: Flutter 3.47.7 / Dart 3.13.5 (`C:/tmp/medicine-flutter`), Python 3.12.4 and isolated headless Chrome. Flutter checks use `D:/tmp/medicine-epics-validation` and process-local D: temp directories. Local artifacts are under `build/med-034/`; older QA directories remain intact.

| Check | Evidence / outcome |
| --- | --- |
| Static analysis | No issues; `analyze.log` |
| Format and whitespace | 104 Dart files, zero formatting changes in final check; tracked diff whitespace check passes; `format.log` |
| Full Flutter unit/widget/regression suite | 312 passed, 22 seconds; `tests.log`. Includes five new policy tests and the workspace's additional privacy fixture tests; fixture success is not compliance sign-off. |
| Static-page tests | Six passed; `site-tests.log`. Shared bilingual content, local links/resources, HTML escaping, schema failures and blocked non-draft rendering. |
| Actual public-render refusal | Expected failure with missing identity/contact/release details; no output directory created; `public-render-check.log` |
| Browser layout | English privacy/support at 1280px, Hindi privacy at 390px, Hindi support at 390px with 200% text. All have no horizontal overflow; `browser-layout.json` and the four page PNGs. Screenshots visually inspected; fluent translation review remains pending. |
| Android debug build | Passed, 117.7 seconds, normal main entry point and default ABIs; `app-build.log`, `medicine-reminder-debug.apk`, `SHA256SUMS.txt` |
| APK inventory | min SDK 24, target/compile 36, version 1.0.0+1; permission list matches the workbook. `apk-badging.log`, `apk-permissions.log`, `merged-AndroidManifest.xml`, `dependency-lock.yaml`. Bundled policy asset matches workspace bytes. |
| Source comparison | 145 workspace/validation snapshot source/dependency hashes match; `source-hashes.json` |

The static renderer uses only Python's standard library. Browser screenshots were obtained with a disposable headless Chrome profile and local files; the temporary QA helper uses this machine's existing websocket package and is not an application or renderer dependency. No personal browser session, real health data, Supabase production configuration, live Console submissions or public deployment was used. Flutter fixture tests and browser geometry do not replace physical TalkBack/OEM delivery, release-upgrade or qualified legal review.

APK SHA256: `B8A85FF0FB2816594F845430022492566AC0C42782E8BD8F897D36187BBEC3D9`. This is a debug QA artifact; existing Kotlin-plugin deprecation warnings remain dependency follow-ups. After the full regression run, the privacy fixture changes were limited to provenance comments and formatter output; app feature sources remained unchanged. No new migration, alarm identity, production SDK or health-data collection path was introduced.

## Remaining acceptance

1. Team supplies real operator/contact/hosting/effective-date details and named qualified reviewers; finalize both languages and intended-use/classification decisions under #13/#38.
2. Resolve the launch account-deletion scope and implement/verify in-app plus web requests if signup remains. Inspect actual deployed Supabase data access, providers, region, transport, logs and retention.
3. Complete branding/listing #45, device/upgrade #42/#43, actual account-specific testing/rating/access information and production signing/release #50. Verify public privacy/deletion URLs from outside the app before submitting the final declarations.

#44 remains open in Review / Testing for the engineering handoff; it is not accepted as a completed public-policy launch. Changes and QA artifacts remain local, without a commit or push.
