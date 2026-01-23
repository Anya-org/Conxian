
import React, { useState, useContext, useEffect } from 'react';
import { Binary, Snowflake, Shield, Info, Tag, Edit3, Lock, Unlock, Eye, EyeOff, Search, Loader2, RefreshCw } from 'lucide-react';
import { AppContext } from '../context';
import { UTXO } from '../types';
import { fetchBtcUtxos } from '../services/protocol';

const UTXOManager: React.FC = () => {
  const context = useContext(AppContext);
  const [utxos, setUtxos] = useState<UTXO[]>([]);
  const [filter, setFilter] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  // Use the first BTC address found in state or fallback to prompt
  const btcAsset = context?.state.assets.find(a => a.layer === 'Mainnet' && a.symbol === 'BTC');
  const activeAddress = btcAsset?.address;

  const loadUtxos = async () => {
    if (!activeAddress) return;
    setIsLoading(true);
    try {
        const realUtxos = await fetchBtcUtxos(activeAddress);
        setUtxos(realUtxos);
    } catch (e) {
        console.error("UTXO Indexer Error", e);
    } finally {
        setIsLoading(false);
    }
  };

  useEffect(() => {
    loadUtxos();
  }, [activeAddress]);

  const toggleFreeze = (txid: string) => {
    setUtxos(prev => prev.map(u => u.txid === txid ? { ...u, isFrozen: !u.isFrozen } : u));
  };

  const filteredUtxos = utxos.filter(u => 
    u.txid.includes(filter) || 
    u.address.includes(filter)
  );

  const totalSats = filteredUtxos.reduce((acc, u) => acc + u.amount, 0);
  const frozenSats = filteredUtxos.filter(u => u.isFrozen).reduce((acc, u) => acc + u.amount, 0);

  return (
    <div className="bg-zinc-950 border border-zinc-800 rounded-[3rem] p-8 shadow-2xl space-y-8 animate-in slide-in-from-bottom-4 duration-500">
      <div className="flex flex-col md:flex-row justify-between items-start md:items-end gap-6 border-b border-zinc-900 pb-8">
        <div>
          <h2 className="text-3xl font-black tracking-tighter text-zinc-100 flex items-center gap-3 italic uppercase">
            <Binary className="text-orange-500" />
            Coin Control Forge
          </h2>
          <p className="text-zinc-500 text-sm italic mt-2">
             Real-time indexer for {activeAddress?.slice(0, 12)}... UTXOs. 
          </p>
        </div>
        <div className="flex items-center gap-4">
            <button 
                type="button"
                aria-label="Refresh UTXOs"
                onClick={loadUtxos} 
                disabled={isLoading} 
                className="p-3 rounded-xl bg-zinc-900 border border-zinc-800 text-zinc-500 hover:text-orange-500"
            >
                <RefreshCw size={16} className={isLoading ? 'animate-spin' : ''} />
            </button>
            <div className="bg-zinc-900/50 border border-zinc-800 px-6 py-4 rounded-2xl text-right min-w-[200px]">
                <p className="text-[10px] font-black uppercase text-zinc-500 tracking-widest">Aggregate Liquid Satoshis</p>
                <div className="flex items-baseline justify-end gap-2">
                    <span className={`text-2xl font-mono font-bold text-zinc-100`}>
                        {(totalSats - frozenSats).toLocaleString()}
                    </span>
                    <span className="text-xs font-bold text-orange-500">SATS</span>
                </div>
            </div>
        </div>
      </div>

      <div className="flex flex-col md:flex-row gap-6">
         <div className="flex-1 relative">
            <input 
               type="text" 
               value={filter}
               onChange={(e) => setFilter(e.target.value)}
               placeholder="Search by TXID or Address..."
               className="w-full bg-zinc-900 border border-zinc-800 rounded-2xl py-4 pl-12 pr-4 font-mono text-sm text-zinc-200 focus:outline-none"
            />
            <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-600" size={18} />
         </div>
      </div>

      {isLoading ? (
        <div className="py-20 flex flex-col items-center gap-4 text-zinc-600">
            <Loader2 className="animate-spin text-orange-500" size={32} />
            <p className="text-[10px] font-black uppercase tracking-widest animate-pulse">Pulling Block Meta from Mempool...</p>
        </div>
      ) : (
        <div className="space-y-4">
            {filteredUtxos.map((utxo) => (
                <div 
                key={utxo.txid} 
                className={`p-6 rounded-[2rem] border transition-all duration-300 group ${
                    utxo.isFrozen ? 'bg-blue-900/10 border-blue-500/30' : 'bg-zinc-900/20 border-zinc-800'
                }`}
                >
                <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-6">
                    <div className="flex items-center gap-5">
                        <div className={`w-12 h-12 rounded-2xl flex items-center justify-center border ${
                            utxo.isFrozen ? 'bg-blue-500/10 border-blue-500/30 text-blue-500' : 'bg-zinc-950 border-zinc-800 text-zinc-500'
                        }`}>
                            {utxo.isFrozen ? <Snowflake size={20} /> : <Binary size={20} />}
                        </div>
                        <div>
                            <div className="flex items-center gap-3 mb-1">
                                <span className={`text-[9px] font-black uppercase px-2 py-0.5 rounded border ${
                                    utxo.privacyRisk === 'High' ? 'text-red-500 border-red-500/20' : 'text-green-500 border-green-500/20'
                                }`}>
                                    {utxo.privacyRisk} Risk
                                </span>
                                <span className="text-[9px] font-black uppercase text-zinc-700 bg-zinc-900 px-2 py-0.5 rounded">v84_legacy</span>
                            </div>
                            <p className="text-[10px] font-mono text-zinc-500 break-all">{utxo.txid}</p>
                        </div>
                    </div>

                    <div className="flex items-center gap-6">
                        <div className="text-right">
                            <p className="text-lg font-mono font-bold text-orange-500">{utxo.amount.toLocaleString()} sats</p>
                            <p className="text-[9px] font-black uppercase text-zinc-600">{utxo.status}</p>
                        </div>
                        <button 
                            type="button"
                            onClick={() => toggleFreeze(utxo.txid)}
                            aria-label={utxo.isFrozen ? "Unlock UTXO" : "Freeze UTXO"}
                            className={`p-3 rounded-xl border transition-all ${
                                utxo.isFrozen ? 'bg-blue-500 text-white' : 'bg-zinc-900 border-zinc-800 text-zinc-500'
                            }`}
                        >
                            {utxo.isFrozen ? <Unlock size={16} /> : <Lock size={16} />}
                        </button>
                    </div>
                </div>
                </div>
            ))}
        </div>
      )}

      {!isLoading && filteredUtxos.length === 0 && (
         <div className="text-center py-20 opacity-30 italic">
            No UTXOs discovered for the active sovereign address.
         </div>
      )}
    </div>
  );
};

export default UTXOManager;
