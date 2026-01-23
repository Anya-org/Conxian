
export type BitcoinLayer = 'Mainnet' | 'Stacks' | 'Rootstock' | 'Lightning' | 'Liquid' | 'Runes' | 'Ordinals';
export type AppMode = 'sovereign' | 'simulation';
export type Network = 'mainnet' | 'testnet' | 'regtest' | 'devnet';
export type LnBackendType = "None" | "LND" | "Breez" | "Greenlight";
export interface LnBackendConfig {
  type: LnBackendType;
  endpoint?: string;
  apiKey?: string;
}

export interface Asset {
  id: string;
  name: string;
  symbol: string;
  balance: number;
  valueUsd: number;
  layer: BitcoinLayer;
  type: 'Native' | 'BRC-20' | 'Rune' | 'SIP-10' | 'Wrapped';
  icon?: string;
  linkedDid?: string;
  address?: string;
}

export interface UTXO {
  txid: string;
  vout: number;
  amount: number;
  address: string;
  label?: string;
  status: 'confirmed' | 'pending';
  isFrozen: boolean;
  derivationPath: string;
  privacyRisk: 'High' | 'Medium' | 'Low';
}

export interface Transaction {
  id: string;
  type: 'send' | 'receive' | 'bridge' | 'buy';
  asset: string;
  amount: number;
  status: 'pending' | 'completed' | 'failed';
  timestamp: number;
  layer: BitcoinLayer;
  counterparty?: string;
}

export interface Signer {
  id: number;
  name: string;
  type: 'local' | 'hardware' | 'xpub' | 'empty';
  key?: string;
  status: 'ready' | 'pending' | 'signed';
}

export interface WalletConfig {
  type: 'single' | 'multisig' | 'hot';
  seedVault?: string;
  quorum?: { m: number; n: number };
  signers?: Signer[];
  masterAddress?: string;
  stacksAddress?: string;
}

export interface Bounty {
  id: string;
  title: string;
  description: string;
  reward: string;
  category: 'Core' | 'UI/UX' | 'Security' | 'L2 Expansion';
  status: 'Open' | 'Claimed' | 'In Review' | 'Completed';
  difficulty: 'Beginner' | 'Intermediate' | 'Elite';
  expiry: string;
  claimedBy?: string;
}

export interface CitadelMember {
  id: string;
  name: string;
  role: 'Architect' | 'Guardian' | 'Initiate';
  sovereigntyScore: number;
  nodeStatus: 'Online' | 'Offline' | 'Leech';
  stackedAmount: number;
  votingPower: number;
}

export interface ReserveAsset {
  asset: string;
  totalSupplied: number;
  totalReserves: number;
  collateralRatio: number;
  status: string;
}

export interface Citadel {
  id: string;
  name: string;
  motto: string;
  members: CitadelMember[];
  treasuryBalance: number;
  sharedRpcEndpoint: string;
  alignmentScore: number;
  nextPayout: string;
  pool: {
    totalStacked: number;
    nextCycleTarget: number;
    estimatedYieldBtc: number;
    coordinatorFee: number;
  };
  proposals: {
    id: string;
    title: string;
    description: string;
    type: string;
    status: string;
    votesFor: number;
    votesAgainst: number;
    deadline: string;
  }[];
  pendingTxs: {
    id: string;
    description: string;
    amount: number;
    asset: string;
    to: string;
    signatures: number;
    required: number;
    status: string;
  }[];
  bounties: Bounty[];
}

export interface AppState {
  version: string;
  mode: AppMode;
  network: Network;
  privacyMode: boolean;
  nodeSyncProgress: number;
  integratorFeesAccumulated: number;
  sovereigntyScore: number;
  isTorActive: boolean;
  deploymentReadiness: number;
  externalGatewaysActive: boolean;
  isMainnetLive: boolean;
  walletConfig?: WalletConfig;
  assets: Asset[];
  bounties: Bounty[];
  activeCitadel?: Citadel;
  dataSharing: {
    enabled: boolean;
    aiCapBoostActive: boolean;
    minAskPrice: number;
    totalEarned: number;
  };
  lnBackend?: LnBackendConfig;
  security?: {
    autoLockMinutes: number;
    duressPin?: string;
    biometricUnlock?: boolean;
  }
}

export interface DIDProfile {
  did: string;
  alias: string;
  bio: string;
  verified: boolean;
  linkedAddress: string;
  avatarUrl?: string;
  socials: {
    twitter?: string;
    github?: string;
    nostr?: string;
  };
}
