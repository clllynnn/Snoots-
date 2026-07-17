# Snoots! iOS Design System

Version: 3.0
Direction: Bright, rounded, pet-first utility with a clear AI accent.

## Typography

Use the system SF Pro Rounded family throughout the app.

| Token | Font & treatment | Use |
|---|---|---|
| Logo | SF Pro Rounded Heavy | `SNOOTS!` wordmark; uppercase is allowed |
| Heading | SF Pro Rounded Semibold | Screen, section, and card titles |
| Body | SF Pro Rounded Regular | Paragraphs, metadata, chips, and supporting copy |
| Button | SF Pro Rounded Bold | Primary and secondary action labels |

## Color

| Token | Value | Use |
|---|---:|---|
| ink | #222222 | Primary text and icons |
| primary / lime | #D8FF45 | Primary actions, verification, and AI accents |
| lavender | #B88EFF | AI actions and AI recommendation cards |
| surface | #FFFFFF | Cards, sheets, and secondary buttons |
| canvas | #F7F7F4 | Screen background |

Keep primary text and icons in ink on light surfaces. Use white text only on lavender AI surfaces.

## Geometry and depth

| Token | Value | Use |
|---|---:|---|
| Button radius | 20 pt | Primary and secondary buttons |
| Card radius | 28 pt | Content, profile, map, and recommendation cards |
| Input radius | 18 pt | Inputs and compact contained rows |
| Profile image radius | 24 pt | Profile and full-width card imagery |
| Card shadow | Black 8%, blur 20 pt, Y 6 pt | Soft card separation |

Use rounded 2 pt line icons. Avoid sharp-cornered decoration.

## Buttons

### Primary

- Background: #D8FF45
- Text: #222222
- Radius: 20 pt

### Secondary

- Background: white
- Border: 2 pt #D8FF45
- Radius: 20 pt

### AI

- Background: #B88EFF
- Text: white
- Radius: 20 pt

## Cards

### Profile card

- White surface with a 28 pt radius and very soft shadow.
- Place the photo full width at the top, using a 24 pt image radius.
- Keep the information area white beneath the image.

### AI recommendation card

- Background: #B88EFF
- Text: white
- AI icon or status accent: #D8FF45
- Use the standard 28 pt card radius and soft shadow.

## Accessibility

- Preserve strong ink-on-light contrast.
- Pair selection, trust, and urgency color with an SF Symbol or clear text.
- Keep icon-only actions labelled for VoiceOver.
- Respect Dynamic Type and do not rely on fixed, single-line safety instructions.

## iOS Human Interface Guidelines

Follow Apple's [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/) alongside this system. Snoots!' visual personality may be distinctive, but its behavior should remain immediately familiar to iOS users.

### Native interaction

- Prefer standard SwiftUI controls and system behaviors for navigation, sheets, menus, alerts, text input, selection, and sharing.
- Use a tab bar only for the app's four top-level destinations. Preserve each tab's navigation state when people switch tabs.
- Present focused, temporary tasks in sheets; use alerts only for important confirmations, errors, or irreversible choices.
- Keep system navigation gestures, safe areas, keyboard behavior, and dismissal affordances intact. Never replace a familiar system gesture with a custom one unless the benefit is clear.
- Make every interactive target at least 44 × 44 pt. Provide clear pressed, selected, disabled, loading, saved, and error states.

### Content and feedback

- Put the primary action where it is easy to find, name it with a direct verb, and avoid duplicate actions on the same screen.
- Use concise, sentence-case labels. Prefer recognizable SF Symbols paired with text when meaning might be ambiguous.
- Give immediate feedback for actions such as matching, saving a place, submitting a post, and requesting help. Use haptics sparingly and only to reinforce a meaningful result.
- Keep emergency guidance calm and unambiguous. Clearly distinguish demo guidance from live medical or emergency services.

### Adaptability and inclusion

- Support Dynamic Type, VoiceOver, Increase Contrast, Reduce Motion, and system light/dark appearance unless a documented product decision requires otherwise.
- Do not encode status, trust, urgency, or selection with color alone; retain a textual or symbolic cue.
- Design layouts to reflow for larger type sizes, narrower widths, and longer localized text. Avoid truncating safety-critical content.
- Respect privacy by requesting permissions only in context and explaining their value before invoking a system prompt.
