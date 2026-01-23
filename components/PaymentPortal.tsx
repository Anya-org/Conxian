
import React, { useState, useEffect, useContext, useRef } from 'react';
import { Send, CreditCard, Zap, Globe, Smartphone, QrCode, ArrowRight, ShieldCheck, Loader2, CheckCircle2, Search, User, TrendingDown, Info, Sparkles, ShieldAlert, X, DollarSign } from 'lucide-react';
import { AppContext } from '../context';
import { BrowserMultiFormatReader } from '@zxing/browser';
import { isLnurl, decodeLnurl, fetchLnurlParams, decodeBolt11 } from '../services/lightning';
import { getLightningBackend } from '../services/lightning-backend';
import { fetchBtcUtxos, broadcastBtcTx } from '../services/protocol';
import { getRecommendedFees } from '../services/fees';
import { buildPsbt } from '../services/psbt';
import { parseBip21 } from '../services/bip21';
import { Network } from '../types';

const PaymentPortal: React.FC = () => {
  const context = useContext(AppContext);
  const [method, setMethod] = useState<'lightning' | 'onchain' | 'onramp'>('lightning');
  const [recipient, setRecipient] = useState('');
  const [amount, setAmount] = useState('');
  const [isSending, setIsSending] = useState(false);
  const [showSuccess, setShowSuccess] = useState(false);
  const [isSmartRouting, setIsSmartRouting] = useState(true);
  const [showPrivacyWarning, setShowPrivacyWarning] = useState(false);
  const [showScanner, setShowScanner] = useState(false);
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const [isScanning, setIsScanning] = useState(false);
  const [scanError, setScanError] = useState<string | null>(null);
  const [lnDetail, setLnDetail] = useState<any | null>(null);
  const [generatedInvoice, setGeneratedInvoice] = useState<string | null>(null);
  const [onchainTxid, setOnchainTxid] = useState<string | null>(null);
  const [onchainError, setOnchainError] = useState<string | null>(null);
  const [breezBalance, setBreezBalance] = useState<number | null>(null);

  useEffect(() => {
     // Poll for cached balance if Breez is active
     if (context?.state.lnBackend?.type === 'Breez' || context?.state.lnBackend?.type === 'Greenlight') {
         const check = async () => {
             try {
                const { getBreezInfo } = await import('../services/breez');
                const info = await getBreezInfo();
                setBreezBalance(info.maxPayableMsat / 1000); // sats
             } catch {}
         };
         check();
     }
  }, [context?.state.lnBackend]);

  const handleSend = async () => {
    // ... (existing Onchain Logic) ...
    if (method === 'onchain') {
      setIsSending(true);
      setShowSuccess(false);
      setOnchainTxid(null);
      setOnchainError(null);
      try {
        const network = (context?.state.network ?? 'mainnet') as Network;
        const fromAddress = context?.state.walletConfig?.masterAddress;
        if (!fromAddress) throw new Error('Wallet not configured');

        const parsed = parseBip21(recipient);
        const toAddress = parsed.address;
        const btcAmount = parsed.amount ?? Number(amount || '0');
        if (!toAddress) throw new Error('Invalid recipient');
        if (!Number.isFinite(btcAmount) || btcAmount <= 0) throw new Error('Invalid amount');

        // Check for PayJoin
        let payJoinResult: any = null;
        const { PayJoinService } = await import('../services/payjoin');
        const pjService = new PayJoinService(network);
        if (pjService.hasPayJoin(recipient)) {
             try {
                 context?.notify('info', 'Negotiating PayJoin privacy transaction...');
                 
                 // 1. Build Original PSBT (Simulated for brevity, typically uses same buildPsbt logic)
                 const utxos = await fetchBtcUtxos(fromAddress, network);
                 const amountSats = Math.floor(btcAmount * 100000000);
                 const base = network === 'mainnet' ? 'https://mempool.space' : 'https://mempool.space/testnet';
                 const fees = await getRecommendedFees(base);
                 
                 const originalPsbtObject = buildPsbt({
                    utxos, toAddress, amountSats, changeAddress: fromAddress, feeRate: fees.halfHourFee || 10, rbf: true, network
                 });
                 // Determine if we need to convert base64 back to Psbt object or if service takes hex/base64
                 // The service expects bitcoin.Psbt. Importing bitcoinjs-lib here dynamically or assuming it's available.
                 const bitcoin = await import('bitcoinjs-lib');
                 const originalPsbt = bitcoin.Psbt.fromBase64(originalPsbtObject as string);

                 // 2. Execute PayJoin
                 const result = await pjService.sendPayJoin(recipient, originalPsbt, async (psbtToSign) => {
                      // Callback to sign the PayJoin PSBT
                      const signed = await context?.authorizeSignature({
                          type: 'transaction',
                          layer: 'Mainnet',
                          payload: { psbt: psbtToSign.toBase64(), network },
                          description: 'Sign PayJoin Transaction'
                      });
                      if (!signed?.psbtBase64) throw new Error('User declined Sign or signing failed');
                      // Reconstruct PSBT from base64 string returned by authorizeSignature
                      return bitcoin.Psbt.fromBase64(signed.psbtBase64);
                 });
                 payJoinResult = result;
             } catch (e) {
                 console.warn("PayJoin failed, falling back to standard tx", e);
             }
        }

        if (payJoinResult) {
             const txid = await broadcastBtcTx(payJoinResult.txHex, network);
             setOnchainTxid(txid);
             setShowSuccess(true);
             context?.notify('success', `Privacy PayJoin Broadcasted: ${txid.substring(0, 12)}...`);
             setRecipient('');
             setAmount('');
             return;
        }

        // Standard Logic Fallback
        const amountSats = Math.floor(btcAmount * 100000000);
        const utxos = await fetchBtcUtxos(fromAddress, network);
        if (!utxos.length) throw new Error('No spendable UTXOs');

        const base =
          network === 'mainnet'
            ? 'https://mempool.space'
            : network === 'testnet'
              ? 'https://mempool.space/testnet'
              : network === 'regtest'
                ? 'http://127.0.0.1:3002'
                : 'https://mempool.space/signet';
        const fees = await getRecommendedFees(base);
        const feeRate = fees.halfHourFee || 8;

        const psbt = buildPsbt({
          utxos,
          toAddress,
          amountSats,
          changeAddress: fromAddress,
          feeRate,
          rbf: true,
          network
        });
        const signed = await context?.authorizeSignature({
          type: 'transaction',
          layer: 'Mainnet',
          payload: { psbt, network },
          description: 'Sign PSBT'
        });
        const rawHex = signed?.broadcastReadyHex;
        if (!rawHex) throw new Error('Signing failed');
        const txid = await broadcastBtcTx(rawHex, network);
        setOnchainTxid(txid);
        setShowSuccess(true);
        context?.notify('success', `Broadcasted: ${txid.substring(0, 12)}...`);
        setRecipient('');
        setAmount('');
      } catch (e: any) {
        const msg = e?.message || 'On-chain send failed';
        setOnchainError(msg);
        context?.notify('error', msg);
      } finally {
        setIsSending(false);
      }
      return;
    }

    if (method === 'lightning') {
      setIsSending(true);
      setShowSuccess(false);
      try {
        const backend = getLightningBackend(context?.state.lnBackend);
        if (!backend.configured) throw new Error('Lightning backend not configured');
        
        // Smart Check: Balance
        if (breezBalance !== null) {
            const sats = Math.floor(Number(amount || '0') * 100000000);
            if (sats > breezBalance) {
                throw new Error(`Insufficient Lightning Liquidity (Max: ${breezBalance} sats)`);
            }
        }

        if (lnDetail?.type === 'lnurl') {
          const sats = Math.floor(Number(amount || '0') * 100000000);
          if (!Number.isFinite(sats) || sats <= 0) throw new Error('Invalid amount');
          await backend.lnurlPay(lnDetail.params.callback, sats * 1000);
        } else if (lnDetail?.type === 'bolt11') {
          await backend.payInvoice(recipient);
        } else {
          throw new Error('Enter a BOLT11 invoice or LNURL');
        }

        setShowSuccess(true);
        setRecipient('');
        setAmount('');
      } catch (e: any) {
        context?.notify('error', e?.message || 'Lightning send failed');
      } finally {
        setIsSending(false);
      }
      return;
    }

    // ... Onramp logic ...
    setIsSending(true);
    setTimeout(() => {
      setIsSending(false);
      setShowSuccess(true);
      setTimeout(() => {
        setShowSuccess(false);
        setRecipient('');
        setAmount('');
      }, 3000);
    }, 2000);
  };


  const handleOnrampInitiate = () => {
    if (!context?.state.externalGatewaysActive) {
      setShowPrivacyWarning(true);
    } else {
      handleSend(); // Simulate GPay Flow
    }
  };

  const confirmGateway = () => {
    context?.toggleGateway(true);
    setShowPrivacyWarning(false);
    handleSend();
  };

  const getFees = () => {
    if (method === 'lightning') return { network: '0.00000001 BTC', integrator: '$0.00', savings: '$12.40' };
    if (method === 'onchain') return { network: '0.00012 BTC', integrator: '$0.00', savings: '$0.00' };
    return { network: '1.5% Spread', integrator: '$0.05', savings: '-$5.20 (KYC Cost)' };
  };

  const fees = getFees();
  const bolt11HasAmount = lnDetail?.type === 'bolt11' && !!lnDetail.info?.amountMsat;

  useEffect(() => {
    let reader: BrowserMultiFormatReader | null = null;
    let stop: (() => void) | null = null;
    if (showScanner) {
      setIsScanning(true);
      setScanError(null);
      reader = new BrowserMultiFormatReader();
      reader.decodeFromVideoDevice(undefined, videoRef.current!, (result, err) => {
        if (result) {
          const text = result.getText();
          setRecipient(text);
          handleRecipientChange(text);
          setShowScanner(false);
          if (stop) stop();
          setIsScanning(false);
        } else if (err && `${err}`.includes('NotFoundException')) {
        } else if (err) {
          setScanError('Camera error');
        }
      }).then(ctrl => { stop = () => ctrl.stop(); }).catch(e => { setScanError('Unable to access camera'); setIsScanning(false); });
    }
    return () => {
      if (stop) stop();
      reader = null;
    };
  }, [showScanner]);

  const handleRecipientChange = async (text: string) => {
    if (method !== 'lightning') return;
    try {
      if (isLnurl(text)) {
        const url = decodeLnurl(text);
        const params = await fetchLnurlParams(url);
        setLnDetail({ type: 'lnurl', params });
      } else {
        const info = decodeBolt11(text);
        setLnDetail({ type: 'bolt11', info });
      }
    } catch (e) {
      setLnDetail({ type: 'error' });
    }
  };

  return (
    <div className="p-8 max-w-4xl mx-auto space-y-10 animate-in fade-in duration-500 pb-24">
      <header className="flex justify-between items-end">
        <div className="space-y-1">
          <h2 className="text-4xl font-bold tracking-tight text-white italic uppercase">Transmit</h2>
          <p className="text-muted text-[10px] font-bold uppercase tracking-widest">Automated pathfinding for maximum cost efficiency</p>
        </div>
        <div className="flex items-center gap-3 bg-surface-200 border border-border px-5 py-2.5 rounded-2xl shadow-lg">
           <TrendingDown size={16} className="text-success" />
           <span className="text-[10px] font-bold uppercase text-muted tracking-widest">Saved: <span className="text-success">$154.50</span></span>
        </div>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-10">
        <div className="space-y-8">
          <div className="bg-surface-100 border border-border rounded-[2.5rem] p-8 space-y-8 shadow-2xl relative overflow-hidden">
            <div className="absolute top-0 right-0 -mt-20 -mr-20 w-64 h-64 bg-bitcoin/5 rounded-full blur-3xl pointer-events-none" />
            
            <div className="flex bg-surface-200 p-1.5 rounded-2xl border border-border overflow-hidden relative z-10">
              <button type="button" onClick={() => setMethod('lightning')} title="Lightning" className={`flex-1 flex items-center justify-center gap-2 py-3.5 rounded-xl text-[10px] font-bold uppercase tracking-[0.15em] transition-all ${method === 'lightning' ? 'bg-bitcoin text-black shadow-lg shadow-bitcoin/20' : 'text-muted hover:text-white'}`}><Zap size={14} /> Lightning</button>
              <button type="button" onClick={() => setMethod('onchain')} title="On-chain" className={`flex-1 flex items-center justify-center gap-2 py-3.5 rounded-xl text-[10px] font-bold uppercase tracking-[0.15em] transition-all ${method === 'onchain' ? 'bg-white text-black' : 'text-muted hover:text-white'}`}><Globe size={14} /> On-chain</button>
              <button type="button" onClick={() => setMethod('onramp')} title="Fiat On-ramp" className={`flex-1 flex items-center justify-center gap-2 py-3.5 rounded-xl text-[10px] font-bold uppercase tracking-[0.15em] transition-all ${method === 'onramp' ? 'bg-white text-black' : 'text-muted hover:text-white'}`}><Smartphone size={14} /> Fiat</button>
            </div>

            {/* Balance Display */}
            {method === 'lightning' && breezBalance !== null && (
               <div className="flex justify-end px-2 relative z-10">
                  <p className="text-[10px] font-bold uppercase text-muted tracking-widest">
                     Liquidity: <span className="text-bitcoin font-mono">{(breezBalance).toLocaleString()} sats</span>
                  </p>
               </div>
            )}

            <div className="space-y-8 relative z-10">
              {method !== 'onramp' ? (
                <>
                  <div className="space-y-3">
                    <label className="text-[10px] font-bold uppercase tracking-[0.2em] text-muted flex justify-between px-1">
                      Recipient 
                      <button type="button" onClick={() => setShowScanner(true)} className="text-bitcoin hover:text-bitcoin/80 flex items-center gap-1.5 font-bold transition-colors" aria-label="Scan QR" title="Scan QR">
                        <QrCode size={14} /> SCAN
                      </button>
                    </label>
                    <div className="relative group">
                      <input 
                        type="text" 
                        value={recipient} 
                        onChange={(e) => { setRecipient(e.target.value); handleRecipientChange(e.target.value); }} 
                        placeholder={method === 'lightning' ? 'Invoice or lnurl...' : 'bc1q... or handle.btc'} 
                        className="w-full bg-surface-200 border border-border rounded-2xl py-5 pl-6 pr-14 font-mono text-sm text-white focus:outline-none focus:border-bitcoin/50 focus:ring-1 focus:ring-bitcoin/20 transition-all placeholder:text-muted/40" 
                      />
                      <Search className="absolute right-6 top-1/2 -translate-y-1/2 text-muted/50 group-focus-within:text-bitcoin transition-colors" size={20} />
                    </div>
                  </div>

                  <div className="space-y-3">
                    <label className="text-[10px] font-bold uppercase tracking-[0.2em] text-muted px-1">Amount (BTC)</label>
                    <div className="relative">
                      <input 
                        type="number" 
                        value={amount} 
                        onChange={(e) => setAmount(e.target.value)} 
                        placeholder="0.00" 
                        className="w-full bg-surface-200 border border-border rounded-2xl py-7 px-8 text-5xl font-bold text-white focus:outline-none focus:border-bitcoin/50 focus:ring-1 focus:ring-bitcoin/20 transition-all font-mono tracking-tighter placeholder:text-muted/20" 
                      />
                      <div className="absolute right-8 top-1/2 -translate-y-1/2 text-xs font-bold text-muted/30 uppercase tracking-widest">BTC</div>
                    </div>
                  </div>
                  {method === 'lightning' && (
                    <div className="flex items-center gap-3">
                      <button type="button" onClick={async () => {
                        try {
                          const backend = getLightningBackend(context?.state.lnBackend);
                          const sats = Math.floor(parseFloat(amount || '0') * 100000000);
                          const inv = await backend.createInvoice(sats, 'Conxius');
                          setGeneratedInvoice(inv.invoice);
                        } catch {
                          setGeneratedInvoice(null);
                        }
                      }} className="px-5 py-3 bg-success/10 border border-success/20 hover:bg-success/20 text-success rounded-xl text-[10px] font-bold uppercase tracking-wider transition-all" aria-label="Generate Invoice">Generate Invoice</button>
                      {generatedInvoice && (
                        <button type="button" onClick={() => navigator.clipboard.writeText(generatedInvoice!)} className="px-5 py-3 bg-surface-200 border border-border text-white hover:border-bitcoin/50 rounded-xl text-[10px] font-bold uppercase tracking-wider transition-all" aria-label="Copy Invoice">Copy Invoice</button>
                      )}
                    </div>
                  )}
                </>
              ) : (
                <div className="space-y-8 animate-in fade-in duration-500">
                  <div className="bg-surface-200 border border-border rounded-3xl p-8 text-center space-y-6">
                     <div className="w-20 h-20 bg-white rounded-2xl mx-auto flex items-center justify-center shadow-2xl shadow-white/5">
                        <CreditCard className="text-black" size={40} />
                     </div>
                     <div className="space-y-2">
                        <h4 className="text-2xl font-bold text-white tracking-tight">Google Pay Gateway</h4>
                        <p className="text-[10px] text-muted font-bold uppercase tracking-widest leading-relaxed italic">Fast BTC on-ramping via your linked accounts. <br/><span className="text-bitcoin">Breaks Enclave Isolation.</span></p>
                     </div>
                     <div className="relative">
                        <input type="number" value={amount} onChange={(e) => setAmount(e.target.value)} placeholder="0.00" className="w-full bg-surface-100 border border-border rounded-2xl py-6 px-8 text-3xl font-bold text-white focus:outline-none text-center font-mono placeholder:text-muted/20" />
                        <span className="absolute right-8 top-1/2 -translate-y-1/2 text-[10px] font-bold text-muted uppercase tracking-widest">USD</span>
                     </div>
                  </div>
                </div>
              )}

              <div className="bg-surface-200/50 border border-border rounded-2xl p-6 space-y-5">
                 <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2.5">
                       <Sparkles size={16} className="text-bitcoin" />
                       <span className="text-[10px] font-bold uppercase text-muted tracking-[0.15em]">Protocol Optimizer</span>
                    </div>
                    <button type="button" onClick={() => setIsSmartRouting(!isSmartRouting)} className={`w-12 h-6 rounded-full transition-all relative ${isSmartRouting ? 'bg-bitcoin shadow-[0_0_15px_rgba(247,147,26,0.2)]' : 'bg-surface-100'}`} aria-label="Toggle Smart Routing" title="Toggle Smart Routing">
                       <div className={`absolute top-1 w-4 h-4 rounded-full bg-white shadow-md transition-all ${isSmartRouting ? 'left-7' : 'left-1'}`} />
                    </button>
                 </div>
                 <div className="grid grid-cols-2 gap-6 text-[10px] uppercase font-bold tracking-widest text-muted">
                    <div className="space-y-1.5">
                       <p className="opacity-60">Est. Network Fee</p>
                       <p className="text-white font-mono">{fees.network}</p>
                    </div>
                    <div className="space-y-1.5 text-right">
                       <p className={method === 'onramp' ? 'text-bitcoin' : 'text-success'}>{method === 'onramp' ? 'Privacy Loss' : 'Protocol Saving'}</p>
                       <p className={`${method === 'onramp' ? 'text-bitcoin' : 'text-success'} font-mono`}>{fees.savings}</p>
                    </div>
                 </div>
              </div>

              <button type="button"
                onClick={method === 'onramp' ? handleOnrampInitiate : handleSend}
                disabled={isSending || (method !== 'onramp' && !recipient) || (method === 'lightning' ? (!amount && !bolt11HasAmount) : (method !== 'onramp' && method !== 'onchain' && !amount)) || (method === 'onchain' && !amount && !parseBip21(recipient).amount) || showSuccess}
                className={`w-full font-bold py-6 rounded-3xl text-[10px] uppercase tracking-[0.2em] transition-all shadow-2xl flex items-center justify-center gap-3 active:scale-95 ${
                  showSuccess ? 'bg-success text-white' : 'bg-bitcoin hover:bg-bitcoin/90 text-black shadow-bitcoin/20'
                }`}
                aria-label="Execute Transfer"
                title="Execute Transfer"
              >
                {isSending ? <Loader2 size={18} className="animate-spin" /> : showSuccess ? <CheckCircle2 size={18} /> : <Send size={18} />}
                {isSending ? 'Broadcasting...' : showSuccess ? 'Transaction Sent' : method === 'onramp' ? 'Buy via Google Pay' : 'Transmit Assets'}
              </button>
              {method === 'onchain' && onchainError && (
                <div className="text-[10px] text-red-500 font-black uppercase tracking-widest">{onchainError}</div>
              )}
              {method === 'onchain' && onchainTxid && (
                <div className="bg-zinc-900/60 border border-zinc-800 rounded-2xl p-6">
                  <p className="text-[10px] uppercase font-black text-zinc-500">Broadcast Result</p>
                  <p className="text-xs font-mono text-zinc-300 break-all">{onchainTxid}</p>
                </div>
              )}
              {method === 'lightning' && lnDetail && (
                <div className="bg-zinc-900/60 border border-zinc-800 rounded-2xl p-6">
                  {lnDetail.type === 'lnurl' && (
                    <div className="text-[10px] uppercase font-black text-zinc-500 space-y-2">
                      <p>LNURL Detected</p>
                      <p className="text-zinc-300">Min: {(lnDetail.params.minSendable/1000).toLocaleString()} sats • Max: {(lnDetail.params.maxSendable/1000).toLocaleString()} sats</p>
                      <p className="text-zinc-400">Callback: {lnDetail.params.callback}</p>
                      <button type="button" onClick={async () => {
                        try {
                          const backend = getLightningBackend(context?.state.lnBackend);
                          const sats = Math.floor(parseFloat(amount || '0') * 100000000);
                          await backend.lnurlPay(lnDetail.params.callback, sats * 1000);
                          setShowSuccess(true);
                        } catch {
                          setShowPrivacyWarning(true);
                        }
                }} className="mt-3 px-4 py-2 bg-amber-600 text-white rounded-xl text-[10px] font-black uppercase" aria-label="Pay LNURL" title="Pay LNURL">Pay LNURL</button>
                    </div>
                  )}
                  {lnDetail.type === 'bolt11' && lnDetail.info && (
                    <div className="text-[10px] uppercase font-black text-zinc-500 space-y-2">
                      <p>BOLT11 Invoice</p>
                      <p className="text-zinc-300">Amount: {lnDetail.info.amountMsat ? Math.floor(lnDetail.info.amountMsat/1000).toLocaleString() : 'n/a'} sats</p>
                      <p className="text-zinc-400">Payee: {lnDetail.info.payee || 'unknown'}</p>
                    </div>
                  )}
                  {lnDetail.type === 'error' && <p className="text-[10px] text-red-500">Lightning decode failed</p>}
                </div>
              )}
        {method === 'lightning' && generatedInvoice && (
          <div className="bg-zinc-900/60 border border-zinc-800 rounded-2xl p-6">
            <p className="text-[10px] uppercase font-black text-zinc-500">Generated Invoice</p>
            <p className="text-xs font-mono text-zinc-300 break-all">{generatedInvoice}</p>
          </div>
        )}
            </div>
          </div>
        </div>

        <div className="space-y-8 animate-in slide-in-from-right-8 duration-700">
           {/* Transaction History / Status */}
           <div className="bg-surface-100 border border-border rounded-[2.5rem] p-8 space-y-6 h-full shadow-xl">
              <div className="flex items-center gap-3 mb-2">
                 <div className="w-10 h-10 bg-surface-200 rounded-xl flex items-center justify-center text-muted">
                    <Info size={20} />
                 </div>
                 <h3 className="font-bold text-lg text-white tracking-tight">Transmission Log</h3>
              </div>
              
              {/* Placeholder for history */}
              <div className="space-y-4">
                 {[1,2,3].map(i => (
                    <div key={i} className="flex items-center justify-between p-4 bg-surface-200/50 border border-border rounded-2xl">
                       <div className="flex items-center gap-3">
                          <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${i === 1 ? 'bg-bitcoin/10 text-bitcoin' : 'bg-surface-100 text-muted'}`}>
                             {i === 1 ? <Zap size={14} /> : <Globe size={14} />}
                          </div>
                          <div className="space-y-0.5">
                             <p className="text-xs font-bold text-white">Sent {i === 1 ? 'Lightning' : 'On-chain'}</p>
                             <p className="text-[10px] font-medium text-muted">2 mins ago</p>
                          </div>
                       </div>
                       <span className="text-xs font-mono text-white font-bold">-0.0024 BTC</span>
                    </div>
                 ))}
              </div>

              <div className="mt-auto pt-6 border-t border-border">
                 <div className="bg-bitcoin/5 border border-bitcoin/10 p-5 rounded-2xl">
                    <div className="flex gap-3">
                       <ShieldCheck className="text-bitcoin shrink-0" size={20} />
                       <div className="space-y-1">
                          <p className="text-[10px] font-bold text-bitcoin uppercase tracking-wider">Enclave Protection Active</p>
                          <p className="text-[10px] text-muted leading-relaxed font-medium">
                             All signatures are generated within the secure WASM environment. Keys never leave local memory.
                          </p>
                       </div>
                    </div>
                 </div>
              </div>
           </div>
        </div>
      </div>

      {/* Sovereign Warning Modal */}
      {showPrivacyWarning && (
        <div className="fixed inset-0 z-[200] flex items-center justify-center p-4 bg-black/90 backdrop-blur-lg animate-in fade-in duration-300">
           <div className="w-full max-w-md bg-zinc-950 border border-zinc-800 rounded-[3rem] p-10 space-y-8 relative shadow-[0_0_100px_rgba(249,115,22,0.1)]">
              <button type="button" onClick={() => setShowPrivacyWarning(false)} className="absolute top-8 right-8 text-zinc-700 hover:text-zinc-300 transition-colors" aria-label="Close Modal" title="Close Modal">
                <X size={24} />
              </button>
              <div className="text-center space-y-4">
                 <div className="w-20 h-20 bg-orange-600/10 border border-orange-500/20 rounded-[2rem] flex items-center justify-center mx-auto text-orange-500 shadow-inner">
                    <ShieldAlert size={40} />
                 </div>
                 <h3 className="text-2xl font-black italic uppercase tracking-tighter">Sovereignty Risk Detected</h3>
                 <p className="text-xs text-zinc-400 leading-relaxed italic">
                    By enabling the **Google Pay Gateway**, you are bridging your sovereign enclave to the legacy financial system. 
                 </p>
              </div>

              <div className="bg-zinc-900 border border-zinc-800 p-6 rounded-3xl space-y-4">
                 <div className="flex items-center gap-3">
                    <div className="w-1.5 h-1.5 rounded-full bg-red-500 shadow-lg shadow-red-500/50" />
                    <span className="text-[10px] font-black uppercase text-zinc-500 tracking-widest">Privacy Penalty: -15 Points</span>
                 </div>
                 <p className="text-[10px] text-zinc-600 italic">
                    Google will receive your wallet metadata, transaction amounts, and IP signature during the checkout process.
                 </p>
              </div>

              <div className="flex flex-col gap-3">
                 <button type="button"
                  onClick={confirmGateway}
                  className="w-full bg-zinc-100 hover:bg-white text-zinc-950 font-black py-5 rounded-[2rem] text-[10px] uppercase tracking-widest transition-all active:scale-95 shadow-2xl"
                 >
                    I Accept the Trade-off
                 </button>
                 <button type="button"
                  onClick={() => setShowPrivacyWarning(false)}
                  className="w-full py-4 text-zinc-600 hover:text-zinc-300 font-black text-[10px] uppercase tracking-widest transition-all"
                 >
                    Stay Native Only
                 </button>
              </div>
           </div>
        </div>
      )}
      {showScanner && (
        <div className="fixed inset-0 z-50 bg-black/90 backdrop-blur-md flex items-center justify-center p-6 animate-in fade-in duration-300">
          <div className="w-full max-w-md bg-surface-100 border border-border rounded-[2.5rem] overflow-hidden shadow-2xl relative">
             <button onClick={() => setShowScanner(false)} aria-label="Close scanner" className="absolute top-6 right-6 z-10 w-10 h-10 bg-black/50 text-white rounded-full flex items-center justify-center hover:bg-black/70 transition-colors backdrop-blur-sm">
                <X size={20} />
             </button>
             <div className="p-8 pb-0 text-center space-y-2 relative z-10">
                <h3 className="text-2xl font-bold text-white tracking-tight">Scan Invoice</h3>
                <p className="text-[10px] text-muted font-bold uppercase tracking-widest">Align QR code within the frame</p>
             </div>
             <div className="aspect-square relative mt-8 bg-black">
                <video ref={videoRef} className="w-full h-full object-cover opacity-80" />
                <div className="absolute inset-0 border-[3px] border-bitcoin/50 m-12 rounded-3xl shadow-[0_0_100px_rgba(247,147,26,0.2)] animate-pulse" />
                
                {/* Scanner Overlay Corners */}
                <div className="absolute top-12 left-12 w-8 h-8 border-l-4 border-t-4 border-bitcoin rounded-tl-xl" />
                <div className="absolute top-12 right-12 w-8 h-8 border-r-4 border-t-4 border-bitcoin rounded-tr-xl" />
                <div className="absolute bottom-12 left-12 w-8 h-8 border-l-4 border-b-4 border-bitcoin rounded-bl-xl" />
                <div className="absolute bottom-12 right-12 w-8 h-8 border-r-4 border-b-4 border-bitcoin rounded-br-xl" />
             </div>
             <div className="p-8 bg-surface-100 border-t border-border">
                {scanError ? (
                   <div className="flex items-center justify-center gap-2 text-red-500 font-bold text-xs uppercase tracking-wider">
                      <ShieldAlert size={16} /> {scanError}
                   </div>
                ) : (
                   <div className="flex items-center justify-center gap-2 text-bitcoin font-bold text-[10px] uppercase tracking-widest">
                      <Loader2 size={14} className="animate-spin" /> Searching for QR Pattern...
                   </div>
                )}
             </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default PaymentPortal;
