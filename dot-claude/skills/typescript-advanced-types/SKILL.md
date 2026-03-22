---
name: typescript-advanced-types
description: Master TypeScript's advanced type system including generics, conditional types, mapped types, template literals, and utility types for building type-safe applications. Use when implementing complex type logic, creating reusable type utilities, or ensuring compile-time type safety in TypeScript projects.
---

# TypeScript Advanced Types

Comprehensive guidance for mastering TypeScript's advanced type system including generics, conditional types, mapped types, template literal types, and utility types for building robust, type-safe applications.

## When to Use This Skill

- Building type-safe libraries or frameworks
- Creating reusable generic components
- Implementing complex type inference logic
- Designing type-safe API clients
- Building form validation systems
- Creating strongly-typed configuration objects
- Implementing type-safe state management
- Migrating JavaScript codebases to TypeScript

## Core Concepts

### 1. Generics

**Purpose:** Create reusable, type-flexible components while maintaining type safety.

**Basic Generic Function:**

function identity<T>(value: T): T {
  return value;
}

const num = identity<number>(42);
const str = identity<string>("hello");
const auto = identity(true); // Type inferred: boolean

> Note: using a single letter for trivial generics can be OK, but prefer giving generic arguments a relevant short name instead.

**Generic Constraints:**

type HasLength = {
  length: number;
}

function logLength<T extends HasLength>(item: T): T {
  console.log(item.length);
  return item;
}

**Multiple Type Parameters:**

function merge<T, U>(obj1: T, obj2: U): T & U {
  return { ...obj1, ...obj2 };
}

### 2. Conditional Types

type IsString<T> = T extends string ? true : false;
type ReturnType<Fn> = Fn extends (...args: any[]) => infer Return ? Return : never;
type ToArray<Item> = Item extends any ? Item[] : never;

### 3. Mapped Types

type Readonly<T> = { readonly [P in keyof T]: T[P] };
type Partial<T> = { [P in keyof T]?: T[P] };
type Getters<T> = { [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K] };
type PickByType<T, U> = { [K in keyof T as T[K] extends U ? K : never]: T[K] };

### 4. Template Literal Types

type EventName = "click" | "focus" | "blur";
type EventHandler = `on${Capitalize<EventName>}`;

### 5. Utility Types

Partial<T>, Required<T>, Readonly<T>, Pick<T, K>, Omit<T, K>, Exclude<T, U>, Extract<T, U>, NonNullable<T>, Record<K, T>

## Advanced Patterns

- Type-Safe Event Emitter
- Type-Safe API Client
- Builder Pattern with Type Safety
- Deep Readonly/Partial
- Type-Safe Form Validation
- Discriminated Unions

## Type Inference Techniques

- `infer` keyword for extracting types
- Type guards with `value is Type`
- Assertion functions with `asserts value is Type`

## Best Practices

1. Use `unknown` over `any`
2. Use `type` over `interface` for object shapes
3. Use `interface` for declaration-mergeable types (extensible in userland)
4. Leverage type inference
5. Create helper types for reuse
6. Use const assertions
7. Avoid type assertions — use type guards
8. Document complex types
9. Use strict mode
10. Test your types
