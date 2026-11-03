# Accessibility

Accessibility is a requirement, not a polish step. Every feature ships usable with a keyboard and a screen reader.

## Semantics

Use the right element for the job: a button for actions, a link for navigation, a heading hierarchy that matches the page structure, lists for lists. Native elements come with keyboard support and screen reader semantics for free. Reach for ARIA attributes only when no native element fits, and then follow the published authoring practices for that pattern.

## Keyboard

- Every interactive element is reachable with the tab key, in a logical order.
- Focus is always visible.
- Dialogs trap focus while open and return it to the trigger when closed.
- Custom widgets such as menus and tabs support the arrow keys expected for their role.

## Text alternatives

Images that carry meaning have alt text that says what the image shows in context. Decorative images have empty alt text. Icon-only buttons have an accessible label.

## Color and contrast

Text meets a contrast ratio of at least 4.5 to 1 against its background, and large text at least 3 to 1. Never use color alone to convey information; pair it with text or an icon.

## Forms

Every input has a visible label tied to it. Error messages appear next to the field, are announced to screen readers and say how to fix the problem.

## Motion

Respect the reduced motion preference. Animations that move large areas of the screen are disabled when it is set.

## Testing

Run the automated accessibility checker in the component tests, and do a manual keyboard pass on every new screen. Automated checks find roughly a third of problems; the keyboard pass finds many of the rest.

## Language and headings

Set the page language so screen readers pronounce content correctly. Every page has exactly one top-level heading that names the page, and heading levels never skip. Screen reader users navigate by headings, so the outline should read like a table of contents.
