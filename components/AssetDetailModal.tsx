
import React, { useState, useEffect } from 'react';
import { Asset, Transaction } from '../types';
import { X, ArrowUpRight, ArrowDownLeft, Clock, Bot, Loader2, ExternalLink, History, ShieldCheck, Sparkles, AlertTriangle } from 'lucide-react';
import { LAYER_COLORS, MOCK_TRANSACTIONS } from '../constants';
import { getAssetInsight } from '../services/gemini';

interface AssetDetailModalProps {
  asset: Asset;
  onClose: () => void;
}

const AssetDetailModal: React.FC<AssetDetailModalProps> = ({ asset, onClose }) => {
  const [insight, setInsight] = useState<string | null>(null);
  const [isLoadingInsight, setIsLoadingInsight] = useState(false);

  useEffect(() => {
    const fetchInsight = async () => {
      setIsLoadingInsight(true);
      const res = await getAssetInsight(asset);
      setInsight(res ?? null);
      setIsLoadingInsight(false);
    };
    fetchInsight();
  }, [asset]);

  // Strictly filter by both symbol and layer as requested, then sort by newest first
  const assetTransactions = MOCK_TRANSACTIONS
    .filter(tx => tx.asset === asset.symbol && tx.layer === asset.layer)
    .sort((a, b) => b.timestamp - a.timestamp);

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-background/80 backdrop-blur-xl animate-in fade-in duration-300">
      <div 
        className="absolute inset-0 transition-opacity duration-300" 
        onClick={onClose}
      />
      
      <div className="relative w-full max-w-2xl bg-surface-100 border border-border rounded-[2.5rem] overflow-hidden shadow-2xl flex flex-col max-h-[90vh] animate-in zoom-in-95 duration-300">
        <div className="absolute top-0 right-0 -mt-24 -mr-24 w-64 h-64 bg-bitcoin/5 rounded-full blur-3xl pointer-events-none" />
        
        {/* Header */}
        <div className="p-8 md:p-10 border-b border-border flex justify-between items-start relative z-10">
          <div className="flex items-center gap-6">
            <div className={`w-16 h-16 rounded-2xl flex items-center justify-center font-bold text-3xl text-white shadow-xl ${LAYER_COLORS[asset.layer] || 'bg-surface-300'}`}>
              {asset.symbol[0]}
            </div>
            <div className="space-y-1">
              <div className="flex items-center gap-3">
                <h2 className="text-2xl font-bold tracking-tight text-white">{asset.name}</h2>
                <div title="D.i.D Verified Asset" className="flex items-center justify-center p-1 bg-bitcoin/10 rounded-full">
                  <ShieldCheck size={16} className="text-bitcoin" />
                </div>
              </div>
              <div className="flex items-center gap-2">
                <span className="text-[10px] font-bold uppercase text-muted tracking-[0.2em]">{asset.layer}</span>
                <div className="w-1 h-1 rounded-full bg-border" />
                <span className="text-[10px] text-muted font-bold uppercase tracking-wider">{asset.type}</span>
              </div>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            aria-label="Close modal"
            className="p-2.5 bg-surface-200 hover:bg-surface-300 border border-border rounded-full text-muted hover:text-white transition-all active:scale-95"
          >
            <X size={20} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto p-8 md:p-10 space-y-10 custom-scrollbar relative z-10">
          {asset.layer === 'Liquid' && (
            <div className="bg-bitcoin/5 border border-bitcoin/10 rounded-2xl p-5 flex items-start gap-3">
              <AlertTriangle size={16} className="text-bitcoin shrink-0 mt-0.5" />
              <p className="text-[10px] text-muted leading-relaxed font-bold uppercase tracking-wider">
                Liquid balances are read from public explorer APIs and do not include confidential asset support.
              </p>
            </div>
          )}

          {/* Stats Grid */}
          <div className="grid grid-cols-2 gap-6">
            <div className="bg-surface-200/50 p-6 rounded-3xl border border-border shadow-inner group hover:border-bitcoin/30 transition-colors">
              <p className="text-muted text-[10px] mb-2 font-bold uppercase tracking-widest">Available Balance</p>
              <p className="text-2xl font-bold tracking-tight text-white font-mono">
                {asset.balance.toLocaleString()} <span className="text-muted text-sm font-normal uppercase ml-1">{asset.symbol}</span>
              </p>
            </div>
            <div className="bg-surface-200/50 p-6 rounded-3xl border border-border shadow-inner group hover:border-bitcoin/30 transition-colors">
              <p className="text-muted text-[10px] mb-2 font-bold uppercase tracking-widest">Market Valuation</p>
              <p className="text-2xl font-bold text-bitcoin tracking-tight font-mono">
                ${asset.valueUsd.toLocaleString()}
              </p>
            </div>
          </div>

          {/* AI Insights Section */}
          <div className="bg-surface-200 border border-border rounded-[2rem] p-8 relative overflow-hidden group shadow-xl">
            <div className="absolute top-0 right-0 p-8 opacity-[0.03] group-hover:opacity-[0.07] transition-opacity pointer-events-none">
              <Bot size={120} />
            </div>
            <div className="relative z-10 space-y-5">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-3">
                  <div className="bg-bitcoin/10 p-2 rounded-xl text-bitcoin">
                    <Sparkles size={18} />
                  </div>
                  <h3 className="font-bold text-[10px] uppercase tracking-[0.2em] text-bitcoin">Protocol Insight Engine</h3>
                </div>
                <div className="flex items-center gap-1.5 px-2 py-1 bg-surface-300 rounded-lg border border-border">
                  <div className="w-1 h-1 rounded-full bg-success animate-pulse" />
                  <span className="text-[8px] font-bold text-muted uppercase tracking-tighter">AI Analysis Live</span>
                </div>
              </div>
              <div className="text-xs text-zinc-300 leading-relaxed min-h-[100px] bg-surface-100/50 p-5 rounded-2xl border border-border italic shadow-inner">
                {isLoadingInsight ? (
                  <div className="flex flex-col items-center justify-center py-8 gap-4 text-muted">
                    <Loader2 className="animate-spin text-bitcoin" size={24} />
                    <span className="text-[10px] font-bold uppercase tracking-widest animate-pulse">Scanning On-Chain Metrics...</span>
                  </div>
                ) : (
                  <p className="whitespace-pre-wrap leading-relaxed opacity-90">{insight}</p>
                )}
              </div>
            </div>
          </div>

          {/* Transaction History Section */}
          <div className="space-y-6">
            <div className="flex items-center justify-between px-2">
              <div className="flex items-center gap-3">
                <div className="p-1.5 bg-surface-200 rounded-lg text-muted">
                  <History size={16} />
                </div>
                <h3 className="font-bold text-[10px] uppercase tracking-[0.2em] text-white">Layer Activity Ledger</h3>
              </div>
              <button 
                type="button" 
                className="text-[10px] font-bold uppercase tracking-widest text-muted hover:text-bitcoin transition-all flex items-center gap-2 group" 
                aria-label="Open Explorer" 
                title="Open Explorer"
              >
                Explorer <ExternalLink size={12} className="group-hover:translate-x-0.5 group-hover:-translate-y-0.5 transition-transform" />
              </button>
            </div>
            
            <div className="space-y-3">
              {assetTransactions.length > 0 ? (
                assetTransactions.map(tx => (
                  <div 
                    key={tx.id} 
                    className="bg-surface-200/30 hover:bg-surface-200/60 border border-border p-5 rounded-2xl flex items-center justify-between group transition-all duration-300 hover:scale-[1.01] shadow-sm hover:shadow-md"
                  >
                    <div className="flex items-center gap-5">
                      <div className={`w-12 h-12 rounded-xl flex items-center justify-center shadow-inner ${
                        tx.type === 'receive' ? 'bg-success/10 text-success' : 
                        tx.type === 'send' ? 'bg-red-500/10 text-red-500' : 
                        'bg-bitcoin/10 text-bitcoin'
                      }`}>
                        {tx.type === 'receive' ? <ArrowDownLeft size={20} /> : 
                         tx.type === 'send' ? <ArrowUpRight size={20} /> : 
                         <Bot size={20} />}
                      </div>
                      <div className="space-y-1">
                        <div className="text-sm font-bold text-white uppercase tracking-tight">{tx.type}</div>
                        <div className="text-[10px] text-muted font-bold uppercase tracking-widest flex items-center gap-2">
                          <span>{new Date(tx.timestamp).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })}</span>
                          <div className="w-1 h-1 rounded-full bg-border" />
                          <span className="opacity-70">{tx.counterparty}</span>
                        </div>
                      </div>
                    </div>
                    <div className="text-right space-y-1.5">
                      <div className={`text-sm font-bold font-mono ${
                        tx.type === 'receive' ? 'text-success' : 'text-white'
                      }`}>
                        {tx.type === 'receive' ? '+' : '-'}{tx.amount.toLocaleString()} {tx.asset}
                      </div>
                      <div className={`text-[8px] font-bold uppercase tracking-[0.15em] px-2 py-0.5 rounded-full border ${
                        tx.status === 'completed' ? 'border-border text-muted bg-surface-200/50' : 'border-bitcoin/30 text-bitcoin bg-bitcoin/5'
                      }`}>
                        {tx.status}
                      </div>
                    </div>
                  </div>
                ))
              ) : (
                <div className="py-20 text-center border-2 border-dashed border-border rounded-[2.5rem] flex flex-col items-center gap-4 bg-surface-200/10">
                  <div className="w-16 h-16 rounded-2xl bg-surface-200 flex items-center justify-center text-muted shadow-inner">
                    <Clock size={32} />
                  </div>
                  <div className="space-y-1.5 px-10">
                    <p className="text-white font-bold text-sm uppercase tracking-widest">No Activity Detected</p>
                    <p className="text-muted text-[10px] font-medium leading-relaxed uppercase tracking-wider">Zero recorded transactions for {asset.symbol} on the {asset.layer} layer.</p>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Footer Actions */}
        <div className="p-8 md:p-10 bg-surface-100 border-t border-border flex gap-5 relative z-10">
          <button type="button" className="flex-1 bg-surface-200 hover:bg-surface-300 text-white font-bold py-4 rounded-2xl transition-all border border-border active:scale-95 shadow-lg flex items-center justify-center gap-2 uppercase text-[10px] tracking-[0.2em]">
            Deposit
          </button>
          <button type="button" className="flex-1 bg-bitcoin hover:bg-bitcoin/90 text-black font-bold py-4 rounded-2xl transition-all shadow-xl shadow-bitcoin/20 active:scale-95 flex items-center justify-center gap-2 uppercase text-[10px] tracking-[0.2em]">
            Transmit {asset.symbol}
          </button>
        </div>
      </div>
    </div>
  );
};

export default AssetDetailModal;
