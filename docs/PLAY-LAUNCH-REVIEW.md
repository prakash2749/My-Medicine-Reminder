# Play launch declaration workbook — MED-034

Prepared 18 October 2026 for [#44](https://github.com/prakash2749/My-Medicine-Reminder/issues/44). These are engineering observations and proposed answers, not submitted Console declarations or legal/regulatory approval. The user has confirmed that operator/legal name, support email and website are unavailable. Public pages must stay unpublished drafts. No Play Console access, account classification or production artifact has been verified by this task.

## Product and health declaration

Proposed scope: Android app for adults recording their existing fixed daily/weekday medicine plans, self-reported dose actions, local reminders, stock and reports. Select the currently available health/medication-management category matching that behavior in the live form. Do not claim clinical decision support, diagnosis, prescribing, a licensed medicine database, active caregiver alerts, OCR, Health Connect or medical-device approval.

The [Health Content and Services policy](https://support.google.com/googleplay/android-developer/answer/16679511?hl=en) requires the health declaration, truthful disclosures, a publicly accessible HTML privacy policy and appropriate health-function wording. The draft uses the policy's non-device statement and directs medical decisions to qualified professionals. Qualified intended-use/classification review under #13/#38 must confirm the actual market and behavior; wording alone does not settle regulatory status. Remove delivery/outcome guarantees from store material and the app. The splash/pubspec guarantee is replaced, and inactive caregiver onboarding is labeled as contact preferences rather than working alerts.

Draft store-description disclosure for #45: Medicine Reminder records plans and self-reported actions entered by the user. It is not a medical device and does not diagnose, treat, cure or prevent any medical condition. Consult a qualified healthcare professional for medical advice, diagnosis or treatment. Reminders depend on device settings and do not guarantee receipt. No clinical outcomes or guaranteed medication adherence are claimed.

Brand review: Android label and public draft use Medicine Reminder; some existing account screens/splash still use Notify. #45 must settle and consistently apply a checked product/developer name before final publication. Neither name has been checked for trademark availability by this task.

## Data safety: source inventory versus proposed form answers

Use the [Data safety instructions](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en) with the exact signed binary, account-enabled configuration and deployed providers. Device-only access does not itself constitute off-device collection under that form, while optional off-device account collection still needs review/declaration. Sharing has policy-specific definitions and exceptions; do not infer “shared” or “not shared” simply from a library name. All rows below are drafts awaiting network, processor and privacy review.

| Data observed in source | Where / purpose | Proposed treatment and evidence still needed |
| --- | --- | --- |
| Medicine names/instructions, doses, history, stock, personal schedule/timezone, revisions | SQLCipher locally; reminders, history and inventory | Core medicine flows have no implemented upload. Disclose local access in the privacy notice; verify all production SDK paths/traffic before asserting any off-device collection answer. |
| Email, password for auth, signup name, Supabase user ID/session | Supabase auth, optional account management and recovery | Answer account collection truthfully for an account-enabled release; map email/name/user IDs to current form types. Verify auth/provider logging, transport, access and credential handling; do not retain passwords in support evidence. |
| Name, date of birth, gender, language, timezone | `profiles` upsert, optional account onboarding | Proposed personal-information collection for account functionality/personalization. Confirm each form subtype, optionality and necessity; birth date is currently required by that wizard, although a user can avoid the entire account flow by using guest. |
| Wake/meal/sleep times and selected onboarding purposes | `routine_times`, `onboarding_answers` | Personal routine/purpose information transmitted with account onboarding. Reviewer must decide health/other-personal-information mapping based on actual answers; do not omit these because medicine schedules are local. |
| Contact name, phone, relationship, alert preferences and owner-consent timestamp | `care_circle_members`, if optional contact details are supplied | Proposed contacts/phone/other-personal-information review, not a claim of Android contacts access. Actual recipient consent, minimization and legal basis need review. No invite/alert delivery is implemented. |
| User-requested PDF and copied readiness bundle | OS share destination / clipboard / chosen support service | Review user-initiated transfer exceptions in the form. Notice covers outside copies. Hosting/support may process submissions and connection metadata; configure real providers and retention before launch. |
| Connection information, server/email logs, session/SDK behavior | Supabase and any deployed hosting/support provider | Unknown actual retention, regions, subprocessors and log use. No blanket “zero collection,” “never leaves phone,” “no sharing” or “encrypted in transit for all flows” answer until verified against deployment. |

No advertising, remote analytics or remote crash SDK is enabled by the app source. Local readiness is on-demand and allowlisted, not clinical telemetry. Verify the full locked dependency tree and release manifest, including transitive libraries, rather than converting that observation into an unverified security certification. Security/retention/grievance review uses [the data map](EPICS-1-7-PRIVACY-REVIEW.md) and named reviewer decisions; do not claim HIPAA/GDPR/DPDP certification.

## Account deletion is a release dependency

Optional account creation is reachable and Supabase account/profile/contact information is distinct from the encrypted medicine database. Local reset and individual medicine deletion are implemented; **they do not delete an online account**. The app now states this clearly.

The [account deletion policy](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en) requires qualifying account-creation apps to offer an in-app deletion-request route plus an accessible outside-app web route. The web route must identify the app/developer and work without requiring reinstallation. Neither route is implemented for Supabase accounts in this test build. [#58](https://github.com/prakash2749/My-Medicine-Reminder/issues/58), originally deferred cloud deletion, must be brought forward if signup remains in the launch scope; cover current auth/profile/routine/purpose/contact data, verification, retention exceptions and deployed deletion execution. An alternative launch-scope decision to remove account creation needs an actual code/build review; it has not been made here. Do not submit a deletion URL that merely describes local reset, invent a working inbox, or check deletion-complete based on draft HTML.

## Artifact and permission review

Initial observation from the #48 debug APK: package `com.example.medicine_reminder`, version `1.0.0+1`, min SDK 24, target/compile SDK 36, label Medicine Reminder. MED-034 validation records the new artifact hash, actual badging/permissions, merged manifest and locked dependency inventory in `build/med-034/`. Use its log as the authoritative observed list, and repeat on the signed AAB/APKs under #50. No Supabase production config was supplied to the QA build; a successful local build does not prove deployed auth, RLS or transport behavior.

| Actual merged permission | Purpose / review |
| --- | --- |
| `INTERNET` | Optional account/network services; also debug tooling in a debug build. Inspect production network endpoints and configuration. |
| `POST_NOTIFICATIONS` | Runtime notification permission; denial preserves records but can stop alerts. |
| `SCHEDULE_EXACT_ALARM` | User-controlled precise scheduling access with degraded approximate behavior when absent. |
| `RECEIVE_BOOT_COMPLETED` | Queue future-alert reconciliation after reboot. |
| `VIBRATE` | Notification vibration from the notification dependency. |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SHORT_SERVICE` | Transitive WorkManager declarations; inspect actual worker/service execution and the current Console form. Presence is not proof of an active long-running data-sync service. |
| `WAKE_LOCK`, `ACCESS_NETWORK_STATE` | AndroidX/WorkManager scheduling and connectivity dependencies. |
| App-scoped `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` | Signature-level AndroidX receiver protection; not personal-data access. |

The inspected merged artifact does **not** declare `USE_EXACT_ALARM`, `USE_FULL_SCREEN_INTENT`, Health Connect, advertising ID, camera, contacts, location, microphone, or broad storage access. `SCHEDULE_EXACT_ALARM` must not be confused with restricted `USE_EXACT_ALARM`; full-screen takeover is not implemented. Recheck any dependency change against [permissions policy](https://support.google.com/googleplay/android-developer/answer/16558241?hl=en) and [foreground/full-screen requirements](https://support.google.com/googleplay/android-developer/answer/13392821?hl=en). Remove genuinely unused permissions after testing rather than claiming exemptions based on a reminder label. The current Gradle release signing uses a debug key: not approved for production.

## SDK target, testing, rating and access

The [current target API policy](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en) says new mobile submissions/updates require target API 36 from 31 August 2026, with described extension options. The inspected debug target is 36; no extension is assumed. Reverify at submission and test Android 16 behavior on the actual release candidate. API 35 emulator evidence alone is not API 36/OEM testing.

The [new personal developer-account testing policy](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en) describes at least 12 opted-in testers for 14 continuous days for applicable accounts created after 13 November 2023, followed by a production-access application. The actual account type/date/dashboard requirements are unknown; the account owner must inspect and record their real requirement without sharing credentials. #46's 20–30 participants/two-week study is a product plan, not evidence that the platform gate was met.

Proposed target audience: adults only, subject to #13 approval. This is not a completed age-rating certificate. Complete the actual IARC questionnaire using reachable content/functionality and record rating/certificate under #45; do not invent an Everyone/3+/18+ result. Describe no ads/no purchases only if the final candidate matches. Under [app review preparation](https://support.google.com/googleplay/android-developer/answer/9859455?hl=en), disclose reviewer access limitations and supply a valid synthetic account/instructions if login-only features remain. The local core can be inspected as guest without an account; do not place real credentials in this repository.

## Draft page generation and publication handoff

`assets/policies.json` is the shared English/Hindi source for the offline app and generated pages. Drafts contain explicit pending operator/deletion/service-review statements. `docs/launch/site-config.example.json` deliberately contains empty real-world details. The renderer is a local build tool, not a publisher or legal approval tool.

```powershell
python -m unittest discover -s scripts -p test_render_policy_site.py -v
python scripts/render_policy_site.py --draft
```

Output: `build/med-034/site/index.html`, `privacy-en.html`, `privacy-hi.html`, `support-en.html`, `support-hi.html`, `style.css`. Files use shared local CSS, semantic headings/links, no script/analytics/external fonts, no login, and a noindex draft banner. `noindex` is not access control; keep drafts local rather than relying on it to hide private information. No actual health data is used.

A non-draft render fails before writing output while identity/contact/HTTPS URL/effective date, account-deletion configuration, reviewed revision or shared-content release gates are unresolved. Updating config flags is not proof that deletion works or a reviewer approved the notice. Before public rendering, implement/verify the missing routes, replace pending shared text with reviewed operator/hosting/retention details in both languages and record reviewer decisions. Then host the static output on the real HTTPS site, verify every URL publicly without login/geofence, and add actual privacy/deletion links in the app and Console. Publication is not part of this task while the required details are unavailable.

## Acceptance handoff

- Engineering: shared offline content, discoverable entry points, safe draft generator, source/artifact inventory, proposed declaration mapping and copy fixes.
- Product/privacy reviewer: approve intended use/classification, operator identity, necessity/consent, retention/rights/contact text and actual providers. Fluent Hindi reviewer signs both UI and pages.
- Platform/release: implement the account-deletion decision, verify deployed network/RLS behavior and release SDK/permissions/signing, complete #42/#43 device/upgrade evidence.
- Account owner: confirm live Console requirements, submit reviewed declarations, host/verify public URLs and record actual IARC/testing results. No checkbox in this workbook claims that these have occurred.

Keep #44 open for review and completion of the external acceptance evidence.
