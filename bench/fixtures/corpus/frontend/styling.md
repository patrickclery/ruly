---
paths:
  - "**/*.css"
  - "**/*.tsx"
---
# Styling

Styles should be predictable, local to their component and built from the shared design tokens.

## Design tokens

Use the design tokens for colors, spacing, font sizes, radii and shadows. Never hard-code a hex color or a pixel value that a token already covers. If you need a value that has no token, raise it with the design team rather than inventing one; the token set is how the product stays consistent.

## Scope

Each component's styles live in a module next to the component and apply only to that component. Global styles are limited to the reset, typography defaults and the token definitions. Do not style another component's internals from the outside; add a prop or a variant instead.

## Layout

- Use flexbox and grid for layout, not floats or absolute positioning.
- Use the spacing scale for margins and gaps, and prefer gap on the parent over margins on children.
- Design mobile first: base styles target small screens, and media queries add layout for larger ones.

## States

Every interactive element has visible hover, focus and disabled states. Focus styles are never removed without a replacement that is at least as visible.

## Dark mode

Colors come from semantic tokens such as surface, text and border, which switch between light and dark themes. Check every new screen in both themes before requesting review.

## Naming

Class names in style modules describe what the element is, not how it looks: a name like priceLabel survives a redesign, while redBoldText does not.

## Removing styles

When a component is deleted, delete its styles in the same change. Unused rules accumulate quietly and make every later change riskier, because nobody knows what still depends on them. Run the unused style check before requesting review.
