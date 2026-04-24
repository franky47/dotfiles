# Drizzle ORM Patterns & Gotchas

## libsql / SQLite Local File URL Scheme

**Date:** 2026-02-23  
**Context:** nuqs-workshop — Next.js 16, Drizzle ORM, SQLite via `@libsql/client`, Bun

The `@libsql/client` driver **requires** the `file:` URI prefix for local SQLite paths.

```env
# .env — CORRECT
DB_FILE_NAME=file:./db/app.db

# WRONG — causes URL_INVALID error at runtime
DB_FILE_NAME=./db/app.db
```

The driver passes this value directly to libsql, which only accepts `file:`, `http:`, `https:`, `ws:`, or `wss:` schemes. A bare path causes an `URL_INVALID` error with no other hint.

---

## `default(sql\`CURRENT_TIMESTAMP\`)`vs`default('CURRENT_TIMESTAMP')`

**Date:** 2026-02-23  
**Context:** Drizzle schema column defaults for timestamps

Using a plain string literal stores the **literal text** `"CURRENT_TIMESTAMP"` as the default value — SQLite never evaluates it.

To have SQLite evaluate the expression at insert time, wrap it in the `sql` template tag:

```ts
import { sql } from 'drizzle-orm'
import { text } from 'drizzle-orm/sqlite-core'

// WRONG — stores the string "CURRENT_TIMESTAMP"
createdAt: text('created_at').default('CURRENT_TIMESTAMP')

// CORRECT — SQLite evaluates CURRENT_TIMESTAMP at insert time
createdAt: text('created_at').default(sql`CURRENT_TIMESTAMP`)
```

This applies to any SQL keyword or function used as a default (e.g. `CURRENT_DATE`, `(datetime('now'))`, etc.).

---

## `.$type<>()` Ordering in Column Chains

**Date:** 2026-02-23  
**Context:** Drizzle column builder method chaining, TypeScript inference

Place `.$type<>()` **before** `.default()` (and other modifiers) in the chain for best TypeScript inference. Putting it after `.default()` can cause the inferred type to widen unexpectedly.

```ts
// PREFERRED
status: text('status').$type<Status>().notNull().default('active')

// AVOID — type inference may be less precise
status: text('status').notNull().default('active').$type<Status>()
```

---

## SQLite Booleans: `int({ mode: 'boolean' })`

**Date:** 2026-02-23  
**Context:** Drizzle SQLite schema, boolean columns

SQLite has no native boolean type — values are stored as integers (`0` / `1`). Drizzle provides a mapping via `int` with `mode: 'boolean'`:

```ts
import { int } from 'drizzle-orm/sqlite-core'

// TypeScript sees `boolean`; DB stores 0 or 1
isActive: int('is_active', { mode: 'boolean' }).notNull().default(false)
```

Without `{ mode: 'boolean' }`, the column is typed as `number` and you must handle `0`/`1` manually.

---

## `drizzle-kit push` Idempotency Limitation (SQLite)

**Date:** 2026-02-23  
**Context:** Drizzle migrations with `drizzle-kit push` on SQLite

Re-running `drizzle-kit push` on an already-pushed SQLite schema can fail with an **"index already exists"** error even when no structural changes were made. This is a known limitation of push mode for SQLite — the tool may re-emit index creation SQL without checking for existence first.

**Safe to ignore** when:

- The schema has not structurally changed
- The error is only about index creation, not table structure

**Workaround:**

- Delete the SQLite file and re-push for a clean slate in development
- Or use `drizzle-kit generate` + `migrate` instead of `push` for more reliable idempotency in CI/production

---

## Custom Column Types for Runtime Value Mapping (`customType`)

**Date:** 2026-02-23  
**Context:** nuqs-workshop — mapping `Date` ↔ `text` in SQLite with Drizzle ORM

`.$type<T>()` **only changes the TypeScript type** — it does NOT transform values at runtime. Methods like `.mapToDriverValue()` do not exist on builder chains. To perform actual value transformation (e.g. `Date` ↔ `string`), use `customType`:

```ts
import { customType } from 'drizzle-orm/sqlite-core'

const dateColumn = customType<{ data: Date; driverData: string }>({
  dataType() {
    return 'text'
  },
  toDriver(value) {
    /* Date → string written to DB */
    const year = value.getFullYear()
    const month = String(value.getMonth() + 1).padStart(2, '0')
    const day = String(value.getDate()).padStart(2, '0')
    return `${year}-${month}-${day}`
  },
  fromDriver(value) {
    /* string read from DB → Date */
    return new Date(value + 'T00:00:00Z')
  },
})

// Usage in table schema
export const usersTable = sqliteTable('users', {
  birthDate: dateColumn('birth_date').notNull(),
})
```

**Imports:** `customType` lives in `drizzle-orm/sqlite-core` (or `drizzle-orm/pg-core`, `drizzle-orm/mysql-core` for other drivers).

---

## Date-Only Timezone Safety (YYYY-MM-DD ↔ `Date`)

**Date:** 2026-02-23  
**Context:** Storing date-only values in SQLite; timezone-safe serialisation

`date.toISOString()` converts to **UTC first**, which can shift the calendar date by ±1 day depending on the local timezone. When storing date-only values, build the string from local-time components:

```ts
// SAFE — uses local date parts, no UTC conversion
toDriver(value: Date): string {
  const year = value.getFullYear()
  const month = String(value.getMonth() + 1).padStart(2, '0')
  const day = String(value.getDate()).padStart(2, '0')
  return `${year}-${month}-${day}`
}

// SAFE — parse as UTC midnight to avoid off-by-one on read
fromDriver(value: string): Date {
  return new Date(value + 'T00:00:00Z')
}
```

---

## ISO-8601 UTC Default for Timestamps in SQLite

**Date:** 2026-02-23  
**Context:** Drizzle SQLite timestamp columns with UTC defaults

`CURRENT_TIMESTAMP` returns `YYYY-MM-DD HH:MM:SS` with **no timezone marker**, which `new Date()` parses as **local time** — not UTC. For a proper ISO-8601 UTC default use `strftime`:

```ts
import { sql } from 'drizzle-orm'
import { text } from 'drizzle-orm/sqlite-core'

// Returns e.g. "2026-02-23T14:05:00Z" — unambiguously UTC
createdAt: text('created_at').default(
  sql`(strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))`,
)
```
