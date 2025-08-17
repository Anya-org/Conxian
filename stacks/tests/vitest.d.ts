/// <reference types="vitest" />
/// <reference types="@hirosystems/clarinet-sdk/vitest-helpers/src/global" />
/// <reference types="@hirosystems/clarinet-sdk/vitest-helpers/src/vitest" />

import 'vitest'

declare global {
  const simnet: import('@hirosystems/clarinet-sdk').Simnet;
}
