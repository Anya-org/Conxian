
import { createContext } from 'react';
import { AppState, WalletConfig, Asset, Bounty, Network, AppMode, LnBackendConfig } from './types';
import { Language } from './services/i18n';
import { ToastType } from './components/Toast';
import { SignRequest, SignResult } from './services/signer';

export const AppContext = createContext<{
  state: AppState & { language: Language };
  setPrivacyMode: (val: boolean) => void;
  updateFees: (val: number) => void;
  toggleGateway: (val: boolean) => void;
  setMainnetLive: (val: boolean) => void;
  setWalletConfig: (config: WalletConfig) => void;
  updateAssets: (assets: Asset[]) => void;
  claimBounty: (bountyId: string) => void;
  resetEnclave: () => void;
  setLanguage: (lang: Language) => void;
  notify: (type: ToastType, message: string) => void;
  authorizeSignature: (request: SignRequest) => Promise<SignResult>;
  lockWallet: () => void;
  setNetwork: (network: Network) => void;
  setMode: (mode: AppMode) => void;
  setLnBackend: (cfg: LnBackendConfig) => void;
  setSecurity: (s: Partial<AppState['security']>) => void;
} | null>(null);
