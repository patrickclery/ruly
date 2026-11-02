---
paths:
  - "**/*.tsx"
---
# React Components

Components are small, typed and predictable. A component should do one job and be easy to render in isolation.

## Exports

React components use named exports; never export default.

Named exports keep import names consistent across the codebase and make renames safe with editor tooling. Each component lives in its own file named after the component, in PascalCase, next to its stylesheet and its test.

## Props

- Type every component's props with an interface named after the component plus Props.
- Keep props flat and few. More than seven props usually means the component does too much.
- Pass callbacks named after the event, such as onSelect or onClose, not after what the parent will do.
- Avoid boolean props that switch between two different layouts; make two components instead.

## State

Keep state as close as possible to where it is used. Lift it only when two siblings need it. Derive values during render instead of copying props into state. Server data comes from the data-fetching layer, not from hand-written effects.

## Effects

Use effects only to synchronize with something outside React: a subscription, a timer, a browser API. Every effect that subscribes also cleans up. If an effect only computes a value from props, it should be a plain calculation during render.

## Composition

Prefer composition with children over configuration objects. A card that accepts a header, body and footer as children is easier to extend than one with twelve props.

## Testing

Test components through what the user sees: text, roles and labels. Avoid asserting on internal state or implementation details such as class names.

## Loading and errors

Every component that shows remote data handles three states: loading, error and empty. Show a skeleton rather than a spinner for content that has a known shape, and give error states a retry action and a short explanation in plain language.
