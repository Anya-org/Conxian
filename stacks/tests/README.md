# Testing Utilities

## Clarity Value Helpers (`utils/clarity-helpers.ts`)

This module provides utilities for parsing Clarity values returned by simnet calls, eliminating the need for manual parsing of nested value objects.

### Available Functions

#### `getUintValue(cv: any): number`
Extracts uint values from various Clarity value formats:
- Direct uint results: `{type:'uint', value:'200'}` → `200`
- Error responses: `{type:'err', value:{type:'uint', value:'307'}}` → `307`
- String values: `'u123'` → `123`
- Raw numbers: `123` → `123`
- Nested values and fallback JSON parsing

#### `getBoolValue(cv: any): boolean`
Extracts boolean values from Clarity results.

#### `getPrincipalValue(cv: any): string`
Extracts principal addresses from Clarity results.

#### `unwrapResult(result: any): any`
Safely unwraps ok/err response types, throwing descriptive errors for err cases.

### Usage Examples

#### Before (manual parsing):
```typescript
const result = simnet.callReadOnlyFn('contract', 'get-balance', [], user);
const balance = parseInt(result.value.value, 10); // Error-prone, assumes specific structure
```

#### After (using helpers):
```typescript
import { getUintValue } from '../utils/clarity-helpers';

const result = simnet.callReadOnlyFn('contract', 'get-balance', [], user);
const balance = getUintValue(result); // Handles multiple formats automatically
```

#### Error Handling:
```typescript
import { getUintValue } from '../utils/clarity-helpers';

const result = simnet.callPublicFn('contract', 'some-function', [], user);
if (result.type === 'err') {
  const errorCode = getUintValue(result.value); // Works for nested error structures
  expect([100, 101, 102]).toContain(errorCode);
}
```

### Migration Pattern

When updating existing tests:
1. Add import: `import { getUintValue } from '../utils/clarity-helpers';`
2. Replace manual parsing: `result.value.value` → `getUintValue(result)`
3. Update BigInt comparisons: `100n` → `100`
4. Test to ensure functionality is preserved

### Updated Test Files
- `automation_trigger_test.ts` - Full conversion with custom uint parsing
- `vault_shares_test.ts` - Deposit/withdraw value parsing  
- `bounty-system_test_modernized.ts` - Bounty amount and error code parsing
- `vault_autonomics_test.ts` - Fee value parsing

This standardization improves test readability, reduces parsing errors, and provides consistent handling of various Clarity value formats across the test suite.
