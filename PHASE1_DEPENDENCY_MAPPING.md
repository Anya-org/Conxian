# Phase 1 Dependency Mapping & Migration Plan

**Generated**: 2025-08-28T14:43:17+02:00  
**Status**: Modular rewrite in progress - Phase 1.2

---

## 📊 **MATH LIBRARY DEPENDENCY ANALYSIS**

### **Contracts Using Old Math Libraries**

| Contract | Current Dependency | Functions Used | Migration Priority |
|----------|-------------------|----------------|-------------------|
| `tick-math.clar` | `.math-lib-advanced.advanced-math-trait` | trait import only | **P1** |
| `stable-pool-enhanced.clar` | `.math-lib-enhanced` | `calculate-sqrt`, `calculate-slippage` | **P0** |
| `multi-hop-router-v3.clar` | `.math-lib-advanced.advanced-math-trait` | trait import only | **P1** |
| `fixed-point-math.clar` | `.math-lib-advanced.advanced-math-trait` | trait import only | **P2** |
| `concentrated-swap-logic.clar` | `.math-lib-advanced.advanced-math-trait` | trait import only | **P1** |
| `concentrated-liquidity-pool.clar` | `.math-lib-advanced.advanced-math-trait` | trait import only | **P1** |
| `precision-calculator.clar` | references `math-lib-advanced` | comment only | **P2** |
| `autovault-registry.clar` | registers `.math-lib-advanced` | registry entry | **P0** |

### **Migration Strategy**

#### **Phase 1a: Update Clarinet.toml (IMMEDIATE)**

- Add `math-lib-unified.clar` to deployment order
- Keep old math libs temporarily for compatibility
- Update contract dependencies gradually

#### **Phase 1b: High-Priority Migrations (P0)**

- `stable-pool-enhanced.clar` - Replace contract-call? with unified lib
- `autovault-registry.clar` - Update registry to point to unified lib

#### **Phase 1c: Medium-Priority Migrations (P1)**

- Update trait imports in concentrated liquidity contracts
- Update trait imports in routing contracts

#### **Phase 1d: Low-Priority Migrations (P2)**

- Clean up references and comments
- Remove deprecated libraries

---

## 🔧 **IMMEDIATE ACTIONS**

### **1. Update Clarinet.toml Configuration**

Add unified math library and update deployment order.

### **2. Migrate Critical Dependencies**

Start with contracts that have active function calls (not just trait imports).

### **3. Test Compatibility**

Ensure backward compatibility during transition period.

---

## 📋 **DETAILED MIGRATION TASKS**

### **Task 1: Update stable-pool-enhanced.clar**

**Current**: Uses `contract-call? .math-lib-enhanced`  
**Target**: Use `contract-call? .math-lib-unified`  
**Functions**: `calculate-sqrt`, `calculate-slippage`

### **Task 2: Update autovault-registry.clar**

**Current**: Registers `.math-lib-advanced`  
**Target**: Register `.math-lib-unified`  
**Impact**: System-wide math library reference

### **Task 3: Update trait imports**

**Contracts**: All contracts using `math-lib-advanced.advanced-math-trait`  
**Target**: Use `math-lib-unified.unified-math-trait`  
**Impact**: Compilation compatibility

---

## ✅ **SUCCESS CRITERIA**

- [ ] All contracts compile with unified math library
- [ ] No breaking changes to existing functionality  
- [ ] Performance improvements from consolidated library
- [ ] Reduced deployment gas costs
- [ ] Simplified maintenance and updates
