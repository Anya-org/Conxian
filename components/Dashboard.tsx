
import React, { useState, useEffect, useContext } from 'react';
import { LAYER_COLORS } from '../constants';
import { Asset, BitcoinLayer, UTXO } from '../types';
import { ArrowRight, Search, Loader2, Zap, Layers, Activity, Sparkles, Send, Plus, ShieldCheck, EyeOff, CheckCircle2, X, Binary, RefreshCw, Wallet, QrCode, Copy, ExternalLink, Database, RotateCcw, Lock as LockIcon } from 'lucide-react';
import { fetchBtcBalance, fetchStacksBalances, fetchBtcPrice, fetchLiquidBalance, fetchRskBalance, broadcastBtcTx, fetchRunesBalances, fetchBtcUtxos } from '../services/protocol';
import { SignRequest } from '../services/signer';
import { getRecommendedFees } from '../services/fees';
import { buildPsbt } from '../services/psbt';
import AssetDetailModal from './AssetDetailModal';
import SovereigntyMeter from './SovereigntyMeter';
import { AppContext } from '../context';
import { getTranslation } from '../services/i18n';
import * as QRCode from 'qrcode';

const Dashboard: React.FC = () => {
  const appContext = useContext(AppContext);
  const [searchQuery, setSearchQuery] = useState('');
  const [detailedAsset, setDetailedAsset] = useState<Asset | null>(null);
  const [isSyncing, setIsSyncing] = useState(false);
  const [showSend, setShowSend] = useState(false);
  const [showReceive, setShowReceive] = useState(false);

  // Send State
  const [sendStep, setSendStep] = useState<'form' | 'sign' | 'broadcast'>('form');
  const [sendAddress, setSendAddress] = useState('');
  const [sendAmount, setSendAmount] = useState('');
  const [feeRate, setFeeRate] = useState<number>(8);
  const [feesRec, setFeesRec] = useState<{ fastestFee?: number; halfHourFee?: number; hourFee?: number }>({});
  const [availableUtxos, setAvailableUtxos] = useState<UTXO[]>([]);
  const [selectedUtxos] = useState<string[]>([]);
  const [psbtBase64, setPsbtBase64] = useState<string>('');
  const [rbfEnabled, setRbfEnabled] = useState<boolean>(true);
  const [signedHex, setSignedHex] = useState('');
  const [isBroadcasting, setIsBroadcasting] = useState(false);
  const [isSigning, setIsSigning] = useState(false);
  const [receiveLayer, setReceiveLayer] = useState<BitcoinLayer>('Mainnet');

  if (!appContext) return null;
  const { mode, network, assets, privacyMode, walletConfig, language } = appContext.state;
  const btcAddress = walletConfig?.masterAddress || '';
  const stxAddress = walletConfig?.stacksAddress || '';

  const t = (key: string) => getTranslation(language, key);

  const syncAllLayers = async () => {
    if (mode === 'simulation' || !btcAddress) return;
    setIsSyncing(true);
    try {
        const btcPrice = await fetchBtcPrice();
        const results = await Promise.all([
            fetchBtcBalance(btcAddress, network),
            fetchStacksBalances(stxAddress, network),
            fetchLiquidBalance(btcAddress, network),
            fetchRskBalance(btcAddress, network),
            fetchRunesBalances(btcAddress)
        ]);

        const [btcBal, stxAssets, liqBal, rskBal, runeAssets] = results;
        const finalAssets: Asset[] = [
            { id: 'btc-main', name: 'Bitcoin', symbol: 'BTC', balance: btcBal, valueUsd: btcBal * btcPrice, layer: 'Mainnet', type: 'Native', address: btcAddress },
            ...stxAssets,
            ...runeAssets,
            { id: 'lbtc-main', name: 'Liquid BTC', symbol: 'L-BTC', balance: liqBal, valueUsd: liqBal * btcPrice, layer: 'Liquid', type: 'Wrapped', address: btcAddress },
            { id: 'rbtc-main', name: 'Smart BTC', symbol: 'RBTC', balance: rskBal, valueUsd: rskBal * btcPrice, layer: 'Rootstock', type: 'Native', address: btcAddress }
        ];
        appContext.updateAssets(finalAssets);
        appContext.notify('success', 'Ledger Synchronized via RPC');
    } catch (e) {
        console.error("Omni-Sync Failed", e);
        appContext.notify('error', 'Sync Failed: Node Unreachable');
    } finally {
        setIsSyncing(false);
    }
  };

  useEffect(() => {
    if (mode === 'sovereign' && btcAddress && assets.length === 0) syncAllLayers();
  }, [btcAddress]);

  useEffect(() => {
    if (btcAddress) {
      fetchBtcUtxos(btcAddress, network).then(setAvailableUtxos);
      const base = network === 'mainnet' ? 'https://mempool.space' : network === 'testnet' ? 'https://mempool.space/testnet' : 'https://mempool.space/signet';
      getRecommendedFees(base).then(setFeesRec);
    }
  }, [btcAddress, network]);

  const totalBalance = assets.reduce((acc, curr) => acc + curr.valueUsd, 0);

  // BIP-21 URI Generation
  const getBip21Uri = () => {
     if (receiveLayer === 'Mainnet') return `bitcoin:${btcAddress}?label=Conxius`;
     if (receiveLayer === 'Stacks') return `stacks:${stxAddress}`;
     return btcAddress;
  };

  const [qrSrc, setQrSrc] = useState<string>('');
  const [qrError, setQrError] = useState<boolean>(false);

  useEffect(() => {
    const generate = async () => {
        try {
            const data = getBip21Uri();
            // Local generation only - Privacy Preserved
            const dataUrl = await QRCode.toDataURL(data, { width: 240, margin: 1, color: { dark: '#000000', light: '#ffffff' } });
            setQrSrc(dataUrl);
            setQrError(false);
        } catch (e) {
            setQrError(true);
        }
    };
    generate();
  }, [receiveLayer, btcAddress, stxAddress]);

  const handleQrError = async () => {
    // Retry local generation
    try {
      const dataUrl = await QRCode.toDataURL(getBip21Uri(), { width: 240, margin: 1 });
      setQrSrc(dataUrl);
      setQrError(false);
    } catch (e) {
      setQrError(true);
    }
  };

  return (
    <div className="max-w-7xl mx-auto p-4 md:p-8 space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-1000 pb-32">
      
      {/* Network & Security Status */}
      <div className="flex flex-col md:flex-row md:items-center justify-between bg-surface-200/50 backdrop-blur-md border border-border/50 rounded-2xl px-6 py-3 gap-4">
         <div className="flex flex-wrap items-center gap-x-6 gap-y-2">
            <div className="flex items-center gap-2.5">
               <div className={`relative flex h-2 w-2`}>
                 <span className={`animate-ping absolute inline-flex h-full w-full rounded-full opacity-75 ${isSyncing ? 'bg-bitcoin' : 'bg-success'}`}></span>
                 <span className={`relative inline-flex rounded-full h-2 w-2 ${isSyncing ? 'bg-bitcoin' : 'bg-success'}`}></span>
               </div>
               <span className="text-[10px] font-bold uppercase text-white tracking-widest">
                 {isSyncing ? 'Synchronizing Nodes...' : 'Network Secured'}
               </span>
            </div>
            <div className="flex items-center gap-3 md:border-l border-border/50 md:pl-6">
               <span className="text-[10px] font-mono text-muted uppercase tracking-wider">BIP-84 • SIP-010 • PSBT Ready</span>
            </div>
         </div>
         <button 
           type="button" 
           onClick={syncAllLayers} 
           disabled={isSyncing}
           className="flex items-center gap-2 px-3 py-1.5 text-[10px] font-bold uppercase tracking-wider text-muted hover:text-white transition-colors disabled:opacity-50"
         >
            <RefreshCw size={12} className={isSyncing ? 'animate-spin' : ''} />
            <span>{isSyncing ? 'Syncing...' : 'Refresh'}</span>
         </button>
      </div>

      {/* Main Balance Card */}
      <div className="relative overflow-hidden rounded-3xl bg-gradient-to-br from-surface-100 to-surface-200 border border-border shadow-2xl p-8 md:p-12">
        {/* Background Decorative Element */}
        <div className="absolute top-0 right-0 -mt-20 -mr-20 w-64 h-64 bg-bitcoin/5 rounded-full blur-3xl" />
        
        <div className="relative z-10 flex flex-col md:flex-row md:items-end justify-between gap-8">
          <div className="space-y-6">
            <div className="space-y-1">
              <div className="flex items-center gap-2 text-muted">
                <ShieldCheck size={14} className="text-success" />
                <span className="text-[10px] font-bold uppercase tracking-widest">{t('balance.title')}</span>
              </div>
              <div className={`flex items-baseline gap-2 transition-all duration-700 ${privacyMode ? 'blur-2xl opacity-20' : 'blur-0'}`}>
                <span className="text-xs font-mono text-muted mb-4">$</span>
                <span className="text-5xl md:text-7xl font-bold tracking-tight text-white leading-none">
                  {totalBalance.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </span>
              </div>
            </div>
            
            <button 
              type="button"
              onClick={() => appContext.setPrivacyMode(!privacyMode)} 
              className="group flex items-center gap-2 text-[10px] font-bold uppercase tracking-widest text-muted hover:text-white transition-colors"
            >
                <div className="p-1.5 rounded-md bg-surface-300 group-hover:bg-surface-200 transition-colors">
                  {privacyMode ? <EyeOff size={12} /> : <Search size={12} />}
                </div>
                {privacyMode ? 'Reveal Balance' : 'Hide Balance'}
            </button>
          </div>

          <div className="flex items-center gap-3">
             <button 
               type="button" 
               onClick={() => { setShowSend(true); setSendStep('form'); }} 
               className="flex-1 md:flex-none bg-bitcoin hover:bg-bitcoin-dark text-black px-8 py-4 rounded-2xl transition-all font-bold shadow-lg shadow-bitcoin/20 flex items-center justify-center gap-2.5 active:scale-95 text-xs uppercase tracking-wider"
             >
               <Send size={16} /> 
               <span>{t('action.transmit')}</span>
             </button>
             <button 
               type="button" 
               onClick={() => setShowReceive(true)} 
               className="flex-1 md:flex-none bg-surface-300 hover:bg-surface-200 text-white px-8 py-4 rounded-2xl transition-all font-bold border border-border flex items-center justify-center gap-2.5 active:scale-95 text-xs uppercase tracking-wider"
             >
               <Plus size={16} className="text-bitcoin" /> 
               <span>{t('action.ingest')}</span>
             </button>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div className="lg:col-span-2 space-y-8">
          <div className="bg-surface-100 border border-border rounded-3xl overflow-hidden shadow-xl">
            <div className="px-8 py-6 border-b border-border/50 flex items-center justify-between bg-surface-200/30">
              <div className="flex items-center gap-3">
                <Layers size={16} className="text-bitcoin" />
                <h3 className="text-[10px] font-bold uppercase tracking-widest text-white">{t('assets.verified')}</h3>
              </div>
              <div className="relative group">
                <input 
                  type="text" 
                  value={searchQuery} 
                  onChange={(e) => setSearchQuery(e.target.value)} 
                  placeholder={t('assets.search')} 
                  className="bg-surface-300/50 border border-border rounded-xl pl-10 pr-4 py-2 text-xs focus:outline-none focus:ring-1 focus:ring-bitcoin/50 w-full md:w-64 transition-all" 
                />
                <Search className="absolute left-3.5 top-1/2 -translate-y-1/2 text-muted group-focus-within:text-bitcoin transition-colors" size={14} />
              </div>
            </div>
            <div className="divide-y divide-border/30">
              {assets.filter(a => a.name.toLowerCase().includes(searchQuery.toLowerCase()) || a.symbol.toLowerCase().includes(searchQuery.toLowerCase())).length === 0 ? (
                <div className="p-12 text-center space-y-3">
                  <div className="w-12 h-12 bg-surface-200 rounded-full flex items-center justify-center mx-auto text-muted">
                    <Database size={20} />
                  </div>
                  <p className="text-xs text-muted font-medium italic">No assets found in your vault</p>
                </div>
              ) : (
                assets.filter(a => a.name.toLowerCase().includes(searchQuery.toLowerCase()) || a.symbol.toLowerCase().includes(searchQuery.toLowerCase())).map(asset => (
                  <button 
                    key={asset.id} 
                    type="button"
                    onClick={() => setDetailedAsset(asset)} 
                    aria-label={`View details for ${asset.name}`}
                    className="w-full px-8 py-5 flex items-center justify-between hover:bg-surface-200/50 transition-all cursor-pointer group"
                  >
                    <div className="flex items-center gap-5">
                      <div className={`w-11 h-11 rounded-xl flex items-center justify-center font-bold text-white shadow-inner group-hover:scale-105 transition-transform ${LAYER_COLORS[asset.layer] || 'bg-surface-300'}`}>
                        {asset.symbol[0]}
                      </div>
                      <div className="space-y-1">
                        <div className="flex items-center gap-2">
                          <p className="text-sm font-bold text-white leading-none">{asset.name}</p>
                          <span className="text-[9px] font-bold uppercase px-1.5 py-0.5 bg-surface-300 text-muted rounded-md border border-border/50">{asset.type}</span>
                        </div>
                        <p className="text-[10px] font-bold uppercase text-muted tracking-wider">{asset.layer}</p>
                      </div>
                    </div>
                    <div className="text-right space-y-1">
                      <p className="text-sm font-bold text-white font-mono">
                        {asset.balance.toLocaleString(undefined, { 
                          minimumFractionDigits: asset.balance < 1 ? 8 : 2,
                          maximumFractionDigits: asset.balance < 1 ? 8 : 2 
                        })} {asset.symbol}
                      </p>
                      {asset.valueUsd > 0 && (
                        <p className="text-[10px] font-medium text-bitcoin">
                          ${asset.valueUsd.toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                        </p>
                      )}
                    </div>
                  </button>
                ))
              )}
            </div>
          </div>
        </div>

        <div className="space-y-8">
          <SovereigntyMeter score={appContext.state.sovereigntyScore} />
          
          {/* Quick Actions Card */}
          <div className="bg-surface-100 border border-border rounded-3xl p-6 space-y-6 shadow-xl">
             <div className="flex items-center gap-3">
                <Zap size={16} className="text-bitcoin" />
                <h3 className="text-[10px] font-bold uppercase tracking-widest text-white">Advanced Protocols</h3>
             </div>
             <div className="grid grid-cols-2 gap-3">
                <button type="button" className="flex flex-col items-center justify-center gap-3 p-4 bg-surface-200 hover:bg-surface-300 border border-border rounded-2xl transition-all group">
                   <div className="p-2 rounded-lg bg-bitcoin/10 text-bitcoin group-hover:scale-110 transition-transform">
                      <Activity size={18} />
                   </div>
                   <span className="text-[10px] font-bold uppercase tracking-wider text-muted group-hover:text-white">BitVM</span>
                </button>
                <button type="button" className="flex flex-col items-center justify-center gap-3 p-4 bg-surface-200 hover:bg-surface-300 border border-border rounded-2xl transition-all group">
                   <div className="p-2 rounded-lg bg-success/10 text-success group-hover:scale-110 transition-transform">
                      <LockIcon size={18} />
                   </div>
                   <span className="text-[10px] font-bold uppercase tracking-wider text-muted group-hover:text-white">Staking</span>
                </button>
                <button type="button" className="flex flex-col items-center justify-center gap-3 p-4 bg-surface-200 hover:bg-surface-300 border border-border rounded-2xl transition-all group">
                   <div className="p-2 rounded-lg bg-blue-500/10 text-blue-500 group-hover:scale-110 transition-transform">
                      <Binary size={18} />
                   </div>
                   <span className="text-[10px] font-bold uppercase tracking-wider text-muted group-hover:text-white">Ordinals</span>
                </button>
                <button type="button" className="flex flex-col items-center justify-center gap-3 p-4 bg-surface-200 hover:bg-surface-300 border border-border rounded-2xl transition-all group">
                   <div className="p-2 rounded-lg bg-purple-500/10 text-purple-500 group-hover:scale-110 transition-transform">
                      <Sparkles size={18} />
                   </div>
                   <span className="text-[10px] font-bold uppercase tracking-wider text-muted group-hover:text-white">Runes</span>
                </button>
             </div>
          </div>
        </div>
      </div>

      {/* SEND MODAL */}
      {showSend && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center p-4 bg-background/80 backdrop-blur-xl animate-in fade-in duration-300">
           <div className="w-full max-w-md bg-surface-100 border border-border rounded-[2.5rem] p-8 md:p-10 space-y-8 relative shadow-2xl overflow-hidden">
              <div className="absolute top-0 right-0 -mt-12 -mr-12 w-32 h-32 bg-bitcoin/5 rounded-full blur-2xl" />
              
              <button type="button" onClick={() => setShowSend(false)} aria-label="Close modal" className="absolute top-6 right-6 p-2 text-muted hover:text-white transition-colors bg-surface-200 rounded-full border border-border/50">
                <X size={20} />
              </button>
              
              <div className="text-center space-y-2">
                 <div className="w-16 h-16 bg-bitcoin/10 rounded-2xl flex items-center justify-center mx-auto text-bitcoin mb-4 shadow-inner">
                   <Send size={28} />
                 </div>
                 <h3 className="text-2xl font-bold tracking-tight text-white">{t('action.transmit')}</h3>
                 <p className="text-[10px] font-bold uppercase tracking-widest text-muted">Sovereign Transaction Construction</p>
              </div>

              {sendStep === 'form' && (
                  <div className="space-y-6 relative z-10">
                      <div className="space-y-2">
                          <label className="text-[10px] font-bold uppercase tracking-widest text-muted ml-1">Recipient Address</label>
                          <div className="relative group">
                            <input 
                              type="text" 
                              value={sendAddress}
                              onChange={(e) => setSendAddress(e.target.value)}
                              placeholder="bc1q..." 
                              className="w-full bg-surface-200 border border-border rounded-2xl p-4 text-sm font-mono text-white focus:outline-none focus:ring-1 focus:ring-bitcoin/50 transition-all"
                            />
                            <Wallet className="absolute right-4 top-1/2 -translate-y-1/2 text-muted group-focus-within:text-bitcoin transition-colors" size={16} />
                          </div>
                      </div>
                      
                      <div className="space-y-2">
                          <label className="text-[10px] font-bold uppercase tracking-widest text-muted ml-1">Amount (SATS)</label>
                          <div className="relative">
                            <input 
                              type="number" 
                              value={sendAmount}
                              onChange={(e) => setSendAmount(e.target.value)}
                              placeholder="0" 
                              className="w-full bg-surface-200 border border-border rounded-2xl p-4 text-sm font-mono text-white focus:outline-none focus:ring-1 focus:ring-bitcoin/50 transition-all"
                            />
                            <div className="absolute right-4 top-1/2 -translate-y-1/2 flex items-center gap-2">
                              <span className="text-[10px] font-bold text-bitcoin">MAX</span>
                            </div>
                          </div>
                      </div>

                      <div className="space-y-3">
                        <label className="text-[10px] font-bold uppercase tracking-widest text-muted ml-1">Network Fee Priority</label>
                        <div className="grid grid-cols-4 gap-2">
                          <button 
                            type="button" 
                            onClick={() => feesRec.fastestFee && setFeeRate(feesRec.fastestFee)} 
                            className={`flex flex-col items-center gap-1.5 p-2.5 rounded-xl border transition-all ${feeRate === feesRec.fastestFee ? 'bg-bitcoin/10 border-bitcoin text-bitcoin shadow-lg shadow-bitcoin/5' : 'bg-surface-200 border-border text-muted hover:border-muted'}`}
                          >
                            <Zap size={14} />
                            <span className="text-[9px] font-bold uppercase">Fast</span>
                          </button>
                          <button 
                            type="button" 
                            onClick={() => feesRec.halfHourFee && setFeeRate(feesRec.halfHourFee)} 
                            className={`flex flex-col items-center gap-1.5 p-2.5 rounded-xl border transition-all ${feeRate === feesRec.halfHourFee ? 'bg-success/10 border-success text-success shadow-lg shadow-success/5' : 'bg-surface-200 border-border text-muted hover:border-muted'}`}
                          >
                            <Activity size={14} />
                            <span className="text-[9px] font-bold uppercase">30m</span>
                          </button>
                          <button 
                            type="button" 
                            onClick={() => feesRec.hourFee && setFeeRate(feesRec.hourFee)} 
                            className={`flex flex-col items-center gap-1.5 p-2.5 rounded-xl border transition-all ${feeRate === feesRec.hourFee ? 'bg-surface-300 border-border text-muted' : 'bg-surface-200 border-border text-muted hover:border-muted'}`}
                          >
                            <Loader2 size={14} />
                            <span className="text-[9px] font-bold uppercase">1h</span>
                          </button>
                          <button 
                            type="button" 
                            onClick={() => setRbfEnabled(!rbfEnabled)} 
                            className={`flex flex-col items-center gap-1.5 p-2.5 rounded-xl border transition-all ${rbfEnabled ? 'bg-bitcoin/10 border-bitcoin text-bitcoin shadow-lg shadow-bitcoin/5' : 'bg-surface-200 border-border text-muted hover:border-muted'}`}
                          >
                            <RotateCcw size={14} />
                            <span className="text-[9px] font-bold uppercase">RBF</span>
                          </button>
                        </div>
                      </div>

                      <button type="button"
                        onClick={() => {
                          const utxos = availableUtxos.filter(u => selectedUtxos.includes(`${u.txid}:${u.vout}`));
                          const psbt = buildPsbt({
                            utxos,
                            toAddress: sendAddress,
                            amountSats: parseInt(sendAmount),
                            changeAddress: btcAddress,
                            feeRate,
                            rbf: rbfEnabled,
                            network
                          });
                          setPsbtBase64(psbt);
                          setSendStep('sign');
                        }}
                        disabled={!sendAddress || !sendAmount}
                        className="w-full bg-bitcoin hover:bg-bitcoin-dark text-black font-bold py-4 rounded-2xl uppercase tracking-widest transition-all disabled:opacity-30 disabled:grayscale shadow-lg shadow-bitcoin/20 flex items-center justify-center gap-2"
                      >
                        <span>Continue to Signing</span>
                        <ArrowRight size={16} />
                      </button>
                  </div>
              )}

              {sendStep === 'sign' && (
                  <div className="space-y-6 text-center animate-in fade-in slide-in-from-right-4">
                      <div className="bg-surface-200/50 p-6 rounded-2xl border border-border text-left space-y-4">
                          <div className="flex justify-between items-center pb-3 border-b border-border/50">
                              <span className="text-[10px] font-bold uppercase tracking-widest text-muted">Target</span>
                              <span className="font-mono text-xs text-white truncate w-32 text-right">{sendAddress}</span>
                          </div>
                          <div className="flex justify-between items-center pb-3 border-b border-border/50">
                              <span className="text-[10px] font-bold uppercase tracking-widest text-muted">Principal</span>
                              <span className="font-mono text-sm text-bitcoin font-bold">{parseInt(sendAmount).toLocaleString()} SATS</span>
                          </div>
                          <div className="flex justify-between items-center">
                              <span className="text-[10px] font-bold uppercase tracking-widest text-muted">Protocol Fee</span>
                              <span className="font-mono text-xs text-muted font-bold">~{feeRate * 140} SATS</span>
                          </div>
                      </div>
                      
                      <div className="space-y-3">
                        <button 
                          onClick={async () => {
                              setIsSigning(true);
                              try {
                                  const signReq: SignRequest = {
                                      type: 'transaction',
                                      layer: 'Mainnet',
                                      payload: { psbt: psbtBase64, network },
                                      description: `Sign PSBT`
                                  };
                                  const result = await appContext.authorizeSignature(signReq);
                                  setSignedHex(result.broadcastReadyHex || '');
                                  setSendStep('broadcast');
                              } catch (e) {
                                  appContext.notify('error', 'Signing Failed');
                              } finally {
                                  setIsSigning(false);
                              }
                          }}
                          disabled={isSigning}
                          className="w-full bg-bitcoin hover:bg-bitcoin-dark text-black font-bold py-4 rounded-2xl uppercase tracking-widest transition-all disabled:opacity-50 flex items-center justify-center gap-3 shadow-lg shadow-bitcoin/20"
                        >
                          {isSigning ? <Loader2 className="animate-spin" size={18} /> : <ShieldCheck size={18} />}
                          <span>{isSigning ? 'Signing in Enclave...' : 'Sign with Biometrics'}</span>
                        </button>
                        
                        <button 
                          onClick={() => setSendStep('form')}
                          className="w-full py-3 text-[10px] font-bold uppercase tracking-widest text-muted hover:text-white transition-colors"
                        >
                          Back to adjustment
                        </button>
                      </div>
                  </div>
              )}

              {sendStep === 'broadcast' && (
                  <div className="space-y-8 text-center animate-in zoom-in-95">
                      <div className="w-20 h-20 bg-success/10 rounded-full flex items-center justify-center mx-auto text-success mb-2 shadow-inner">
                          <CheckCircle2 size={40} />
                      </div>
                      <div className="space-y-2">
                        <h4 className="text-xl font-bold text-white">Signature Verified</h4>
                        <p className="text-xs text-muted">Transmission ready for mempool propagation</p>
                      </div>
                      
                      <div className="bg-surface-200 p-4 rounded-xl border border-border font-mono text-[10px] text-muted break-all overflow-hidden max-h-20 flex items-center justify-center">
                        {signedHex.substring(0, 64)}...
                      </div>
                      
                      <button 
                        onClick={async () => {
                            setIsBroadcasting(true);
                            try {
                                const txid = await broadcastBtcTx(signedHex, network);
                                appContext.notify('success', 'Transaction Broadcasted!');
                                setTimeout(() => { setShowSend(false); setSendStep('form'); }, 2000);
                            } catch (e) {
                                appContext.notify('error', 'Broadcast Failed');
                            } finally {
                                setIsBroadcasting(false);
                            }
                        }}
                        disabled={isBroadcasting}
                        className="w-full bg-success hover:bg-success/90 text-white font-bold py-4 rounded-2xl uppercase tracking-widest transition-all disabled:opacity-50 flex items-center justify-center gap-3 shadow-lg shadow-success/20"
                      >
                         {isBroadcasting ? <Loader2 className="animate-spin" size={18} /> : <Activity size={18} />}
                         <span>{isBroadcasting ? 'Propagating...' : 'Broadcast to Network'}</span>
                      </button>
                  </div>
              )}
           </div>
        </div>
      )}

      {/* RECEIVE MODAL */}
      {showReceive && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center p-4 bg-background/80 backdrop-blur-xl animate-in fade-in duration-300">
           <div className="w-full max-w-md bg-surface-100 border border-border rounded-[2.5rem] p-8 md:p-10 space-y-8 relative shadow-2xl overflow-hidden">
              <div className="absolute top-0 right-0 -mt-12 -mr-12 w-32 h-32 bg-bitcoin/5 rounded-full blur-2xl" />
              
              <button type="button" onClick={() => setShowReceive(false)} aria-label="Close modal" className="absolute top-6 right-6 p-2 text-muted hover:text-white transition-colors bg-surface-200 rounded-full border border-border/50">
                <X size={20} />
              </button>
              
              <div className="text-center space-y-2">
                 <div className="w-16 h-16 bg-bitcoin/10 rounded-2xl flex items-center justify-center mx-auto text-bitcoin mb-4 shadow-inner">
                   <QrCode size={28} />
                 </div>
                 <h3 className="text-2xl font-bold tracking-tight text-white">{t('action.ingest')}</h3>
                 <p className="text-[10px] font-bold uppercase tracking-widest text-muted">Secure Incoming Liquidity</p>
              </div>

              <div className="flex bg-surface-200 p-1.5 rounded-2xl border border-border">
                {(['Mainnet', 'Stacks', 'Rootstock'] as BitcoinLayer[]).map(l => (
                    <button 
                        key={l}
                        type="button"
                        onClick={() => setReceiveLayer(l)}
                        className={`flex-1 py-2.5 rounded-xl text-[10px] font-bold uppercase tracking-wider transition-all ${receiveLayer === l ? 'bg-bitcoin text-black shadow-lg shadow-bitcoin/20' : 'text-muted hover:text-white'}`}
                    >
                        {l}
                    </button>
                ))}
              </div>

              <div className="bg-surface-200/50 border border-border p-8 rounded-[2rem] flex flex-col items-center gap-6 relative z-10">
                 <div className="bg-white p-4 rounded-2xl shadow-2xl overflow-hidden ring-4 ring-bitcoin/10">
                    {!qrError ? (
                      <img src={qrSrc} onError={handleQrError} alt="Wallet Address QR Code" className="w-48 h-48" />
                    ) : (
                      <div className="w-48 h-48 flex items-center justify-center text-xs text-zinc-600 text-center px-4">
                        QR generation failed. Please use the address below.
                      </div>
                    )}
                 </div>
                 
                 <div className="w-full space-y-3">
                    <div className="flex items-center justify-between px-1">
                      <p className="text-[10px] font-bold text-muted uppercase tracking-widest">{receiveLayer} Address</p>
                      <button 
                        type="button"
                        aria-label="Share address"
                        onClick={() => {
                          const addr = receiveLayer === 'Stacks' ? stxAddress : btcAddress;
                          if (navigator.share) {
                            navigator.share({ title: 'My Bitcoin Address', text: addr });
                          } else {
                            navigator.clipboard.writeText(addr);
                            appContext.notify('info', 'Address Copied');
                          }
                        }}
                        className="text-bitcoin hover:text-bitcoin-dark transition-colors"
                      >
                        <ExternalLink size={14} />
                      </button>
                    </div>
                    
                    <div className="flex items-center gap-3 bg-surface-100 p-4 rounded-2xl border border-border group">
                       <p className="text-xs font-mono text-white truncate flex-1">{receiveLayer === 'Stacks' ? stxAddress : btcAddress}</p>
                       <button 
                         type="button"
                         aria-label="Copy address"
                         onClick={() => { 
                           navigator.clipboard.writeText(receiveLayer === 'Stacks' ? stxAddress : btcAddress); 
                           appContext.notify('info', 'Address Copied'); 
                         }} 
                         className="text-muted hover:text-bitcoin transition-colors p-1"
                       >
                         <Copy size={16} />
                       </button>
                    </div>
                 </div>
              </div>

              <div className="bg-bitcoin/5 border border-bitcoin/10 p-4 rounded-2xl flex items-start gap-3">
                <ShieldCheck size={16} className="text-bitcoin shrink-0 mt-0.5" />
                <p className="text-[10px] text-muted leading-relaxed">
                  Only send <span className="text-white font-bold">{receiveLayer === 'Mainnet' ? 'BTC' : receiveLayer === 'Stacks' ? 'STX/SIP-10' : 'RBTC'}</span> to this address. Sending other assets may result in permanent loss.
                </p>
              </div>
           </div>
        </div>
      )}

      {detailedAsset && <AssetDetailModal asset={detailedAsset} onClose={() => setDetailedAsset(null)} />}
    </div>
  );
};

export default Dashboard;
