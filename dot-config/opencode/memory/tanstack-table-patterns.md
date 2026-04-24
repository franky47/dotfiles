# TanStack Table Patterns & Gotchas

## Using TanStack Table in React Server Components (No `'use client'`)

**Date:** 2026-02-23  
**Context:** nuqs-workshop — Next.js 16 App Router, rendering data tables in RSC without client-side hooks

### Problem

`useReactTable` is a React hook — it cannot be used in server components. The standard shadcn `DataTable` pattern requires `'use client'`.

### Solution: `createTable` from `@tanstack/table-core`

Use the vanilla JS `createTable` API (re-exported by `@tanstack/react-table`) to create a table instance synchronously without React hooks:

```tsx
import { createTable, getCoreRowModel } from '@tanstack/react-table'

const table = createTable({
  columns,
  data,
  getCoreRowModel: getCoreRowModel(),
  state: {},
  onStateChange: () => {},
  renderFallbackValue: null,
})
```

### CRITICAL: State Initialization Gotcha

After calling `createTable()`, you **MUST** call `table.setOptions()` to merge `table.initialState`:

```tsx
table.setOptions((prev) => ({
  ...prev,
  state: { ...table.initialState },
}))
```

**Without this**, `getState()` returns the empty `{}` you passed in, and built-in features (column pinning, visibility, etc.) crash because their state properties are `undefined`.

**Error symptom:** `Cannot read properties of undefined (reading 'left')` from `getHeaderGroups()`.

**Why this works:** This mirrors what `useReactTable` does internally — it creates the table, then immediately merges `table.initialState` with the user-provided state via `setOptions`.

---

## RSC-Compatible TanStack Table APIs

**Date:** 2026-02-23  
**Context:** Identifying which TanStack Table exports work without `'use client'`

| API                  | RSC-safe? | Notes                               |
| -------------------- | --------- | ----------------------------------- |
| `createTable`        | ✅        | Vanilla JS, no hooks                |
| `flexRender`         | ✅        | No hooks internally                 |
| `createColumnHelper` | ✅        | Type helper only, no runtime hooks  |
| `getCoreRowModel`    | ✅        | Pure function, works server-side    |
| `useReactTable`      | ❌        | React hook, requires `'use client'` |
