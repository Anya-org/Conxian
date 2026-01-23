
import React, { useState } from 'react';
import { Lock, Loader2, ShieldCheck, AlertCircle, Fingerprint } from 'lucide-react';
import { authenticateBiometric } from '../services/biometric';

interface LockScreenProps {
  onUnlock: (pin: string) => Promise<void>;
  isError: boolean;
  requireBiometric?: boolean;
  onResetWallet?: () => void;
}

const LockScreen: React.FC<LockScreenProps> = ({ onUnlock, isError, requireBiometric, onResetWallet }) => {
  const [pin, setPin] = useState('');
  const [isValidating, setIsValidating] = useState(false);
  const [biometricApproved, setBiometricApproved] = useState(!requireBiometric);
  const [isBiometricChecking, setIsBiometricChecking] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (pin.length < 4) return;
    
    setIsValidating(true);
    // Artificial delay to prevent brute-force timing attacks
    await new Promise(r => setTimeout(r, 500));
    await onUnlock(pin);
    setIsValidating(false);
    setPin('');
  };

  const handleNumClick = (num: string) => {
    if (!biometricApproved) return;
    if (pin.length < 8) setPin(prev => prev + num);
  };

  return (
    <div className="fixed inset-0 bg-background flex items-center justify-center z-[1000] p-6">
      <div className="w-full max-w-sm flex flex-col items-center gap-10 animate-in zoom-in duration-500">
        <div className="flex flex-col items-center gap-6">
           <div className="w-24 h-24 bg-surface-100 rounded-[2.5rem] flex items-center justify-center shadow-2xl border border-border relative group transition-transform duration-500 hover:scale-105">
              <div className="absolute inset-0 bg-bitcoin/5 rounded-[2.5rem] opacity-0 group-hover:opacity-100 transition-opacity" />
              <Lock size={36} className="text-bitcoin relative z-10" />
              {isError && (
                 <div className="absolute -top-1 -right-1 bg-error text-white p-2 rounded-full animate-bounce shadow-lg ring-4 ring-background">
                    <AlertCircle size={16} />
                 </div>
              )}
           </div>
           <div className="text-center space-y-2">
              <h1 className="text-3xl font-bold text-white tracking-tighter uppercase italic">Conxius Enclave</h1>
              <p className="text-[10px] font-bold text-muted uppercase tracking-[0.2em]">Sovereign Environment Locked</p>
           </div>
        </div>

        <form onSubmit={handleSubmit} className="w-full space-y-10">
           {requireBiometric && !biometricApproved && (
             <button
               type="button"
               onClick={async () => {
                 setIsBiometricChecking(true);
                 const ok = await authenticateBiometric();
                 setBiometricApproved(ok);
                 setIsBiometricChecking(false);
               }}
               disabled={isBiometricChecking}
               className="w-full bg-surface-200 hover:bg-surface-300 border border-border text-white font-bold py-4 rounded-2xl text-[10px] uppercase tracking-widest flex items-center justify-center gap-3 active:scale-95 transition-all disabled:opacity-50 shadow-lg"
             >
               {isBiometricChecking ? <Loader2 size={16} className="animate-spin text-bitcoin" /> : <Fingerprint size={16} className="text-bitcoin" />}
               {isBiometricChecking ? 'Verifying Identity...' : 'Unlock with Biometrics'}
             </button>
           )}

           <div className="flex justify-center gap-6">
              {[...Array(4)].map((_, i) => (
                 <div 
                   key={i} 
                   className={`w-3.5 h-3.5 rounded-full transition-all duration-500 ${
                      i < pin.length 
                        ? isError ? 'bg-error scale-125 shadow-[0_0_15px_rgba(239,68,68,0.5)]' : 'bg-bitcoin scale-125 shadow-[0_0_15px_rgba(247,147,26,0.5)]' 
                        : 'bg-surface-300'
                   }`} 
                 />
              ))}
           </div>

           <div className="grid grid-cols-3 gap-5 px-2">
              {[1, 2, 3, 4, 5, 6, 7, 8, 9, '', 0, 'del'].map((item, i) => (
                 item === '' ? <div key={i} /> :
                 item === 'del' ? (
                    <button 
                      type="button" 
                      key={i}
                      onClick={() => setPin(prev => prev.slice(0, -1))}
                      className="h-16 rounded-2xl flex items-center justify-center text-muted hover:text-white hover:bg-surface-200 transition-all font-bold text-[10px] uppercase tracking-widest"
                      disabled={!biometricApproved}
                    >
                       Clear
                    </button>
                 ) : (
                    <button 
                      type="button" 
                      key={i}
                      onClick={() => handleNumClick(item.toString())}
                      disabled={!biometricApproved}
                      className="h-16 bg-surface-100 hover:bg-surface-200 border border-border rounded-2xl text-2xl font-bold text-white transition-all active:scale-90 disabled:opacity-30 shadow-sm"
                    >
                       {item}
                    </button>
                 )
              ))}
           </div>

           <div className="space-y-4">
             <button 
               type="submit" 
               disabled={!biometricApproved || pin.length < 4 || isValidating}
               className="w-full bg-bitcoin hover:bg-bitcoin-dark disabled:opacity-30 disabled:grayscale text-black font-bold py-5 rounded-2xl text-[10px] uppercase tracking-widest shadow-xl shadow-bitcoin/20 flex items-center justify-center gap-3 active:scale-95 transition-all"
             >
                {isValidating ? <Loader2 size={18} className="animate-spin" /> : <ShieldCheck size={18} />}
                <span>{isValidating ? 'Decrypting State...' : 'Unlock Vault'}</span>
             </button>
             
             {onResetWallet && (
               <button
                 type="button"
                 onClick={onResetWallet}
                 className="w-full text-muted hover:text-white text-[9px] font-bold uppercase tracking-[0.2em] py-2 transition-colors"
               >
                 Purge & Reset Wallet
               </button>
             )}
           </div>
        </form>
      </div>
    </div>
  );
};

export default LockScreen;
