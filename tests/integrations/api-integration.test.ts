import { Clarinet, Tx, Block } from '@stacks/clarinet';
import { 
  BankApiAdapter,
  SsiCredentialManager,
  AutoRegulatoryAlignment
} from '../contracts/integrations';

describe('API Integration Suite', () => {
  let clarinet: Clarinet;
  let deployer: any;
  let bankApiAdapter: BankApiAdapter;
  let ssiCredentialManager: SsiCredentialManager;
  let autoRegulatoryAlignment: AutoRegulatoryAlignment;
  let user: string;
  let institution: string;
  let admin: string;

  before(async () => {
    clarinet = new Clarinet();
    deployer = await clarinet.deployer();
    
    // Deploy contracts
    const contracts = await deployer.deployContracts([
      'contracts/integrations/bank-api-adapter.clar',
      'contracts/integrations/ssi-credential-manager.clar',
      'contracts/integrations/auto-regulatory-alignment.clar',
      'contracts/compliance/regulatory-adapter.clar',
      'contracts/access/conxian-access.clar'
    ]);
    
    bankApiAdapter = contracts[0];
    ssiCredentialManager = contracts[1];
    autoRegulatoryAlignment = contracts[2];
    
    // Get test addresses
    user = deployer.accounts.get('wallet_1').address;
    institution = deployer.accounts.get('wallet_2').address;
    admin = deployer.accounts.get('deployer').address;
    
    // Setup initial state
    await deployer.runBlock(Block.genesis());
    
    // Setup admin roles
    await deployer.tx(
      tx => tx.callFn('conxian-access.grant-role', user, 1), // ROLE_ADMIN
      deployer.accounts.get('deployer')
    );
    
    await deployer.runBlock(Block.genesis());
  });

  describe('Bank API Adapter', () => {
    it('should register API provider successfully', async () => {
      const block = await deployer.tx(
        tx => tx.callFn('bank-api-adapter.register-api-provider', 1, 'test_client_id', 'test_public_key'),
        admin
      );
      
      expect(block.result).toBeOk(true);
    });

    it('should initiate account verification for compliant users', async () => {
      // Mock compliance check
      await deployer.tx(
        tx => tx.callFn('regulatory-adapter.submit-compliance-proof', '0x01', 1000000, 'US'),
        user
      );
      
      const block = await deployer.tx(
        tx => tx.callFn('bank-api-adapter.initiate-account-verification', 
          1, // API_PROVIDER_PLAID
          '0x1234567890abcdef1234567890abcdef1234567890abcdef', // account hash
          'Test Bank',
          'checking'
        ),
        user
      );
      
      expect(block.result).toBeOk();
      expect(block.result.value).toBeGreaterThan(0); // request ID
    });

    it('should complete account verification', async () => {
      // First initiate verification
      const initBlock = await deployer.tx(
        tx => tx.callFn('bank-api-adapter.initiate-account-verification', 
          1,
          '0x1234567890abcdef1234567890abcdef1234567890abcdef',
          'Test Bank',
          'checking'
        ),
        user
      );
      
      const requestId = initBlock.result.value;
      
      // Complete verification
      const block = await deployer.tx(
        tx => tx.callFn('bank-api-adapter.complete-verification', 
          requestId,
          1, // verification tier
          '0x987654321fedcba9876543210fedcba9876543210fedc' // response hash
        ),
        admin
      );
      
      expect(block.result).toBeOk(true);
    });

    it('should record transaction monitoring data', async () => {
      const block = await deployer.tx(
        tx => tx.callFn('bank-api-adapter.record-transaction',
          user,
          1000000, // $10 in micro-units
          'deposit'
        ),
        admin
      );
      
      expect(block.result).toBeOk();
      expect(block.result.value).toBeGreaterThan(0); // risk score
    });

    it('should check institutional eligibility', async () => {
      // First complete verification
      await deployer.tx(
        tx => tx.callFn('bank-api-adapter.initiate-account-verification', 
          1,
          '0x1234567890abcdef1234567890abcdef1234567890abcdef',
          'Test Bank',
          'checking'
        ),
        user
      );
      
      await deployer.tx(
        tx => tx.callFn('bank-api-adapter.complete-verification', 
          1,
          2, // enhanced tier
          '0x987654321fedcba9876543210fedcba9876543210fedc'
        ),
        admin
      );
      
      const block = await deployer.tx(
        tx => tx.callFn('bank-api-adapter.check-institutional-eligibility', user),
        admin
      );
      
      expect(block.result).toBeOk();
      const result = block.result.value;
      expect(result['has-verified-account']).toBe(true);
      expect(result['verification-tier']).toBe(2);
      expect(result['is-eligible']).toBe(true);
    });
  });

  describe('SSI Credential Manager', () => {
    it('should register DID for compliant users', async () => {
      // Mock compliance check
      await deployer.tx(
        tx => tx.callFn('regulatory-adapter.submit-compliance-proof', '0x01', 1000000, 'US'),
        user
      );
      
      const block = await deployer.tx(
        tx => tx.callFn('ssi-credential-manager.register-did',
          1, // DID_METHOD_KEY
          '0x1234567890abcdef1234567890abcdef1234567890abcdef' // document hash
        ),
        user
      );
      
      expect(block.result).toBeOk();
      expect(block.result.value).toContain('did:key:'); // DID string
    });

    it('should register institutional issuer', async () => {
      const block = await deployer.tx(
        tx => tx.callFn('ssi-credential-manager.register-institutional-issuer',
          'Test Institution',
          2, // accreditation level
          'US',
          518400 // 30 days in blocks
        ),
        admin
      );
      
      expect(block.result).toBeOk(true);
    });

    it('should issue verifiable credential', async () => {
      // Register DID first
      await deployer.tx(
        tx => tx.callFn('ssi-credential-manager.register-did',
          1,
          '0x1234567890abcdef1234567890abcdef1234567890abcdef'
        ),
        user
      );
      
      // Register institution
      await deployer.tx(
        tx => tx.callFn('ssi-credential-manager.register-institutional-issuer',
          'Test Institution',
          2,
          'US',
          518400
        ),
        institution
      );
      
      const block = await deployer.tx(
        tx => tx.callFn('ssi-credential-manager.issue-credential',
          user,
          1, // CREDENTIAL_TYPE_KYC
          '0xabcdef1234567890abcdef1234567890abcdef12345678', // credential hash
          518400 // expires in 30 days
        ),
        institution
      );
      
      expect(block.result).toBeOk();
      expect(block.result.value).toBeInstanceOf(Buffer); // credential ID
    });

    it('should verify credential', async () => {
      // Issue credential first
      await deployer.tx(
        tx => tx.callFn('ssi-credential-manager.register-did',
          1,
          '0x1234567890abcdef1234567890abcdef1234567890abcdef'
        ),
        user
      );
      
      const issueBlock = await deployer.tx(
        tx => tx.callFn('ssi-credential-manager.issue-credential',
          user,
          1,
          '0xabcdef1234567890abcdef1234567890abcdef12345678',
          518400
        ),
        institution
      );
      
      const credentialId = issueBlock.result.value;
      
      const block = await deployer.tx(
        tx => tx.callFn('ssi-credential-manager.verify-credential',
          credentialId,
          '0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef12345678' // signature
        ),
        admin
      );
      
      expect(block.result).toBeOk(true);
    });

    it('should check credential requirements', async () => {
      // Issue multiple credentials
      await deployer.tx(
        tx => tx.callFn('ssi-credential-manager.register-did',
          1,
          '0x1234567890abcdef1234567890abcdef1234567890abcdef'
        ),
        user
      );
      
      await deployer.tx(
        tx => tx.callFn('ssi-credential-manager.issue-credential',
          user,
          1, // KYC
          '0xabcdef1234567890abcdef1234567890abcdef12345678',
          518400
        ),
        institution
      );
      
      await deployer.tx(
        tx => tx.callFn('ssi-credential-manager.issue-credential',
          user,
          2, // AML
          '0xbcdef1234567890abcdef1234567890abcdef1234567890a',
          518400
        ),
        institution
      );
      
      const block = await deployer.tx(
        tx => tx.callFn('ssi-credential-manager.check-credential-requirements',
          user,
          [1, 2], // require KYC and AML
          500 // minimum trust level
        ),
        admin
      );
      
      expect(block.result).toBeOk();
      const result = block.result.value;
      expect(result['has-all-required']).toBe(true);
      expect(result['meets-min-trust']).toBe(true);
    });
  });

  describe('Auto Regulatory Alignment', () => {
    it('should register regulatory framework', async () => {
      const block = await deployer.tx(
        tx => tx.callFn('auto-regulatory-alignment.register-regulatory-framework',
          1, // JURISDICTION_US
          'US Banking Framework',
          'v2.0',
          800 // compliance threshold
        ),
        admin
      );
      
      expect(block.result).toBeOk(true);
    });

    it('should register regulatory rule', async () => {
      // Register framework first
      await deployer.tx(
        tx => tx.callFn('auto-regulatory-alignment.register-regulatory-framework',
          1,
          'US Banking Framework',
          'v2.0',
          800
        ),
        admin
      );
      
      const block = await deployer.tx(
        tx => tx.callFn('auto-regulatory-alignment.register-regulatory-rule',
          1, // jurisdiction
          1, // RULE_CATEGORY_KYC
          'Enhanced KYC Requirements',
          'All financial institutions must implement enhanced KYC verification',
          ['Document verification', 'Address verification', 'Risk assessment'],
          2, // critical severity
          1000, // effective immediately
          0 // no expiry
        ),
        admin
      );
      
      expect(block.result).toBeOk();
      expect(block.result.value).toBeInstanceOf(Buffer); // rule ID
    });

    it('should perform alignment check', async () => {
      // Setup framework and rules
      await deployer.tx(
        tx => tx.callFn('auto-regulatory-alignment.register-regulatory-framework',
          1,
          'US Banking Framework',
          'v2.0',
          800
        ),
        admin
      );
      
      await deployer.tx(
        tx => tx.callFn('auto-regulatory-alignment.register-regulatory-rule',
          1,
          1,
          'Enhanced KYC Requirements',
          'All financial institutions must implement enhanced KYC verification',
          ['Document verification', 'Address verification'],
          2,
          1000,
          0
        ),
        admin
      );
      
      // Mock compliance
      await deployer.tx(
        tx => tx.callFn('regulatory-adapter.submit-compliance-proof', '0x01', 1000000, 'US'),
        user
      );
      
      const block = await deployer.tx(
        tx => tx.callFn('auto-regulatory-alignment.perform-alignment-check',
          user,
          1 // US jurisdiction
        ),
        admin
      );
      
      expect(block.result).toBeOk();
      expect(block.result.value).toBeGreaterThan(0); // compliance score
    });

    it('should provide compliance recommendations', async () => {
      // Setup framework and perform alignment check
      await deployer.tx(
        tx => tx.callFn('auto-regulatory-alignment.register-regulatory-framework',
          1,
          'US Banking Framework',
          'v2.0',
          800
        ),
        admin
      );
      
      await deployer.tx(
        tx => tx.callFn('auto-regulatory-alignment.perform-alignment-check',
          user,
          1
        ),
        admin
      );
      
      const block = await deployer.tx(
        tx => tx.callFn('auto-regulatory-alignment.get-compliance-recommendations',
          user,
          1
        ),
        admin
      );
      
      expect(block.result).toBeInstanceOf(Array);
    });

    it('should get framework summary', async () => {
      // Register framework
      await deployer.tx(
        tx => tx.callFn('auto-regulatory-alignment.register-regulatory-framework',
          1,
          'US Banking Framework',
          'v2.0',
          800
        ),
        admin
      );
      
      const block = await deployer.tx(
        tx => tx.callFn('auto-regulatory-alignment.get-framework-summary',
          1
        ),
        admin
      );
      
      expect(block.result).toBeOk();
      const result = block.result.value;
      expect(result['framework-name']).toBe('US Banking Framework');
      expect(result['version']).toBe('v2.0');
      expect(result['auto-alignment-enabled']).toBe(true);
    });
  });

  describe('Integration Tests', () => {
    it('should handle complete institutional onboarding flow', async () => {
      // 1. User submits compliance proof
      await deployer.tx(
        tx => tx.callFn('regulatory-adapter.submit-compliance-proof', '0x01', 1000000, 'US'),
        user
      );
      
      // 2. Register DID
      await deployer.tx(
        tx => tx.callFn('ssi-credential-manager.register-did',
          1,
          '0x1234567890abcdef1234567890abcdef1234567890abcdef'
        ),
        user
      );
      
      // 3. Register institution
      await deployer.tx(
        tx => tx.callFn('ssi-credential-manager.register-institutional-issuer',
          'Test Bank',
          3, // High accreditation
          'US',
          1036800 // 60 days
        ),
        institution
      );
      
      // 4. Initiate bank verification
      const verificationBlock = await deployer.tx(
        tx => tx.callFn('bank-api-adapter.initiate-account-verification',
          1,
          '0x1234567890abcdef1234567890abcdef1234567890abcdef',
          'Test Bank',
          'business'
        ),
        user
      );
      
      // 5. Complete bank verification
      await deployer.tx(
        tx => tx.callFn('bank-api-adapter.complete-verification',
          verificationBlock.result.value,
          2, // Premium tier
          '0x987654321fedcba9876543210fedcba9876543210fedc'
        ),
        institution
      );
      
      // 6. Issue credentials
      await deployer.tx(
        tx => tx.callFn('ssi-credential-manager.issue-credential',
          user,
          1, // KYC
          '0xabcdef1234567890abcdef1234567890abcdef12345678',
          1036800
        ),
        institution
      );
      
      await deployer.tx(
        tx => tx.callFn('ssi-credential-manager.issue-credential',
          user,
          2, // AML
          '0xbcdef1234567890abcdef1234567890abcdef1234567890a',
          1036800
        ),
        institution
      );
      
      // 7. Verify credentials
      const credentials = await deployer.callReadOnlyFn('ssi-credential-manager.get-user-credentials', user);
      expect(credentials.result).toBeInstanceOf(Array);
      expect(credentials.result.length).toBe(2);
      
      // 8. Check institutional eligibility
      const eligibilityBlock = await deployer.tx(
        tx => tx.callFn('bank-api-adapter.check-institutional-eligibility',
          user
        ),
        admin
      );
      
      expect(eligibilityBlock.result).toBeOk();
      const eligibility = eligibilityBlock.result.value;
      expect(eligibility['is-eligible']).toBe(true);
      expect(eligibility['verification-tier']).toBe(2);
      
      // 9. Perform regulatory alignment
      await deployer.tx(
        tx => tx.callFn('auto-regulatory-alignment.register-regulatory-framework',
          1,
          'US Banking Framework',
          'v2.1',
          900 // Higher threshold for institutions
        ),
        admin
      );
      
      const alignmentBlock = await deployer.tx(
        tx => tx.callFn('auto-regulatory-alignment.perform-alignment-check',
          user,
          1
        ),
        admin
      );
      
      expect(alignmentBlock.result).toBeOk();
      expect(alignmentBlock.result.value).toBeGreaterThan(850); // High compliance score
    });
  });
});
