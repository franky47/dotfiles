# Accessibility (a11y) Patterns and Fixes

Common accessibility issues detected by oxlint and how to fix them.

## Click Events on Non-Interactive Elements

### Rule: `jsx-a11y/click-events-have-key-events`

**Problem:** Click handlers on non-interactive elements (`div`, `span`) are not keyboard accessible.

❌ **Before:**
```tsx
<div onClick={handleClick}>
  Click me
</div>
```

✅ **Fix Option 1: Make it keyboard accessible**
```tsx
<div
  tabIndex={0}
  onClick={handleClick}
  onKeyDown={(e) => {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault()
      handleClick(e)
    }
  }}
>
  Click me
</div>
```

✅ **Fix Option 2: Use semantic HTML (preferred)**
```tsx
<button onClick={handleClick}>
  Click me
</button>
```

**Why:** Keyboard-only users cannot trigger click events on non-interactive elements. Adding `tabIndex={0}` and keyboard handlers makes it accessible.

## Missing Alternative Text

### Rule: `jsx-a11y/alt-text`

❌ **Before:**
```tsx
<img src="/photo.jpg" />
```

✅ **Fix:**
```tsx
// For meaningful images
<img src="/photo.jpg" alt="A sunset over mountains" />

// For decorative images
<img src="/decoration.png" alt="" />
```

**Why:** Screen readers need alt text to describe images to users who can't see them.

## Redundant Alt Text

### Rule: `jsx-a11y/img-redundant-alt`

❌ **Before:**
```tsx
<img src="/photo.jpg" alt="Photo of a cat" />
<img src="/image.jpg" alt="Image showing sunset" />
```

✅ **Fix:**
```tsx
<img src="/photo.jpg" alt="A cat sleeping on a windowsill" />
<img src="/image.jpg" alt="Sunset over mountains" />
```

**Why:** Screen readers already announce "image", so don't include words like "photo", "image", or "picture" in alt text.

## Static Element Interactions

### Rule: `jsx-a11y/no-static-element-interactions`

❌ **Before:**
```tsx
<div onClick={handleClick} onKeyPress={handleKeyPress}>
  Interactive element
</div>
```

✅ **Fix:**
```tsx
<button onClick={handleClick}>
  Interactive element
</button>
```

**Why:** Use semantic interactive elements instead of making static elements interactive.

## Missing Form Labels

### Rule: `jsx-a11y/label-has-associated-control`

❌ **Before:**
```tsx
<label>Username</label>
<input type="text" />
```

✅ **Fix Option 1: Wrap input**
```tsx
<label>
  Username
  <input type="text" />
</label>
```

✅ **Fix Option 2: Use htmlFor**
```tsx
<label htmlFor="username">Username</label>
<input id="username" type="text" />
```

## ARIA Attributes

### Rule: `jsx-a11y/aria-props`

❌ **Before:**
```tsx
<div aria-labelledby="nonexistent-id">Content</div>
<button aria-pressed="yes">Toggle</button>
```

✅ **Fix:**
```tsx
<div aria-labelledby="heading-id">Content</div>
<h2 id="heading-id">Heading</h2>

<button aria-pressed={isPressed ? "true" : "false"}>Toggle</button>
```

**Why:** ARIA attributes must be valid and properly formatted. Boolean values must be strings.

## Anchor Links

### Rule: `jsx-a11y/anchor-is-valid`

❌ **Before:**
```tsx
<a href="#">Click</a>
<a href="javascript:void(0)">Click</a>
```

✅ **Fix:**
```tsx
<button onClick={handleClick}>Click</button>

// Or for actual links:
<a href="/destination">Navigate</a>
```

## Role Attributes

### Rule: `jsx-a11y/aria-role`

❌ **Before:**
```tsx
<div role="invalid-role">Content</div>
<button role="link">Click</button>
```

✅ **Fix:**
```tsx
<div role="region">Content</div>
<a href="/page">Navigate</a>
```

**Why:** Use valid ARIA roles and prefer semantic HTML over role attributes.

## Common Pattern: Interactive List Items

❌ **Before:**
```tsx
<ul>
  {items.map((item) => (
    <li key={item.id} onClick={() => handleClick(item.id)}>
      {item.name}
    </li>
  ))}
</ul>
```

✅ **Fix:**
```tsx
<ul>
  {items.map((item) => (
    <li key={item.id}>
      <button onClick={() => handleClick(item.id)}>
        {item.name}
      </button>
    </li>
  ))}
</ul>
```

## Common Pattern: Icon Buttons

❌ **Before:**
```tsx
<button>
  <SearchIcon />
</button>
```

✅ **Fix:**
```tsx
<button aria-label="Search">
  <SearchIcon aria-hidden="true" />
</button>
```

**Why:** Icon-only buttons need text alternatives for screen readers.

## Configuring a11y Rules

Recommended configuration:

```json
{
  "plugins": ["jsx-a11y"],
  "rules": {
    "jsx-a11y/alt-text": "warn",
    "jsx-a11y/click-events-have-key-events": "warn",
    "jsx-a11y/no-static-element-interactions": "warn",
    "jsx-a11y/aria-props": "error",
    "jsx-a11y/aria-role": "error",
    "jsx-a11y/label-has-associated-control": "warn",
    "jsx-a11y/anchor-is-valid": "error",
    "jsx-a11y/img-redundant-alt": "warn"
  }
}
```

## Testing Accessibility

After fixes, test with:

1. **Keyboard navigation** - Tab through all interactive elements
2. **Screen reader** - Use VoiceOver (Mac) or NVDA (Windows)
3. **axe DevTools** - Browser extension for automated testing

## Resources

- [MDN Accessibility Guide](https://developer.mozilla.org/en-US/docs/Web/Accessibility)
- [WCAG Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [ARIA Authoring Practices](https://www.w3.org/WAI/ARIA/apg/)
