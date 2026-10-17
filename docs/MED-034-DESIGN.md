# MED-034 launch disclosures and policy pages design

Issue: [#44](https://github.com/prakash2749/My-Medicine-Reminder/issues/44). Designed 18 October 2026 before implementation. The user confirmed that operator/legal name, support email and public website are not available. Prepare unpublished drafts and review evidence; do not invent contacts, deploy pages or submit Play declarations.

## Findings and scope

The core medicine records stay on-device, but optional Supabase signup/sign-in and profile onboarding are reachable. A blanket “no data collected” declaration would be misleading. Signup refers to unavailable terms/privacy text; the splash/pubspec still promise “never miss a dose.” The current debug merged manifest targets API 36 and includes transitive WorkManager permissions that are absent from the source manifest. Inventory the actual artifact rather than copying only the source permission list.

Deliver a shared English/Hindi policy-content asset, accessible offline privacy/support view, entry points before guest/account use and from Settings, removal of delivery guarantees, plain intended-use/non-device disclosures, a dependency-free static-page renderer with draft handling, and a sourced Play review workbook. Preserve existing account behavior and local medicine records. Account deletion is an explicit release dependency (#58), not silently implemented as local reset. Human classification/legal review, production SDK/network audit, real operator/contact/hosting, actual Play account requirements and public publication remain pending.

## Content architecture and UI

One versioned JSON asset supplies privacy/support sections in English and Hindi to Flutter and the static renderer. Application copy is separate from prescription text. The privacy page covers local health data, optional remote account/profile/care-circle fields, service providers, exports/clipboard/notifications, retention/deletion/security limits, and contact status. Support covers software/treatment boundaries, reminder limitations, safe record-preserving troubleshooting, diagnostic review, local-versus-account deletion and contact status.

The offline view loads only the bundled asset, supports explicit privacy/support selection, semantic headings, scrolling/large text and a retry state if the asset cannot load. Opening/closing preserves form state and never changes records, consent or permissions. Buttons open a normal Navigator route so legacy and GoRouter screens share the same view. Place access on welcome, login, first personal-info collection and signup, plus Settings. Replace passive agreement to unspecified terms with a clear privacy-notice acknowledgement; retain the existing provider validation contract rather than manufacture legal terms.

Public drafts render as standalone semantic HTML with shared local CSS, correct language, no analytics, script, external font or login dependency. Draft headers explicitly say unpublished; missing contact details are visible as unavailable. A non-draft render refuses empty identity/contact/HTTPS-site/effective-date values and unresolved account-deletion configuration. Rendering never publishes, sends mail or makes a declaration. Operator confirmation and qualified review still determine release readiness; a successful render is not legal approval.

## Policy and artifact evidence

Record the reviewed date and direct official policy links beside decisions: health-app declaration/non-device wording, privacy notice and Data safety, reachable account-creation deletion obligations, API target level, precise alarms/full-screen intents, foreground-service permissions and account-specific closed testing. Keep proposed answers separate from observed facts and unknown deployed-service behavior. Intended audience adults is not a completed IARC content rating or jurisdictional medical-device classification.

Capture package/version/SDK/permissions from the newly built APK and retain the merged manifest and dependency inventory with its hash. Flag production-specific differences: debug artifact/network config is not a signed release or network-traffic audit. Supabase host/region/server retention/RLS, provider collection and email delivery still require review against the deployed project without exposing keys.

## Validation and handoff

- Test policy content schema, parity of both languages, offline navigation/back/form preservation, load failure/retry and 200% narrow-screen layouts.
- Test static rendering: complete local links, HTML escaping, draft status and refusal of incomplete non-draft configuration. Confirm generated pages do not require external resources or login.
- Format/analyze/run the Flutter regressions, build a normal debug APK and inspect actual permission/target metadata. Review claims and declarations against source plus current primary policies.
- Record exact outcomes and external release gates in MED-034-REVIEW.md. Keep #44 open; “ready for review” does not mean public URLs or approved Console declarations exist.
