# Prototype Instructions

Run the local server yourself and open the preview in the browser available to this environment. Do not give the user server-start instructions when you can run it.

Before making substantial visual changes, use the Product Design plugin's `get-context` skill when the visual source is unclear or no longer matches the current goal. When the user gives durable prototype-specific design feedback, preferences, or decisions, record them in `AGENTS.md`.

When implementing from a selected generated mock, treat that image as the source of truth for layout, component anatomy, density, spacing, color, typography, visible content, and hierarchy.

## Snoots website design decisions

- Mirror the Xcode `Snoots! iOS Design System` tokens on the website: SF Pro Rounded-style typography; ink `#222222`; canvas `#F7F7F4`; surface `#FFFFFF`; lavender `#B8A1FF`; lime `#C7F36B`; 20 px buttons, 28 px cards, 18 px compact controls, and 24 px media corners.
- Use rounded, 2 px line icons with explicit accessible labels for icon-only actions, and keep interactive targets at least 44 × 44 px.
- The hero product film starts automatically without sound unless Reduce Motion is enabled. Keep the hero copy visible during ambient playback; only reveal the focused player and hide the copy after the user taps the film or its introduction controls.
