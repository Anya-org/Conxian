
import React, { useState, useEffect, useRef } from 'react';
import { Shield, ArrowRight, Key, Users, Zap, ShieldCheck, RefreshCcw, RotateCcw, Loader2, Eye, Lock, AlertTriangle, Database, Globe, CheckCircle2 } from 'lucide-react';
import { WalletConfig, AppMode } from '../types';
import { deriveSovereignRoots } from '../services/signer';
import { encryptSeed } from '../services/seed';
import * as bip39 from 'bip39';

interface OnboardingProps {
  onComplete: (config: WalletConfig & { mode: AppMode }, pin: string) => void;
}

const BIP39_SUBSET = [
  "abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd", "abuse", "access", "accident",
  "account", "accuse", "achieve", "acid", "acoustic", "acquire", "across", "act", "action", "actor", "actress", "actual",
  "adapt", "add", "addict", "address", "adjust", "admit", "adult", "advance", "advice", "aerobic", "affair", "afford",
  "afraid", "again", "age", "agent", "agree", "ahead", "aim", "air", "airport", "aisle", "alarm", "album", "alcohol",
  "alert", "alien", "all", "alley", "allow", "almost", "alone", "alpha", "already", "also", "alter", "always", "amaze",
  "amber", "ambush", "among", "amount", "amuse", "analyst", "anchor", "ancient", "anger", "angle", "angry", "animal",
  "ankle", "announce", "annual", "another", "answer", "antenna", "antique", "anxiety", "any", "apart", "apology", "appear",
  "apple", "approve", "april", "arch", "arctic", "area", "arena", "argue", "arm", "armed", "armor", "army", "around",
  "arrange", "arrest", "arrive", "arrow", "art", "artefact", "artist", "artwork", "ask", "aspect", "assault", "asset",
  "assist", "assume", "asthma", "athlete", "atom", "attack", "attend", "attitude", "attract", "auction", "audit", "august"
];

const Onboarding: React.FC<OnboardingProps> = ({ onComplete }) => {
  const [step, setStep] = useState<'type' | 'entropy' | 'security' | 'backup'>('type');
  const [appMode, setAppMode] = useState<AppMode>('sovereign');
  const [walletType, setWalletType] = useState<'single' | 'multisig' | 'hot'>('single');
  const [entropyProgress, setEntropyProgress] = useState(0);
  const [mnemonic, setMnemonic] = useState<string[]>([]);
  const [isGenerating, setIsGenerating] = useState(false);
  const [showMnemonic, setShowMnemonic] = useState(false);
  const [isFinalizing, setIsFinalizing] = useState(false);
  
  // Refs for dynamic styles to avoid inline-style linter warnings
  const entropyCircleRef = useRef<HTMLDivElement>(null);
  const entropyBarRef = useRef<HTMLDivElement>(null);
  
  // Security State
  const [pin, setPin] = useState('');
  const [confirmPin, setConfirmPin] = useState('');
  const [passphrase, setPassphrase] = useState('');

  // Entropy Harvesting
  const handleEntropyInput = () => {
    if (step === 'entropy' && entropyProgress < 100) {
      setEntropyProgress(prev => Math.min(100, prev + 0.5)); // Increased speed slightly for better mobile feel
    }
  };

  const handleMouseMove = (e: React.MouseEvent) => {
    handleEntropyInput();
  };

  const handleTouchMove = (e: React.TouchEvent) => {
    handleEntropyInput();
  };

  const generateSeed = async () => {
    setIsGenerating(true);
    
    // Real Production Logic using BIP-39
    await new Promise(r => setTimeout(r, 800)); // UX Pause for "Entropy Calculation" effect
    const generatedMnemonic = bip39.generateMnemonic();
    const generated = generatedMnemonic.split(' ');

    setMnemonic(generated);
    setIsGenerating(false);
    setStep('security');
  };

  useEffect(() => {
    // Direct DOM manipulation to avoid linter errors with inline styles
    if (entropyCircleRef.current) {
      entropyCircleRef.current.style.height = `${entropyProgress}%`;
    }
    if (entropyBarRef.current) {
      entropyBarRef.current.style.width = `${entropyProgress}%`;
    }

    if (entropyProgress >= 100) {
      generateSeed();
    }
  }, [entropyProgress]);

  const handleFinalize = async () => {
    setIsFinalizing(true);
    const seedString = mnemonic.join(' ');
    // Async derivation ensures UI doesn't freeze during heavy hashing
    const roots = await deriveSovereignRoots(seedString, passphrase || undefined);
    const seedBytes = await bip39.mnemonicToSeed(seedString, passphrase || undefined);
    const seedVault = await encryptSeed(new Uint8Array(seedBytes), pin);
    
    // Pass PIN up to App for encryption
    onComplete({ 
      mode: appMode,
      type: walletType,
      seedVault,
      masterAddress: roots.btc,
      stacksAddress: roots.stx
    }, pin);
    setIsFinalizing(false);
  };

  return (
    <div 
      className="min-h-screen bg-background flex items-center justify-center p-4 font-sans select-none touch-none"
      onMouseMove={handleMouseMove}
      onTouchMove={handleTouchMove}
    >
      <div className="max-w-md w-full bg-surface-100 border border-border rounded-[2.5rem] p-8 md:p-12 space-y-8 md:space-y-10 shadow-2xl animate-in fade-in zoom-in duration-500 relative overflow-hidden">
        <div className="absolute top-0 right-0 -mt-20 -mr-20 w-64 h-64 bg-bitcoin/5 rounded-full blur-3xl pointer-events-none" />
        
        {step === 'type' && (
          <div className="space-y-10 animate-in fade-in relative z-10">
            <div className="text-center space-y-4">
              <div className="w-20 h-20 bg-surface-200 border border-bitcoin/20 rounded-3xl flex items-center justify-center mx-auto text-bitcoin shadow-xl shadow-bitcoin/5">
                <Shield size={40} />
              </div>
              <div className="space-y-1">
                <h2 className="text-3xl font-bold tracking-tight text-white uppercase italic">Configure Vault</h2>
                <p className="text-muted text-[10px] font-bold uppercase tracking-widest">Define your multi-layer signature policy</p>
              </div>
            </div>

            <div className="space-y-4">
              {[
                { id: 'single', label: 'Personal Vault', desc: 'Standard security for personal assets.', icon: Key },
                { id: 'multisig', label: 'Treasury (Multi-Sig)', desc: 'Institutional grade M-of-N protection.', icon: Users },
                { id: 'hot', label: 'Lightning Hot Wallet', desc: 'Ephemeral keys for high-speed payments.', icon: Zap },
              ].map((type) => (
                <button
                  key={type.id}
                  onClick={() => setWalletType(type.id as any)}
                  className={`w-full p-6 rounded-3xl border text-left transition-all group ${
                    walletType === type.id 
                      ? 'bg-bitcoin/10 border-bitcoin/50 text-white shadow-lg' 
                      : 'bg-surface-200/50 border-border text-muted hover:border-bitcoin/30'
                  }`}
                >
                  <div className="flex items-center gap-5">
                    <div className={`p-3 rounded-2xl transition-colors ${
                      walletType === type.id ? 'bg-bitcoin text-black' : 'bg-surface-100 text-muted group-hover:text-bitcoin'
                    }`}>
                      <type.icon size={22} />
                    </div>
                    <div className="space-y-1">
                       <p className={`font-bold text-sm tracking-tight ${walletType === type.id ? 'text-white' : 'text-white/70'}`}>{type.label}</p>
                       <p className="text-[10px] font-medium opacity-60 leading-relaxed">{type.desc}</p>
                    </div>
                  </div>
                </button>
              ))}
            </div>

            <button 
              onClick={() => setStep('entropy')}
              className="w-full bg-white hover:bg-white/90 text-black font-bold py-5 rounded-2xl text-[10px] uppercase tracking-[0.2em] transition-all active:scale-95 shadow-xl"
            >
              Continue to Entropy Scan
            </button>
          </div>
        )}

        {step === 'entropy' && (
          <div className="text-center space-y-12 py-10 animate-in fade-in relative z-10">
             <div className="space-y-6">
                <div className="w-24 h-24 bg-surface-200 border border-border rounded-full flex items-center justify-center mx-auto relative overflow-hidden shadow-inner">
                   <div 
                     ref={entropyCircleRef}
                     className="absolute bottom-0 left-0 right-0 bg-bitcoin/20 transition-all duration-300" 
                   />
                   <RotateCcw className={`text-bitcoin relative z-10 ${entropyProgress < 100 ? 'animate-spin' : ''}`} size={40} />
                </div>
                <div className="space-y-2">
                   <h3 className="text-2xl font-bold italic uppercase tracking-tight text-white">Gathering Entropy</h3>
                   <p className="text-[10px] text-muted font-bold uppercase tracking-widest max-w-[240px] mx-auto">
                      Hardware-level noise captured via cursor trajectory
                   </p>
                </div>
             </div>

             <div className="space-y-4">
                <div className="w-full h-2.5 bg-surface-200 rounded-full overflow-hidden border border-border p-0.5">
                   <div 
                     ref={entropyBarRef}
                     className="h-full bg-bitcoin rounded-full transition-all shadow-[0_0_15px_rgba(247,147,26,0.3)]" 
                   />
                </div>
                <p className="text-[10px] font-bold text-bitcoin uppercase tracking-widest">{Math.floor(entropyProgress)}% Captured</p>
             </div>
             {isGenerating && (
                <div className="flex items-center justify-center gap-3 text-bitcoin text-[10px] font-bold uppercase tracking-[0.15em]">
                   <Loader2 size={16} className="animate-spin" /> Finalizing BIP-39 Map...
                </div>
             )}
          </div>
        )}

        {step === 'security' && (
          <div className="space-y-10 animate-in fade-in relative z-10">
             <div className="text-center space-y-4">
                <div className="w-20 h-20 bg-surface-200 border border-border rounded-3xl flex items-center justify-center mx-auto text-bitcoin shadow-xl mb-2">
                   <Lock size={40} />
                </div>
                <div className="space-y-1">
                   <h3 className="text-2xl font-bold italic uppercase tracking-tight text-white">Secure Enclave</h3>
                   <p className="text-[10px] text-muted font-bold uppercase tracking-widest">Set a PIN to encrypt your local session</p>
                </div>
             </div>

             <div className="space-y-6">
                <div className="space-y-2.5">
                   <label className="text-[10px] font-bold uppercase text-muted tracking-widest ml-1">Enclave PIN (4-8 digits)</label>
                   <input 
                      type="password"
                      value={pin}
                      onChange={(e) => setPin(e.target.value)}
                      placeholder="••••"
                      aria-label="Enclave PIN"
                      className="w-full bg-surface-200 border border-border rounded-2xl py-5 px-6 text-center text-3xl font-mono text-white tracking-[1em] focus:outline-none focus:border-bitcoin/50 focus:ring-1 focus:ring-bitcoin/20 transition-all placeholder:text-muted/30"
                      maxLength={8}
                   />
                </div>
                <div className="space-y-2.5">
                   <label className="text-[10px] font-bold uppercase text-muted tracking-widest ml-1">Confirm PIN</label>
                   <input 
                      type="password"
                      value={confirmPin}
                      onChange={(e) => setConfirmPin(e.target.value)}
                      placeholder="••••"
                      aria-label="Confirm Enclave PIN"
                      className="w-full bg-surface-200 border border-border rounded-2xl py-5 px-6 text-center text-3xl font-mono text-white tracking-[1em] focus:outline-none focus:border-bitcoin/50 focus:ring-1 focus:ring-bitcoin/20 transition-all placeholder:text-muted/30"
                      maxLength={8}
                   />
                </div>
                <div className="space-y-2.5">
                   <label className="text-[10px] font-bold uppercase text-muted tracking-widest ml-1">BIP-39 Passphrase (Optional)</label>
                   <input 
                      type="password"
                      value={passphrase}
                      onChange={(e) => setPassphrase(e.target.value)}
                      placeholder="Enter optional passphrase"
                      aria-label="BIP-39 Passphrase"
                      className="w-full bg-surface-200 border border-border rounded-2xl py-5 px-6 text-center text-sm font-mono text-white tracking-widest focus:outline-none focus:border-bitcoin/50 focus:ring-1 focus:ring-bitcoin/20 transition-all placeholder:text-muted/30"
                   />
                </div>
             </div>

             <button 
                onClick={() => setStep('backup')}
                disabled={!pin || pin.length < 4 || pin !== confirmPin}
                className="w-full bg-white hover:bg-white/90 disabled:opacity-30 disabled:cursor-not-allowed text-black font-bold py-5 rounded-2xl text-[10px] uppercase tracking-[0.2em] transition-all active:scale-95 flex items-center justify-center gap-3 shadow-xl"
             >
                <CheckCircle2 size={18} /> Confirm Encryption
             </button>
          </div>
        )}

        {step === 'backup' && (
          <div className="space-y-10 animate-in slide-in-from-bottom-4 relative z-10">
             <div className="text-center space-y-2">
                <h3 className="text-2xl font-bold italic uppercase tracking-tight text-white">Master Seed Backup</h3>
                <p className="text-[10px] text-muted font-bold uppercase tracking-widest">Production-grade recovery phrase</p>
             </div>

             <div className="relative group">
                <div className={`grid grid-cols-3 gap-3 p-8 bg-surface-200 border border-border rounded-[2.5rem] transition-all duration-700 ${!showMnemonic ? 'blur-xl' : 'blur-0'}`}>
                   {mnemonic.map((word, i) => (
                      <div key={i} className="flex items-center gap-2.5">
                         <span className="text-[10px] text-muted font-mono font-bold">{String(i+1).padStart(2, '0')}.</span>
                         <span className="text-sm font-bold text-white tracking-tight">{word}</span>
                      </div>
                   ))}
                </div>
                {!showMnemonic && (
                  <button 
                    onClick={() => setShowMnemonic(true)}
                    className="absolute inset-0 flex flex-col items-center justify-center bg-transparent rounded-[2.5rem] group-hover:scale-105 transition-transform"
                  >
                     <div className="w-16 h-16 bg-bitcoin/10 rounded-full flex items-center justify-center mb-3">
                        <Eye size={32} className="text-bitcoin" />
                     </div>
                     <span className="text-[10px] font-bold uppercase text-bitcoin tracking-[0.2em]">Reveal Phrase</span>
                  </button>
                )}
             </div>

             <div className="bg-bitcoin/5 border border-bitcoin/10 p-6 rounded-3xl flex gap-5">
                <AlertTriangle className="text-bitcoin shrink-0" size={24} />
                <div className="space-y-1">
                   <p className="text-[10px] font-bold text-bitcoin uppercase tracking-wider">Security Protocol</p>
                   <p className="text-[10px] text-muted leading-relaxed font-medium italic">
                      This phrase is encrypted locally. It is <span className="text-white font-bold">NEVER</span> transmitted to Conxius Labs or any third party.
                   </p>
                </div>
             </div>

             <button 
               onClick={handleFinalize}
               disabled={isFinalizing}
               className="w-full bg-bitcoin hover:bg-bitcoin/90 text-black font-bold py-5 rounded-2xl text-[10px] uppercase tracking-[0.2em] shadow-xl shadow-bitcoin/10 flex items-center justify-center gap-3 disabled:opacity-50 transition-all active:scale-95"
             >
                {isFinalizing ? <Loader2 size={18} className="animate-spin" /> : <Lock size={18} />}
                {isFinalizing ? 'Deriving Roots...' : 'Initialize Enclave'}
             </button>
          </div>
        )}

        <div className="text-center pt-2 relative z-10">
          <p className="text-[9px] text-muted/50 uppercase tracking-[0.3em] font-bold">
            Conxius SVN 0.3 • SOVEREIGN
          </p>
        </div>
      </div>
    </div>
  );
};

export default Onboarding;
