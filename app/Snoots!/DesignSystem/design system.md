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
