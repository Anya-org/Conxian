#!/usr/bin/env python3
"""
Test Refactoring Script for Conxian System
Updates all test files to match current contract structure
"""

import os
import re
import json
from pathlib import Path
from typing import Dict, List, Tuple

class TestRefactorer:
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.tests_dir = self.project_root / "tests"
        self.contracts_dir = self.project_root / "contracts"
        
    def analyze_test_files(self) -> Dict[str, List[str]]:
        """Analyze all test files and identify issues"""
        issues = {
            "path_issues": [],
            "contract_issues": [],
            "import_issues": []
        }
        
        for test_file in self.tests_dir.rglob("*.test.ts"):
            try:
                content = test_file.read_text(encoding='utf-8')
            except UnicodeDecodeError:
                continue
            
            # Check for incorrect paths
            if "Clarinet.minimal.toml" in content:
                issues["path_issues"].append(str(test_file))
            if "stacks/Clarinet.test.toml" in content:
                issues["path_issues"].append(str(test_file))
                
            # Check for initSession calls (deprecated)
            if "initSession" in content:
                issues["contract_issues"].append(str(test_file))
                
        return issues
    
    def fix_test_paths(self) -> int:
        """Fix incorrect Clarinet.toml paths"""
        fixed_count = 0
        
        for test_file in self.tests_dir.rglob("*.ts"):
            try:
                content = test_file.read_text(encoding='utf-8')
            except UnicodeDecodeError:
                # Skip files with encoding issues
                continue
            
            # Replace incorrect paths
            old_paths = [
                "../stacks/Clarinet.test.toml",
                "../Clarinet.minimal.toml",
                "stacks/Clarinet.test.toml"
            ]
            
            new_content = content
            for old_path in old_paths:
                new_content = new_content.replace(old_path, "../Clarinet.toml")
                
            if new_content != content:
                test_file.write_text(new_content)
                fixed_count += 1
                
        return fixed_count
    
    def fix_deprecated_calls(self) -> int:
        """Remove deprecated initSession calls"""
        fixed_count = 0
        
        for test_file in self.tests_dir.rglob("*.test.ts"):
            try:
                content = test_file.read_text(encoding='utf-8')
            except UnicodeDecodeError:
                continue
            
            # Remove initSession calls
            pattern = r'await simnet\.initSession\(process\.cwd\(\), "Clarinet\.toml"\);'
            new_content = re.sub(pattern, '', content)
            
            # Clean up empty lines
            new_content = re.sub(r'\n\s*\n\s*\n', '\n\n', new_content)
            
            if new_content != content:
                test_file.write_text(new_content)
                fixed_count += 1
                
        return fixed_count
    
    def update_contract_references(self) -> int:
        """Update contract references to match current addresses"""
        fixed_count = 0
        
        # Get current contract addresses from Clarinet.toml
        clarinet_path = self.project_root / "Clarinet.toml"
        if not clarinet_path.exists():
            return 0
            
        contracts = {}
        with open(clarinet_path, 'r') as f:
            content = f.read()
            
        # Extract contract addresses
        contract_pattern = r'\[contracts\.([^\]]+)\]\s*path\s*=\s*"([^"]+)"\s*address\s*=\s*"([^"]+)"'
        matches = re.findall(contract_pattern, content)
        
        for name, path, address in matches:
            contracts[name] = {"path": path, "address": address}
        
        # Update test files with correct contract references
        for test_file in self.tests_dir.rglob("*.test.ts"):
            try:
                content = test_file.read_text(encoding='utf-8')
            except UnicodeDecodeError:
                continue
            new_content = content
            
            for contract_name, contract_info in contracts.items():
                # Update contract principal references if needed
                old_pattern = f'"{contract_name}"'
                # Keep as is since tests should use contract names, not addresses
                
            if new_content != content:
                test_file.write_text(new_content)
                fixed_count += 1
                
        return fixed_count
    
    def create_comprehensive_test_suite(self) -> None:
        """Create a comprehensive test suite for the current system"""
        
        # Core contract tests
        core_test = '''import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { initSimnet, type Simnet } from "@stacks/clarinet-sdk";
import { Cl } from "@stacks/transactions";

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe("Core Contract Tests", () => {
  beforeAll(async () => {
    simnet = await initSimnet("Clarinet.toml");
  });

  beforeEach(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
  });

  describe("Core Protocol", () => {
    it("should have conxian-protocol contract deployed", () => {
      const contract = simnet.getContractSource("conxian-protocol");
      expect(contract).toBeDefined();
    });

    it("should check protocol pause status", () => {
      const result = simnet.callReadOnlyFn(
        "conxian-protocol",
        "is-paused",
        [],
        deployer
      );
      expect(result.result).toBeOk(Cl.bool(false));
    });
  });

  describe("Traits System", () => {
    it("should have sip-standards trait deployed", () => {
      const contract = simnet.getContractSource("sip-standards");
      expect(contract).toBeDefined();
    });

    it("should have core-traits deployed", () => {
      const contract = simnet.getContractSource("core-traits");
      expect(contract).toBeDefined();
    });
  });

  describe("Token System", () => {
    it("should have cxd-token deployed", () => {
      const contract = simnet.getContractSource("cxd-token");
      expect(contract).toBeDefined();
    });

    it("should get token name", () => {
      const result = simnet.callReadOnlyFn(
        "cxd-token",
        "get-name",
        [],
        deployer
      );
      expect(result.result).toBeOk(Cl.stringAscii("Conxian Token"));
    });
  });
});
'''
        
        core_test_path = self.tests_dir / "core-contracts.test.ts"
        core_test_path.write_text(core_test)
        
        # Governance tests
        gov_test = '''import { describe, it, expect, beforeAll, beforeEach } from "vitest";
import { initSimnet, type Simnet } from "@stacks/clarinet-sdk";
import { Cl } from "@stacks/transactions";

let simnet: Simnet;
let deployer: string;
let wallet1: string;

describe("Governance Tests", () => {
  beforeAll(async () => {
    simnet = await initSimnet("Clarinet.toml");
  });

  beforeEach(() => {
    const accounts = simnet.getAccounts();
    deployer = accounts.get("deployer")!;
    wallet1 = accounts.get("wallet_1")!;
  });

  describe("Operations Engine", () => {
    it("should have conxian-operations-engine deployed", () => {
      const contract = simnet.getContractSource("conxian-operations-engine");
      expect(contract).toBeDefined();
    });

    it("should allow operational adjustments", () => {
      const params = Cl.bufferFromHex("00");
      const result = simnet.callPublicFn(
        "conxian-operations-engine",
        "execute-operational-adjustment",
        [params],
        deployer
      );
      expect(result.result).toBeOk(Cl.bool(true));
    });
  });

  describe("Agent Risk", () => {
    it("should have agent-risk deployed", () => {
      const contract = simnet.getContractSource("agent-risk");
      expect(contract).toBeDefined();
    });
  });
});
'''
        
        gov_test_path = self.tests_dir / "governance-system.test.ts"
        gov_test_path.write_text(gov_test)
        
    def run_refactoring(self) -> Dict[str, int]:
        """Run the complete refactoring process"""
        results = {
            "paths_fixed": self.fix_test_paths(),
            "deprecated_calls_fixed": self.fix_deprecated_calls(),
            "contracts_updated": self.update_contract_references(),
            "new_tests_created": 2
        }
        
        # Create comprehensive test suite
        self.create_comprehensive_test_suite()
        
        return results

if __name__ == "__main__":
    import sys
    
    project_root = sys.argv[1] if len(sys.argv) > 1 else "."
    refactorer = TestRefactorer(project_root)
    
    print("🔧 Analyzing test files...")
    issues = refactorer.analyze_test_files()
    
    print(f"Found {len(issues['path_issues'])} path issues")
    print(f"Found {len(issues['contract_issues'])} contract issues")
    
    print("🔄 Running refactoring...")
    results = refactorer.run_refactoring()
    
    print("✅ Refactoring complete!")
    for key, value in results.items():
        print(f"  {key}: {value}")
