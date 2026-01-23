
import React, { useState, useContext } from 'react';
import { Settings as SettingsIcon, Globe, Moon, Sun, DollarSign, Bell, Shield, Info, Database, Eye, Crown, Zap, CheckCircle2, RotateCcw, Languages, MapPin, Lock, Briefcase } from 'lucide-react';
import { AppContext } from '../context';
import { Language } from '../services/i18n';
import { Network } from '../types';

const Settings: React.FC = () => {
  const appContext = useContext(AppContext);
  const [currency, setCurrency] = useState('USD');
  const [unit, setUnit] = useState('BTC');

  if (!appContext) return null;
  const { language, mode, network } = appContext.state;

  return (
    <div className="p-8 max-w-4xl mx-auto space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-500 pb-24">
      <header className="flex justify-between items-end">
        <div>
          <div className="flex items-center gap-4 mb-2">
            <div className="w-12 h-12 bg-zinc-900 border border-zinc-800 rounded-2xl flex items-center justify-center">
              <SettingsIcon className="text-zinc-400" size={24} />
            </div>
            <h2 className="text-3xl font-black tracking-tighter uppercase italic">Enclave Config</h2>
          </div>
          <p className="text-zinc-500 text-sm italic">Localize your sovereign experience and refine node parameters.</p>
        </div>
      </header>

      <div className="grid grid-cols-1 gap-6">
        
        {/* Localization Matrix */}
        <section className="bg-zinc-900/40 border border-zinc-800 rounded-3xl overflow-hidden shadow-xl">
          <div className="p-6 border-b border-zinc-800 bg-zinc-900/20">
            <h3 className="text-[10px] font-black uppercase tracking-widest text-zinc-500 flex items-center gap-2">
              <Languages size={16} className="text-orange-500" /> Localization & Region
            </h3>
          </div>
          <div className="p-8 grid grid-cols-1 md:grid-cols-2 gap-10">
            <div className="space-y-4">
              <label className="text-[10px] font-black uppercase text-zinc-600 flex items-center gap-2">
                <Globe size={12} /> Interface Language
              </label>
              <select 
                value={language}
                onChange={(e) => appContext.setLanguage(e.target.value as Language)}
                className="w-full bg-zinc-950 border border-zinc-800 rounded-2xl px-5 py-4 text-sm focus:outline-none focus:ring-1 focus:ring-orange-500/50"
                aria-label="Interface Language"
                title="Interface Language"
              >
                <option value="en">English (Global)</option>
                <option value="ar">العربية (Arabic)</option>
                <option value="fr">Français (Afrique)</option>
                <option value="zh">中文 (Chinese)</option>
                <option value="ru">Русский (Russian)</option>
                <option value="pt">Português (Brasil)</option>
                <option value="hi">हिन्दी (Hindi)</option>
                <option value="fa">فارسی (Persian)</option>
                <option value="id">Bahasa Indonesia</option>
                <option value="tr">Türkçe (Turkish)</option>
                <option value="sw">Kiswahili (Swahili)</option>
                <option value="es">Español (LatAm)</option>
                <option value="de">Deutsch (German)</option>
                <option value="cypher">Cypherpunk (Standard)</option>
              </select>
            </div>
            <div className="space-y-4">
              <label className="text-[10px] font-black uppercase text-zinc-600 flex items-center gap-2">
                <DollarSign size={12} /> Valuation Fiat
              </label>
              <select 
                value={currency}
                onChange={(e) => setCurrency(e.target.value)}
                className="w-full bg-zinc-950 border border-zinc-800 rounded-2xl px-5 py-4 text-sm focus:outline-none"
                aria-label="Valuation Fiat"
                title="Valuation Fiat"
              >
                <option value="USD">US Dollar ($)</option>
                <option value="EUR">Euro (€)</option>
                <option value="BRL">Brazilian Real (R$)</option>
                <option value="JPY">Japanese Yen (¥)</option>
              </select>
            </div>
            <div className="space-y-4">
              <label className="text-[10px] font-black uppercase text-zinc-600 flex items-center gap-2">
                <Zap size={12} /> Native Unit
              </label>
              <div className="flex bg-zinc-950 border border-zinc-800 p-1 rounded-2xl">
                 {['BTC', 'SATS', 'BITS'].map(u => (
                   <button 
                    key={u}
                    type="button"
                    onClick={() => setUnit(u)}
                    className={`flex-1 py-3 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${unit === u ? 'bg-orange-600 text-white shadow-lg' : 'text-zinc-600 hover:text-zinc-400'}`}
                   >
                     {u}
                   </button>
                 ))}
              </div>
            </div>
            <div className="space-y-4">
              <label className="text-[10px] font-black uppercase text-zinc-600 flex items-center gap-2">
                <MapPin size={12} /> Region Logic
              </label>
              <p className="text-[10px] text-zinc-500 italic leading-relaxed">
                 Adjusts fee estimators and gateway priority based on local chain density. Currently optimized for <strong>Global Relay</strong>.
              </p>
            </div>
          </div>
        </section>

        {/* System Persistence */}
        <section className="bg-zinc-900/40 border border-zinc-800 rounded-3xl overflow-hidden">
          <div className="p-6 border-b border-zinc-800 bg-zinc-900/20">
            <h3 className="text-[10px] font-black uppercase tracking-widest text-zinc-500 flex items-center gap-2">
              <RotateCcw size={16} className="text-red-500" /> Final Protocol Reset
            </h3>
          </div>
          <div className="p-8 flex items-center justify-between">
            <div className="max-w-md">
              <p className="font-bold text-zinc-200">Purge Sovereign State</p>
              <p className="text-xs text-zinc-500 mt-1">Wipes all keys, BIP-39 entropy, and cached ledger data. Action is terminal.</p>
            </div>
            <button type="button" onClick={appContext.resetEnclave} className="px-8 py-3 bg-red-600/10 border border-red-500/20 text-red-500 rounded-2xl font-black text-[10px] uppercase tracking-widest hover:bg-red-600 hover:text-white transition-all">
              Execute Purge
            </button>
          </div>
        </section>

        {/* Advanced */}
        <section className="bg-zinc-900/40 border border-zinc-800 rounded-3xl overflow-hidden">
          <div className="p-6 border-b border-zinc-800 bg-zinc-900/20">
            <h3 className="text-[10px] font-black uppercase tracking-widest text-zinc-500 flex items-center gap-2">
              <Lock size={16} className="text-green-600" /> Advanced Controls
            </h3>
          </div>
          <div className="p-8 grid grid-cols-1 md:grid-cols-2 gap-10">
            <div className="space-y-4">
              <label className="text-[10px] font-black uppercase text-zinc-600 flex items-center gap-2">
                Shop Mode (DEMO)
              </label>
              <div className="flex bg-zinc-950 border border-zinc-800 p-1 rounded-2xl">
                {[
                  { id: 'sovereign', label: 'Production' },
                  { id: 'simulation', label: 'Shop Demo' }
                ].map(opt => (
                  <button
                    key={opt.id}
                    type="button"
                    onClick={() => appContext.setMode(opt.id as any)}
                    className={`flex-1 py-3 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${
                      mode === opt.id ? 'bg-green-600 text-white shadow-lg' : 'text-zinc-600 hover:text-zinc-400'
                    }`}
                  >
                    {opt.label}
                  </button>
                ))}
              </div>
              <p className="text-[10px] text-zinc-500 italic">Demo restricts core features to marketplace simulations.</p>
            </div>

            <div className="space-y-4">
              <label className="text-[10px] font-black uppercase text-zinc-600 flex items-center gap-2">
                Network Selection
              </label>
              <select 
                value={network}
                onChange={(e) => appContext.setNetwork(e.target.value as Network)}
                className="w-full bg-zinc-950 border border-zinc-800 rounded-2xl px-5 py-4 text-sm focus:outline-none focus:ring-1 focus:ring-amber-600/50"
                aria-label="Network Selection"
                title="Network Selection"
              >
                <option value="mainnet">Mainnet (Production)</option>
                <option value="testnet">Testnet (Public)</option>
                <option value="regtest">Regtest (Local)</option>
                <option value="devnet">Devnet (Experimental)</option>
              </select>
              <p className="text-[10px] text-zinc-500 italic">Applies to BTC, Stacks, Liquid, and Rootstock endpoints.</p>
            </div>

            {/* Corporate Profile (Sovereign Entity) */}
            <div className="space-y-4 md:col-span-2 border-t border-zinc-800 pt-6 mt-2">
               <label className="text-[10px] font-black uppercase text-zinc-600 flex items-center gap-2">
                 <Briefcase size={12} /> Corporate Entity (Encrypted)
               </label>
               <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <input placeholder="Legal Entity Name" className="bg-zinc-950 border border-zinc-800 rounded-2xl px-5 py-3 text-sm focus:outline-none" />
                  <input placeholder="Tax / VAT ID (Optional)" className="bg-zinc-950 border border-zinc-800 rounded-2xl px-5 py-3 text-sm focus:outline-none" />
                  <input placeholder="Registered Address" className="md:col-span-2 bg-zinc-950 border border-zinc-800 rounded-2xl px-5 py-3 text-sm focus:outline-none" />
               </div>
               <p className="text-[10px] text-zinc-500 italic">These details are signed by your DID and included in PayJoin invoices.</p>
            </div>
            
            <div className="space-y-4">
              <label className="text-[10px] font-black uppercase text-zinc-600 flex items-center gap-2">
                Security Controls
              </label>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <span className="text-[10px] font-black uppercase text-zinc-600">Auto-Lock (minutes)</span>
                  <input 
                    type="number" 
                    min={1}
                    value={appContext.state.security?.autoLockMinutes ?? 5}
                    onChange={(e) => appContext.setSecurity({ autoLockMinutes: Math.max(1, parseInt(e.target.value || '1')) })}
                    className="w-full bg-zinc-950 border border-zinc-800 rounded-2xl px-5 py-4 text-sm focus:outline-none"
                    aria-label="Auto Lock Minutes"
                    title="Auto Lock Minutes"
                  />
                </div>
                <div>
                  <span className="text-[10px] font-black uppercase text-zinc-600">Duress PIN (optional)</span>
                  <input 
                    type="password"
                    value={appContext.state.security?.duressPin ?? ''}
                    onChange={(e) => appContext.setSecurity({ duressPin: e.target.value })}
                    className="w-full bg-zinc-950 border border-zinc-800 rounded-2xl px-5 py-4 text-sm focus:outline-none"
                    aria-label="Duress PIN"
                    title="Duress PIN"
                    placeholder="Enter duress PIN"
                  />
                  <p className="text-[10px] text-zinc-500 italic mt-1">Unlock with duress PIN loads a decoy wallet.</p>
                </div>
                <div className="md:col-span-2 flex items-center justify-between bg-zinc-950 border border-zinc-800 rounded-2xl px-5 py-4">
                  <div>
                    <span className="text-[10px] font-black uppercase text-zinc-600">Biometric Gate</span>
                    <p className="text-[10px] text-zinc-500 italic mt-1">Require device authentication before PIN entry.</p>
                  </div>
                  <button
                    type="button"
                    onClick={() => appContext.setSecurity({ biometricUnlock: !(appContext.state.security?.biometricUnlock ?? false) })}
                    className={`w-12 h-6 rounded-full transition-colors relative ${(appContext.state.security?.biometricUnlock ?? false) ? 'bg-amber-600' : 'bg-zinc-800'}`}
                    aria-label="Toggle Biometric Gate"
                    title="Toggle Biometric Gate"
                  >
                    <div className={`absolute top-0.5 w-5 h-5 rounded-full bg-white shadow-md transition-all ${(appContext.state.security?.biometricUnlock ?? false) ? 'left-6' : 'left-0.5'}`} />
                  </button>
                </div>
              </div>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
};

export default Settings;
