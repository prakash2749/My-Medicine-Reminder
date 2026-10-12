# Notify — Signup UI Flow

## Experience

A calm mobile setup with one clear task per screen. Use the existing teal and mint theme, rounded cards, Inter typography, generous spacing and large touch targets. Keep a Back action at the top and the main action near the bottom. Retain entered values when users move between steps.

Design: https://www.figma.com/design/TkgXR4niEB8bP5bWUmXydw?node-id=37-832
Prototype: https://www.figma.com/proto/TkgXR4niEB8bP5bWUmXydw?node-id=39-834

## Main journey

Launch animation → Get Started → Personal Info → Purpose → My Day → Optional Care Circle → Create Account → Verify Email → Dashboard.

The first version is for users setting up their own medicine routine.

## 1. Opening animation

Show the friendly Notify companion blinking and gently moving for approximately three seconds.

Text:
- Notify
- “A little nudge. A calmer day.”

Then open the appropriate destination:
- Signed out: Get Started.
- Signed in with unfinished setup: last unfinished screen.
- Signed in with completed setup: Dashboard.

For this UI phase, use a demo switch to preview each destination. If the user prefers reduced motion, show a static logo. Avoid a bright flash between the animation and destination.

## 2. Get Started

Heading: “Less to remember. More peace of mind.”

Description: “Your prescriptions, daily routine and a little support — together in one place.”

Show the Notify companion above the heading and a short benefit card: “Upload. Review. Get reminded.”

Actions:
- Primary: Get started → Personal Info.
- Bottom link: Already have an account? Log in → Log In.
- Footer links: Terms and Privacy Policy → readable detail screens.

## 3. Personal Info — Step 1 of 4

Heading: “Let’s get to know you.”

Description: “A few details to make Notify feel like yours.”

Inputs:
- Name: text field; required.
- Birth date: date picker; required for this proposed flow, with no future dates.
- Gender: optional choice sheet; include Prefer not to say and a custom option.

Use a clear date display such as 09 Nov 2000. Let the year be selected directly rather than scrolling through months.

Actions:
- Continue → Purpose.
- Back → Get Started.

Behaviour:
- Show a short error below an incomplete required input after Continue is tapped.
- Keep the keyboard from covering inputs or the main action.
- Do not impose an age restriction in this UI until Notify’s account policy is defined.

## 4. Purpose — Step 2 of 4

Heading: “What can we help with?”

Description: “Choose what matters. You can select more than one.”

Show selectable cards with a checkbox and label:
- Remember my medicines.
- Track doses I’ve taken.
- Know when to refill.
- Organize prescriptions.
- Get family support.

Behaviour:
- Tap anywhere on a card to toggle it.
- Selected cards use a mint background, teal outline and checkmark.
- Selection must remain clear without relying on colour alone.
- Preserve selected cards when returning to this screen.
- Show only features planned for the released experience; the preview can use the full list.

Actions:
- Continue → My Day.
- Skip for now → My Day with no goals selected.
- Back → Personal Info.

## 5. My Day — Step 3 of 4

Heading: “Your day, your rhythm.”

Description: “Confirm your usual times. You can change these later.”

Show editable time cards with suggested values:
- Wake up: 7:00 AM.
- Breakfast: 8:30 AM.
- Lunch: 1:00 PM.
- Dinner: 8:00 PM.
- Bedtime: 10:30 PM.

Tapping a card opens a time picker. Make it clear that suggested times are editable. Offer “My routine changes” to let users skip fixed routine times.

Supporting text: “Dose times are confirmed after prescription review.”

Actions:
- Save my routine → Care Circle.
- Set up later → Care Circle.
- Back → Purpose.

This step asks about daily habits. Actual medicine reminders are reviewed after adding a prescription; do not imply that meal times already define a medicine dose.

## 6. Care Circle — Step 4 of 4

Heading: “A little support helps.”

Description: “Would you like someone to receive an alert when a dose hasn’t been confirmed?”

Start with two large choices:
- Yes, invite someone.
- Maybe later.

Choosing Yes reveals:
- Contact name: required.
- Country code and mobile number: required.
- Relationship: optional, e.g. Parent, Partner, Sibling, Friend, Other.
- Alert delay: editable; suggested 30 minutes.
- An unchecked agreement: “I agree to share unconfirmed-dose alerts with this person.”

Supporting text: “Medicine details stay private by default. Your contact must accept the invitation.”

Behaviour:
- Allow manual number entry.
- Offer Choose from contacts as an optional action.
- Show clear errors for an incomplete number or missing agreement after Continue is tapped.
- Maybe later proceeds without requiring contact fields.
- Explain: “Your invitation will be sent after your account is verified.”

Actions:
- Continue to account → Create Account.
- Maybe later → Create Account.
- Back → My Day.

## 7. Create Account

Heading: “Your routine is ready. Let’s keep it safe.”

Description: “Save your setup and restore it on another phone.”

Inputs:
- Email.
- Password with Show/Hide control.

Provide readable password requirements and inline validation. Display the applicable terms agreement clearly. Keep the setup answers when users return to a previous screen.

Actions:
- Create account → Verify Email in the preview.
- Already registered? Log in → Log In.
- Back → Care Circle.

UI states to design:
- Default.
- Invalid email.
- Password requirement unmet.
- Submitting: spinner and disabled duplicate submission.
- Submission failed: clear retry message, retaining inputs.

In the current preview, account creation is simulated. Do not present a demonstration as an actual saved account.

## 8. Verify Email

Heading: “Check your inbox.”

Description: “Open the verification link we sent to your email.”

Display the entered email and allow correcting it. Explain that the invitation will follow account verification.

Actions:
- I’ve verified my email → Dashboard in the preview.
- Resend verification email → simulated confirmation.
- Change email → Create Account.

Include a waiting state and a gentle “Not verified yet” message. Resend should show a visible cooldown. Demo actions must be labelled as simulated.

## 9. Dashboard — First Visit

Heading: “Hello, [name]. Let’s add your first prescription.”

Show:
- My Day summary, or Set up My Day if skipped.
- Care Circle status only when a contact was added.
- A clear first-prescription card.

Actions:
- Upload prescription → choose Camera or Photos.
- Enter medicines manually → medicine form.
- Edit My Day → routine editor.
- Care Circle → invitation status screen.

Request camera or photo access only when the user chooses that action.

## 10. Prescription and Dose-Time UI

After upload, show a review screen with editable medicine cards:
- Medicine name and strength.
- Amount per intake and unit.
- Instructions.
- Daily or selected weekdays.
- Start date and optional end date.
- One or more reminder times.

Show the prescription alongside the extracted details. Highlight unclear values with “Please check this.” In this UI phase, use clearly labelled sample results.

Add a time with “Add another dose time.” Each time can be edited or removed. Show a readable summary before the final action.

Actions:
- Confirm reminder plan → reminder-ready screen.
- Edit details → review form.
- Back → preserve the current review.

Do not activate a plan with unresolved medicine or dose details. Changing My Day later must show a confirmation preview before moving any related medicine reminders.

## 11. Invitation Status UI

Use separate visual states:
- Not added: Add someone.
- Pending: “Waiting for [name] to accept.”
- Accepted: “[name] is in your Care Circle.”
- Expired: “This invitation expired.”
- Removed: “This person no longer receives alerts.”

Actions:
- Resend invitation.
- Edit alert preferences.
- Remove person, with a short confirmation dialog.

Use demo states for these screens until the real invitation experience is connected. Do not show an invitation as delivered merely because the user tapped Send.

## 12. Log In and Password Reset

Log In:
- Email and password.
- Show/Hide password.
- Log in button.
- Forgot password link.
- Create account link.

Preview Log in → Dashboard or unfinished setup, according to the demo scenario.

Forgot Password:
- Email input.
- Send reset link button.
- Confirmation screen: “If an account exists for this email, you’ll receive a reset link.”
- Back to Log in.

## UI-phase completion checklist

- Navigation works through signup and back without losing entries.
- Purpose cards toggle independently.
- Date and time pickers open and retain selections.
- Care Circle fields appear only after Yes.
- Skipping optional steps works.
- Validation errors are readable and inputs remain available to correct.
- Password visibility toggles.
- Small screens scroll; large text does not overlap buttons.
- Keyboard and safe areas are handled.
- Demo loading, success and failure states are clearly simulated.
- Light and dark themes remain readable.

This document is the target UI flow. The existing Figma prototype demonstrates the main navigation; editable controls, conditional states and additional supporting screens should be implemented during UI development. Live account verification, prescription analysis, invitations and reminders follow in the integration phase.
