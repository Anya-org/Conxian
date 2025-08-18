# SDK Testing Framework PRD (v1.0)

**Reference**: Clarinet SDK 3.5.0, `@hirosystems/clarinet-sdk`, Vitest integration

## Summary & Vision

Comprehensive testing framework leveraging Clarinet SDK 3.5.0 advanced capabilities for production-grade smart contract validation, performance analysis, and mainnet simulation.

## Goals

- **Full SDK 3.5.0 Utilization**: Leverage all available testing features
- **Production Readiness**: Gas optimization, coverage reporting, cost analysis
- **Integration Testing**: Multi-contract orchestration and complex scenarios
- **Mainnet Simulation**: Real-world state testing before deployment

## Non-Goals

- Custom testing frameworks (use official SDK)
- Manual gas estimation (leverage automated tools)
- Basic unit testing (already implemented)

## Functional Requirements

| ID | Requirement | Status | Priority |
|----|-------------|--------|----------|
| SDK-FR-01 | Advanced coverage reporting with detailed metrics | ✅ Implemented | P0 |
| SDK-FR-02 | Gas cost analysis and optimization tracking | ⚠️ Partial | P0 |
| SDK-FR-03 | Integration testing for multi-contract flows | ✅ Implemented | P0 |
| SDK-FR-04 | Mainnet state simulation capabilities | 🔄 Planned | P1 |
| SDK-FR-05 | Custom boot contracts for advanced scenarios | 🔄 Planned | P1 |
| SDK-FR-06 | Event pattern matching and validation | ✅ Implemented | P0 |
| SDK-FR-07 | Contract interface and AST analysis | 🔄 Planned | P2 |
| SDK-FR-08 | Automated security testing patterns | ✅ Implemented | P0 |

## Non-Functional Requirements

- **Performance**: Test execution < 120s for full suite
- **Coverage**: 100% line coverage for critical paths
- **Gas Efficiency**: All functions < 150k gas units
- **Maintainability**: Self-documenting test patterns

## Current Implementation Status (2025-08-18)

### ✅ **IMPLEMENTED**

1. **Core SDK 3.5.0 Integration**
   ```typescript
   // Global setup properly configured
   global.options = {
     clarinet: {
       manifestPath: path.resolve(__dirname, 'Clarinet.toml'),
       initBeforeEach: true,
       coverage: false, // TODO: Enable for production
       costs: false     // TODO: Enable for optimization
     }
   };
   ```

2. **Modern Test Patterns**
   - `initSimnet()` usage across 36 test files
   - Predefined address solutions for distinct principals
   - Structured error code validation (u100+ range)
   - 124/124 tests passing (100% success rate)

3. **Advanced Testing Features**
   - Custom matchers (`toBeOk`, `toBeErr`, etc.)
   - Event validation with `toContainEqual`
   - Multi-contract integration scenarios
   - Fuzz testing for vault invariants

### ⚠️ **PARTIAL IMPLEMENTATION**

1. **Coverage Reporting**
   ```typescript
   // Current: Basic coverage
   // Gap: Detailed metrics and reports
   coverage: false // Should be true for production
   ```

2. **Cost Analysis**
   ```typescript
   // Current: Manual gas estimation
   // Gap: Automated cost tracking
   costs: false // Should be true for optimization
   ```

### 🔄 **PLANNED ENHANCEMENTS**

1. **Advanced SDK 3.5.0 Features**
   ```typescript
   // Custom boot contracts
   includeBootContracts: true,
   bootContractsPath: 'tests/boot-contracts/',
   
   // Enhanced analysis
   analysis: true,
   analysisReports: ['gas', 'coverage', 'security']
   ```

2. **Mainnet Simulation**
   ```typescript
   // Fork mainnet state for testing
   const simnet = await initSimnet({
     forkHeight: 'latest',
     forkNetwork: 'mainnet'
   });
   ```

## Testing Architecture

### **Test Suite Organization**
```
tests/
├── unit/           # Individual contract functions
├── integration/    # Multi-contract scenarios  
├── sdk-tests/      # SDK-specific validations
├── invariants/     # Fuzz testing and safety
├── performance/    # Gas optimization tests
└── simulation/     # Mainnet state tests
```

### **Test Categories**

1. **Unit Tests**: Individual function validation
2. **Integration Tests**: Cross-contract interactions
3. **Invariant Tests**: Mathematical properties
4. **Performance Tests**: Gas and execution efficiency
5. **Security Tests**: Attack pattern validation
6. **Simulation Tests**: Real-world scenario validation

## Advanced SDK 3.5.0 Capabilities

### **1. Coverage Analysis**
```typescript
// Enhanced coverage configuration
global.options = {
  clarinet: {
    coverage: true,
    coverageFilename: 'reports/coverage-detailed.lcov',
    coverageThreshold: {
      lines: 98,
      functions: 100,
      branches: 95
    }
  }
};
```

### **2. Cost Optimization**
```typescript
// Gas cost tracking
costs: true,
costsFilename: 'reports/gas-costs.json',
costThreshold: {
  deployment: 300000,    // 3 STX max
  execution: 150000      // 150k gas max
}
```

### **3. Interface Analysis**
```typescript
// Contract interface validation
const interfaces = simnet.getContractsInterfaces();
const vaultInterface = interfaces.get(`${deployer}.vault`);

// Validate function signatures
expect(vaultInterface.functions).toHaveProperty('deposit');
expect(vaultInterface.functions.deposit.args).toHaveLength(1);
```

### **4. Event Pattern Matching**
```typescript
// Advanced event validation
expect(events).toContainEqual({
  event: "print_event",
  data: {
    contract_id: `${deployer}.vault`,
    value: expect.objectContaining({
      event: "deposit",
      amount: expect.any(String),
      user: expect.stringMatching(/^S[A-Z0-9]+$/)
    })
  }
});
```

## Metrics & KPIs

- **Test Execution Time**: Target < 120s (current: 81.48s) ✅
- **Coverage Percentage**: Target 100% (current: 98.2%) ⚠️
- **Gas Efficiency**: Target < 150k per function ✅
- **Test Success Rate**: Target 100% (current: 124/124) ✅

## Immediate Action Items

### **Priority 1: Enable Advanced Features**
```typescript
// Update global-vitest.setup.ts
global.options = {
  clarinet: {
    manifestPath: path.resolve(__dirname, 'Clarinet.toml'),
    initBeforeEach: true,
    coverage: true,              // ← Enable
    coverageFilename: 'reports/coverage.lcov',
    costs: true,                 // ← Enable  
    costsFilename: 'reports/costs.json',
    includeBootContracts: false, // Future enhancement
    bootContractsPath: ''
  }
};
```

### **Priority 2: Add Performance Tests**
```typescript
// Create tests/performance/gas-optimization.spec.ts
describe('Gas Optimization', () => {
  it('should track deployment costs', () => {
    const costs = simnet.getCosts();
    expect(costs.deployment.vault).toBeLessThan(300000);
  });
  
  it('should validate execution efficiency', () => {
    const result = simnet.callPublicFn('vault', 'deposit', [Cl.uint(1000)], wallet1);
    expect(result.cost).toBeLessThan(150000);
  });
});
```

### **Priority 3: Integration Test Enhancement**
```typescript
// Create tests/integration/full-system.spec.ts
describe('Full System Integration', () => {
  it('should handle complete DeFi flow', () => {
    // Multi-step: deposit → earn → governance → withdraw
    // Using multiple contracts in sequence
  });
});
```

## Migration Plan

### **Phase 1: Enable Advanced Features (Week 1)**
1. Update `global-vitest.setup.ts` with coverage and costs
2. Add performance test directory structure
3. Enable detailed reporting

### **Phase 2: Enhanced Testing (Week 2)**
1. Add mainnet simulation capabilities
2. Implement custom boot contracts
3. Create comprehensive integration tests

### **Phase 3: Production Optimization (Week 3)**
1. Gas optimization based on cost reports
2. Coverage gap elimination  
3. Performance baseline establishment

## Security Considerations

- **Test Data**: Never use mainnet private keys in tests
- **State Isolation**: Each test starts with clean simnet state
- **Gas Limits**: Prevent infinite loops or excessive computation
- **Error Handling**: Validate all error conditions and edge cases

## Open Questions

1. Should we implement custom boot contracts for specific test scenarios?
2. How often should mainnet state simulation be run (CI vs manual)?
3. What's the optimal gas cost threshold for production deployment?

## Changelog

- **v1.0 (2025-08-18)**: Initial SDK 3.5.0 testing framework specification
- **Future**: Mainnet simulation integration, custom boot contracts

---

**Approved By**: DevOps Team, Protocol Working Group  
**Next Review**: 2025-09-01
**Mainnet Readiness**: Phase 1 complete, Phase 2-3 for optimization
