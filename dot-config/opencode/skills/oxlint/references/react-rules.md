# React and React Hooks Rules

Comprehensive guide to React-specific linting rules in oxlint.

## Rules of Hooks

### Rule: `react/rules-of-hooks`

Enforces the Rules of Hooks to ensure hooks are called consistently.

**The Rules:**
1. Only call hooks at the top level (not in loops, conditions, or nested functions)
2. Only call hooks from React function components or custom hooks

#### Conditional Hook Call

❌ **Wrong:**
```tsx
function Component({ condition }) {
  if (condition) {
    const [value, setValue] = useState(0)  // Error!
  }
}
```

✅ **Correct:**
```tsx
function Component({ condition }) {
  const [value, setValue] = useState(condition ? 0 : null)
}
```

#### Hook in Loop

❌ **Wrong:**
```tsx
function Component({ items }) {
  for (let i = 0; i < items.length; i++) {
    const [value, setValue] = useState(items[i])  // Error!
  }
}
```

✅ **Correct:**
```tsx
function Component({ items }) {
  const [values, setValues] = useState(items)
}
```

#### Hook in Nested Function

❌ **Wrong:**
```tsx
function Component() {
  function handleClick() {
    const [count, setCount] = useState(0)  // Error!
  }
}
```

✅ **Correct:**
```tsx
function Component() {
  const [count, setCount] = useState(0)
  
  function handleClick() {
    setCount(c => c + 1)
  }
}
```

#### Invalid Hook Name

❌ **Wrong:**
```tsx
function notAHook() {
  const [value, setValue] = useState('')  // Error! Not a valid hook name
}
```

✅ **Correct:**
```tsx
function useMyHook() {
  const [value, setValue] = useState('')
  return [value, setValue]
}
```

#### Hook at Top Level

❌ **Wrong:**
```tsx
const value = useState(0)  // Error! Not in a component or hook
```

✅ **Correct:**
```tsx
function Component() {
  const [value, setValue] = useState(0)
}
```

## Exhaustive Dependencies

### Rule: `react/exhaustive-deps`

Ensures all dependencies are included in hook dependency arrays.

❌ **Wrong:**
```tsx
function Component({ userId }) {
  const [data, setData] = useState(null)
  
  useEffect(() => {
    fetchUser(userId).then(setData)
  }, [])  // Error! Missing dependency: userId
}
```

✅ **Correct:**
```tsx
function Component({ userId }) {
  const [data, setData] = useState(null)
  
  useEffect(() => {
    fetchUser(userId).then(setData)
  }, [userId])
}
```

**Common patterns:**

```tsx
// Stable functions don't need to be in deps
const stableFunc = useCallback(() => {
  doSomething()
}, [])

useEffect(() => {
  stableFunc()
}, [stableFunc])  // Can be omitted if wrapped in useCallback

// Intentionally empty deps (only on mount)
useEffect(() => {
  // Initialization that should only run once
  const socket = connectToSocket()
  return () => socket.disconnect()
}, [])  // Intentional - add comment to explain
```

## JSX Key Prop

### Rule: `react/jsx-key`

Ensures elements in arrays/iterators have a unique `key` prop.

❌ **Wrong:**
```tsx
function List({ items }) {
  return (
    <ul>
      {items.map((item) => (
        <li>{item.name}</li>  // Error! Missing key
      ))}
    </ul>
  )
}
```

✅ **Correct:**
```tsx
function List({ items }) {
  return (
    <ul>
      {items.map((item) => (
        <li key={item.id}>{item.name}</li>
      ))}
    </ul>
  )
}
```

**Key guidelines:**
- Use stable, unique identifiers (IDs from database)
- Avoid array indices as keys (unless list never reorders)
- Keys must be unique among siblings (not globally)

## Dangerous Properties

### Rule: `react/no-danger`

Warns about `dangerouslySetInnerHTML` usage.

❌ **Avoid:**
```tsx
function Component({ html }) {
  return <div dangerouslySetInnerHTML={{ __html: html }} />
}
```

✅ **Safer alternatives:**
```tsx
// Option 1: Use markdown parser
import { marked } from 'marked'

function Component({ markdown }) {
  return <div>{marked(markdown)}</div>
}

// Option 2: Sanitize HTML
import DOMPurify from 'dompurify'

function Component({ html }) {
  const clean = DOMPurify.sanitize(html)
  return <div dangerouslySetInnerHTML={{ __html: clean }} />
}
```

## Button Type

### Rule: `react/button-has-type`

Enforces explicit `type` attribute on `<button>` elements.

❌ **Wrong:**
```tsx
<button onClick={handleClick}>Submit</button>
```

✅ **Correct:**
```tsx
<button type="button" onClick={handleClick}>Submit</button>
<button type="submit">Submit Form</button>
<button type="reset">Reset</button>
```

**Why:** Buttons in forms default to `type="submit"`, which can cause unexpected form submissions.

## Array Index as Key

### Rule: `react/no-array-index-key`

Warns against using array index as key prop.

❌ **Avoid:**
```tsx
items.map((item, index) => (
  <li key={index}>{item}</li>
))
```

✅ **Better:**
```tsx
items.map((item) => (
  <li key={item.id}>{item}</li>
))
```

**When index keys are OK:**
- Static list that never changes
- Items have no unique identifiers
- List is never reordered, filtered, or paginated

## Target Blank Security

### Rule: `react/jsx-no-target-blank`

Prevents security vulnerability with `target="_blank"`.

❌ **Wrong:**
```tsx
<a href="https://external.com" target="_blank">
  Link
</a>
```

✅ **Correct:**
```tsx
<a href="https://external.com" target="_blank" rel="noopener noreferrer">
  Link
</a>
```

**Why:** Without `rel="noopener noreferrer"`, the linked page can access `window.opener` and potentially redirect the original page.

## React Fragment Shorthand

### Rule: `react/jsx-fragments`

Prefer `<>` over `<React.Fragment>` when keys aren't needed.

❌ **Verbose:**
```tsx
<React.Fragment>
  <Child1 />
  <Child2 />
</React.Fragment>
```

✅ **Better:**
```tsx
<>
  <Child1 />
  <Child2 />
</>
```

**Exception - when keys are needed:**
```tsx
items.map((item) => (
  <React.Fragment key={item.id}>
    <dt>{item.term}</dt>
    <dd>{item.definition}</dd>
  </React.Fragment>
))
```

## Recommended React Configuration

```json
{
  "plugins": ["react", "react-perf"],
  "rules": {
    "react/rules-of-hooks": "error",
    "react/exhaustive-deps": "error",
    "react/jsx-key": "error",
    "react/no-danger": "warn",
    "react/button-has-type": "warn",
    "react/no-array-index-key": "warn",
    "react/jsx-no-target-blank": "error",
    "react/jsx-fragments": "warn"
  }
}
```

## Performance Rules (react-perf plugin)

```json
{
  "plugins": ["react-perf"],
  "rules": {
    "react-perf/jsx-no-new-object-as-prop": "warn",
    "react-perf/jsx-no-new-array-as-prop": "warn",
    "react-perf/jsx-no-new-function-as-prop": "warn"
  }
}
```

These catch common performance pitfalls:

❌ **Problematic:**
```tsx
<Component
  style={{ margin: 10 }}  // New object every render
  items={[1, 2, 3]}       // New array every render
  onClick={() => {}}       // New function every render
/>
```

✅ **Optimized:**
```tsx
const style = { margin: 10 }
const items = [1, 2, 3]
const handleClick = () => {}

<Component
  style={style}
  items={items}
  onClick={handleClick}
/>
```
