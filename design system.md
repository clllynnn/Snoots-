# Snoots! iOS Design System

Version: 2.0  
Direction: Bright, trusted, urban-pet utility. Native iOS usability with playful editorial moments.

## 1. Principles

- Keep the canvas clean and light. White is the default screen and card surface.
- Use bright color as a signal, not decoration: lime for discovery and verification, sky blue for calm action, butter for warmth, pink and lilac for social accents.
- Use oversized rounded display type sparingly: once per screen, never for dense instructions.
- Prioritize crisp dark type and icons over low-contrast color-on-color treatments.
- Use photo-led or clearly replaceable photo-style hero tiles for pets and venues. Do not use gradients.
- Care is the exception: it should feel calm, spacious, and direct even though it shares the brand palette.

## 2. Color Tokens

| Token | Value | Primary use |
|---|---:|---|
| canvas | #FFFFFC | Screen background |
| surface | #FFFFFF | Cards, sheets, controls |
| ink | #14141A | Primary text and icons |
| secondaryText | System secondary label | Supporting copy and metadata |
| pink | #FF4085 | Social actions, favorites, selected social state |
| softPink | #FFE3F0 | Soft social chips and inactive progress |
| lilac | #B885FF | Community and secondary accent |
| deepLilac | #4A2E7A | Trusted-community emphasis |
| sky | #52ADFF | Photo-tile blue and energetic discovery surfaces |
| careBlue | #146EE0 | Care primary action and Care icon enclosure |
| careTint | #E3F0FF | Care guidance surface |
| lime | #C7FF3D | Verification, availability, map discovery |
| butter | #FFE891 | Warm labels, headings within hero tiles |
| alert | #B31C40 | DEMO safety notice text only |

### Color use rules

- Keep text on canvas, surface, lime, and butter in ink.
- Use white text only on sufficiently saturated pink or careBlue actions.
- Do not use dark page backgrounds, muddy neutrals, or gradients.
- Do not use alert for a primary action; it is reserved for the Care disclaimer.

## 3. Typography

Use Nunito for friendly, premium display typography and Inter for clean, highly legible interface text. This pairing gives Snoots! warmth in its editorial moments while keeping dense utility and Care content crisp and accessible.

| Token | Font & treatment | Use |
|---|---|---|
| display | Nunito, 34–40 pt, Black (900) | App name and one primary screen title |
| screenTitle | Nunito, 34 pt, Bold (700) | Playdates, Care, Places |
| sectionTitle | Nunito, 20 pt, Bold (700) | Feed and content sections |
| cardTitle | Nunito, 17–20 pt, Bold (700) | Pet, venue, and Care step titles |
| body | Inter, 15–17 pt, Regular (400) | Instructions and post copy |
| metadata | Inter, 12–13 pt, Medium (500) | Time, distance, verification date |
| chip | Inter, 11–12 pt, Medium (500) | Tabs, category pills, behavioral declarations, and venue rules |

### Type rules

- Use Nunito's rounded, inviting forms for headings only; keep primary titles short and do not force long sentences into display type.
- Use Inter for all small, dense, functional, and safety-critical copy to maximize readability.
- Set tabs and category pills in Inter Medium (500). Prefer Title Case; all caps is acceptable only when space is very limited and tracking remains readable.
- Use sentence case for instructions and labels. Use all caps only for compact safety/status labels such as DEMO GUIDANCE ONLY.
- Safety and handoff instructions must use Inter body text with generous line spacing, never decorative type.

## 4. Layout, Spacing, and Geometry

| Token | Value | Use |
|---|---:|---|
| screenInset | 18 pt | Primary horizontal inset |
| spaceXS | 4 pt | Title/subtitle gap |
| spaceS | 8 pt | Tight metadata and chip spacing |
| spaceM | 12–16 pt | Card padding and standard component gaps |
| spaceL | 18–20 pt | Major content sections |
| cardRadius | 18–20 pt | Cards, hero tiles, map panel |
| smallRadius | 13–16 pt | Notices and internal rule rows |
| pillRadius | Capsule | Chips and primary actions only |
| iconRadius | Circle | Small utility and status icons |

- Keep cards rounded but not inflated. Use 18–20 pt, not oversized bubble corners.
- Use shadows only to separate white cards from white canvas: black at approximately 8% opacity, 10 pt blur, 4 pt vertical offset.
- Preserve clear iOS tap targets, with action controls at least 44 pt high.

## 5. Core Components

### 5.1 Photo-style hero tile

- Use as the lead visual in photo posts, Playdates, and venue detail.
- Use a flat bright background (sky, lilac, or butter) with a lime focal shape and a small camera indicator.
- The current tile is a replaceable placeholder; production imagery should use real, well-lit pet or venue photography.
- Keep the identifying label on a butter capsule and never overlay essential copy on a dark scrim.

### 5.2 Trust and declaration chips

- Small capsule with chip typography.
- Surface: softPink, butter, or a restrained lilac tint.
- Use for verified behavior, leash requirements, owner accountability, and venue micro-rules.
- Do not overload a card: show the three most useful declarations first.

### 5.3 White content cards

- Surface: white; text: ink; radius: cardRadius.
- Use for feed posts, owner accountability, clinic destination, and venue rows.
- Keep internal hierarchy clear with one title, one supporting line, and only the essential actions.

### 5.4 Primary action

- Full-width capsule, minimum 44 pt high, semibold or bold label.
- Use pink for Social, Playdates, and Places actions.
- Use careBlue for Care actions.
- Do not add decorative chevrons when the label already describes the action.

### 5.5 Care guidance card

- Surface: careTint; title and instruction in ink.
- Pair with the careBlue primary action and clear step progress.
- The DEMO disclaimer appears directly above the guidance card in alert text on a pale alert surface.
- Never imply live diagnosis, emergency dispatch, or medical certainty.

### 5.6 Places map and rule rows

- Use lime as the map base with clean white route lines and pink/blue location pins.
- Every venue row must expose its most consequential micro-rules before navigation to detail.
- Place detail uses short rule rows with an SF Symbol, direct rule copy, and a plain verification timestamp.

## 6. Navigation and States

- Four persistent tabs: Social, Playdates, Care, Places.
- Active tab uses the tab’s associated bright accent; inactive icons remain ink.
- Sheets remain white and use native navigation controls.
- Selected, saved, matched, and Care-progress states must be visible through both text and icon/color changes.

## 7. Accessibility Checklist

- Maintain strong ink/light-surface contrast.
- Do not convey trust, urgency, or selection through color alone; pair it with an SF Symbol or text.
- Support Dynamic Type without relying on fixed one-line safety instructions.
- Give all icon-only actions an accessibility label.
- Keep Care copy short, concrete, and visually separated into status, instruction, and next action.
