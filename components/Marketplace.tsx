
import React, { useState, useContext } from 'react';
import { ShoppingBag, Wifi, Gift, Zap, Globe, Smartphone, Search, Filter, Loader2, CheckCircle2, ShieldCheck, Ticket, Plane, Copy, QrCode, Tag, Lock } from 'lucide-react';
import { AppContext } from '../context';

type Category = 'Airtime' | 'Data' | 'Vouchers' | 'eSIM';

interface Product {
  id: string;
  name: string;
  description: string;
  priceSats: number;
  category: Category;
  icon: any;
  provider: string;
  region: string;
}

const MOCK_PRODUCTS: Product[] = [
  { id: '1', name: 'Global Ghost eSIM', description: '1GB Data, 30 Days. Works in 140 countries. No KYC.', priceSats: 25000, category: 'eSIM', icon: Plane, provider: 'Silent.Link', region: 'Global' },
  { id: '2', name: 'Africa Mobile Refill', description: '1000 NGN Airtime for MTN, Airtel, Glo.', priceSats: 12000, category: 'Airtime', icon: Smartphone, provider: 'Bitrefill', region: 'Nigeria' },
  { id: '3', name: 'AliExpress Voucher', description: '¥100 Shopping Credit. Global shipping.', priceSats: 28000, category: 'Vouchers', icon: Gift, provider: 'AliPay', region: 'China' },
  { id: '4', name: 'Uber Credits MENA', description: '50 AED Ride Credits. Valid in UAE, Egypt, Saudi.', priceSats: 25000, category: 'Vouchers', icon: Ticket, provider: 'Bitrefill', region: 'MENA' },
  { id: '5', name: 'Private VPN', description: '1 Month Mullvad VPN. Account number delivery.', priceSats: 8500, category: 'Data', icon: ShieldCheck, provider: 'Mullvad', region: 'Global' },
  { id: '6', name: 'LatAm Airtime', description: '50 BRL Claro/Vivo Recharge.', priceSats: 15000, category: 'Airtime', icon: Smartphone, provider: 'Bitrefill', region: 'Brazil' },
  { id: '7', name: 'M-Pesa Top-Up', description: '1000 KES mobile money credit.', priceSats: 14000, category: 'Airtime', icon: Smartphone, provider: 'Bitrefill', region: 'Kenya' },
  { id: '8', name: 'GrabFood Voucher', description: '500 PHP food delivery credit. Philippines/SEA.', priceSats: 18000, category: 'Vouchers', icon: Gift, provider: 'Grab', region: 'SEA' },
];

const Marketplace: React.FC = () => {
  const appContext = useContext(AppContext);
  const [activeCategory, setActiveCategory] = useState<Category | 'All'>('All');
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedProduct, setSelectedProduct] = useState<Product | null>(null);
  const [isProcessing, setIsProcessing] = useState(false);
  const [purchaseStep, setPurchaseStep] = useState<'select' | 'invoice' | 'success'>('select');
  const [regionFilter, setRegionFilter] = useState('All');
  
  // Advanced Filters
  const [providerFilter, setProviderFilter] = useState('All');
  const [minPrice, setMinPrice] = useState<string>('');
  const [maxPrice, setMaxPrice] = useState<string>('');

  if (!appContext) return null;
  const { mode } = appContext.state;

  // In sovereign mode, we don't show mock products.
  const productsToShow = mode === 'simulation' ? MOCK_PRODUCTS : [];
  if (mode === 'sovereign') {
    console.info('Marketplace offline in Sovereign mode');
  }

  const providers = ['All', ...Array.from(new Set(productsToShow.map(p => p.provider)))];

  const filteredProducts = productsToShow.filter(p => {
    const matchesCategory = activeCategory === 'All' || p.category === activeCategory;
    const matchesRegion = regionFilter === 'All' || p.region === regionFilter || p.region === 'Global';
    const matchesProvider = providerFilter === 'All' || p.provider === providerFilter;
    const matchesSearch = p.name.toLowerCase().includes(searchQuery.toLowerCase()) || p.provider.toLowerCase().includes(searchQuery.toLowerCase());
    
    const price = p.priceSats;
    const min = minPrice ? parseInt(minPrice) : 0;
    const max = maxPrice ? parseInt(maxPrice) : Infinity;
    const matchesPrice = price >= min && price <= max;

    return matchesCategory && matchesRegion && matchesProvider && matchesSearch && matchesPrice;
  });

  const handleBuy = (product: Product) => {
    setSelectedProduct(product);
    setPurchaseStep('invoice');
  };

  const simulatePayment = () => {
    setIsProcessing(true);
    setTimeout(() => {
      setIsProcessing(false);
      setPurchaseStep('success');
    }, 3000);
  };

  const closePurchase = () => {
    setSelectedProduct(null);
    setPurchaseStep('select');
  };

  return (
    <div className="p-8 max-w-7xl mx-auto space-y-10 animate-in fade-in duration-500 pb-24">
      <header className="flex flex-col md:flex-row md:items-end justify-between gap-6">
        <div>
          <h2 className="text-3xl font-black tracking-tighter text-zinc-100 flex items-center gap-3 italic uppercase">
            <ShoppingBag className="text-orange-500" />
            Sovereign Bazaar
          </h2>
          <p className="text-zinc-500 text-sm italic">Live on Bitcoin. Buy airtime, data, and essentials privately via Lightning.</p>
        </div>
        
        <div className="flex gap-4">
           <div className="bg-zinc-900 border border-zinc-800 px-6 py-3 rounded-2xl flex items-center gap-4">
              <div className="w-12 h-12 bg-green-500 rounded-xl flex items-center justify-center text-white shadow-lg">
                 <ShieldCheck size={24} />
              </div>
              <div>
                 <p className="text-[10px] font-black uppercase text-zinc-500">Privacy Status</p>
                 <div className="flex items-center gap-2">
                    <p className="text-sm font-bold text-zinc-200">No-KYC / Accountless</p>
                 </div>
              </div>
           </div>
        </div>
      </header>

      {/* Controls */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-8">
         <div className="lg:col-span-3 space-y-6">
            {/* Search */}
            <div className="relative">
               <input 
                  type="text" 
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="Search products..."
                  className="w-full bg-zinc-950 border border-zinc-800 rounded-2xl py-4 pl-12 pr-4 font-mono text-xs text-zinc-200 focus:outline-none focus:border-orange-500/50"
               />
               <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-zinc-600" size={16} />
            </div>

            {/* Region Filter */}
            <div className="bg-zinc-900/40 border border-zinc-800 rounded-[2rem] p-6 space-y-4">
               <h3 className="text-[10px] font-black uppercase tracking-widest text-zinc-500 flex items-center gap-2">
                  <Globe size={14} /> Region
               </h3>
               <div className="flex flex-wrap gap-2">
                  {['All', 'Global', 'Brazil', 'Nigeria', 'Kenya', 'China', 'MENA', 'SEA', 'EU'].map(r => (
                     <button 
                        key={r}
                        onClick={() => setRegionFilter(r)}
                        className={`px-3 py-1.5 rounded-lg text-[10px] font-bold uppercase transition-all ${
                           regionFilter === r 
                              ? 'bg-orange-500 text-white' 
                              : 'bg-zinc-950 border border-zinc-800 text-zinc-500 hover:border-zinc-700'
                        }`}
                     >
                        {r}
                     </button>
                  ))}
               </div>
            </div>

            {/* Provider Filter */}
            <div className="bg-zinc-900/40 border border-zinc-800 rounded-[2rem] p-6 space-y-4">
               <h3 className="text-[10px] font-black uppercase tracking-widest text-zinc-500 flex items-center gap-2">
                  <Tag size={14} /> Provider
               </h3>
               <div className="flex flex-wrap gap-2">
                  {providers.map(p => (
                     <button 
                        key={p}
                        onClick={() => setProviderFilter(p)}
                        className={`px-3 py-1.5 rounded-lg text-[10px] font-bold uppercase transition-all ${
                           providerFilter === p 
                              ? 'bg-purple-600 text-white' 
                              : 'bg-zinc-950 border border-zinc-800 text-zinc-500 hover:border-zinc-700'
                        }`}
                     >
                        {p}
                     </button>
                  ))}
               </div>
            </div>

            {/* Price Filter */}
            <div className="bg-zinc-900/40 border border-zinc-800 rounded-[2rem] p-6 space-y-4">
               <h3 className="text-[10px] font-black uppercase tracking-widest text-zinc-500 flex items-center gap-2">
                  <Zap size={14} /> Price Range (Sats)
               </h3>
               <div className="flex gap-2">
                  <input 
                     type="number" 
                     placeholder="Min" 
                     value={minPrice} 
                     onChange={(e) => setMinPrice(e.target.value)}
                     className="w-full bg-zinc-950 border border-zinc-800 rounded-xl py-2 px-3 text-[10px] text-zinc-200 focus:outline-none focus:border-orange-500/50"
                  />
                  <input 
                     type="number" 
                     placeholder="Max" 
                     value={maxPrice} 
                     onChange={(e) => setMaxPrice(e.target.value)}
                     className="w-full bg-zinc-950 border border-zinc-800 rounded-xl py-2 px-3 text-[10px] text-zinc-200 focus:outline-none focus:border-orange-500/50"
                  />
               </div>
            </div>

            {/* Categories */}
            <div className="space-y-2">
               {[
                  { id: 'All', icon: Filter, label: 'All Items' },
                  { id: 'eSIM', icon: Wifi, label: 'Ghost Data (eSIM)' },
                  { id: 'Airtime', icon: Smartphone, label: 'Mobile Refills' },
                  { id: 'Vouchers', icon: Gift, label: 'Gift Cards' },
                  { id: 'Data', icon: ShieldCheck, label: 'Privacy Tools' },
               ].map((cat) => (
                  <button
                     key={cat.id}
                     onClick={() => setActiveCategory(cat.id as any)}
                     className={`w-full flex items-center justify-between p-4 rounded-2xl border transition-all ${
                        activeCategory === cat.id 
                           ? 'bg-zinc-900 border-orange-500/50 text-zinc-100 shadow-lg' 
                           : 'bg-zinc-950 border-zinc-900 text-zinc-500 hover:border-zinc-800'
                     }`}
                  >
                     <div className="flex items-center gap-3">
                        <cat.icon size={16} className={activeCategory === cat.id ? 'text-orange-500' : 'text-zinc-600'} />
                        <span className="text-xs font-bold uppercase tracking-wide">{cat.label}</span>
                     </div>
                     {activeCategory === cat.id && <div className="w-1.5 h-1.5 rounded-full bg-orange-500" />}
                  </button>
               ))}
            </div>
         </div>

         {/* Product Grid */}
         <div className="lg:col-span-9">
            {mode === 'sovereign' ? (
                <div className="flex flex-col items-center justify-center h-96 opacity-70 space-y-4 border border-zinc-800 rounded-[2.5rem] bg-zinc-900/20">
                    <Lock size={48} className="text-zinc-700" />
                    <p className="text-sm font-bold text-zinc-500 uppercase tracking-widest">Marketplace Offline</p>
                    <p className="text-xs text-zinc-600 italic">Sovereign P2P Bazaar connection requires active tor circuit.</p>
                </div>
            ) : filteredProducts.length === 0 ? (
               <div className="flex flex-col items-center justify-center h-96 opacity-50 space-y-4">
                  <Search size={48} className="text-zinc-700" />
                  <p className="text-sm font-bold text-zinc-500">No products found matching your filters.</p>
                  <button 
                     onClick={() => {
                        setRegionFilter('All');
                        setProviderFilter('All');
                        setMinPrice('');
                        setMaxPrice('');
                        setSearchQuery('');
                     }}
                     className="text-[10px] uppercase font-black text-orange-500 hover:underline"
                     type="button"
                  >
                     Reset Filters
                  </button>
               </div>
            ) : (
               <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                  {filteredProducts.map((product) => (
                     <button 
                        key={product.id}
                        onClick={() => handleBuy(product)}
                        className="bg-zinc-900/20 border border-zinc-800 rounded-[2.5rem] p-6 text-left hover:bg-zinc-900/40 hover:border-orange-500/30 transition-all group flex flex-col h-full"
                        type="button"
                     >
                        <div className="flex justify-between items-start mb-6">
                           <div className="w-12 h-12 bg-zinc-950 rounded-2xl flex items-center justify-center border border-zinc-900 group-hover:border-zinc-800">
                              <product.icon size={20} className="text-zinc-400 group-hover:text-orange-500 transition-colors" />
                           </div>
                           <span className="text-[9px] font-black uppercase bg-zinc-950 text-zinc-500 px-2 py-1 rounded border border-zinc-900">{product.provider}</span>
                        </div>
                        
                        <div className="flex-1">
                           <h3 className="font-bold text-zinc-200 text-lg mb-1">{product.name}</h3>
                           <p className="text-xs text-zinc-500 leading-relaxed">{product.description}</p>
                        </div>

                        <div className="mt-6 pt-4 border-t border-zinc-800/50 flex items-center justify-between">
                           <div className="flex items-center gap-1.5">
                              <Zap size={14} className="text-yellow-500 fill-current" />
                              <span className="text-sm font-mono font-bold text-zinc-300">{product.priceSats.toLocaleString()}</span>
                              <span className="text-[10px] font-black uppercase text-zinc-600">Sats</span>
                           </div>
                           <span className="text-[9px] font-bold text-zinc-500 uppercase">{product.region}</span>
                        </div>
                     </button>
                  ))}
               </div>
            )}
         </div>
      </div>

      {/* Purchase Modal */}
      {selectedProduct && (
         <div className="fixed inset-0 z-[100] flex items-center justify-center p-4 bg-black/80 backdrop-blur-md animate-in fade-in duration-300">
            <div className="w-full max-w-md bg-zinc-950 border border-zinc-800 rounded-[3rem] p-8 space-y-6 relative shadow-2xl overflow-hidden">
               
               {purchaseStep === 'invoice' && (
                  <>
                     <div className="text-center space-y-2">
                        <h3 className="text-2xl font-black italic uppercase tracking-tighter text-zinc-100">Pay Invoice</h3>
                        <p className="text-xs text-zinc-500">Scan via Lightning to receive your code instantly.</p>
                     </div>

                     <div className="bg-white p-6 rounded-3xl mx-auto w-48 h-48 flex items-center justify-center relative overflow-hidden group cursor-pointer" onClick={simulatePayment}>
                        <QrCode size={120} className="text-zinc-950" />
                        {isProcessing && (
                           <div className="absolute inset-0 bg-white/90 flex items-center justify-center flex-col gap-2">
                              <Loader2 size={32} className="animate-spin text-orange-600" />
                              <span className="text-[10px] font-black uppercase tracking-widest text-zinc-950">Detecting...</span>
                           </div>
                        )}
                        <div className="absolute inset-0 bg-black/5 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center">
                           <span className="text-[10px] font-black text-zinc-900 uppercase">Click to Simulate</span>
                        </div>
                     </div>

                     <div className="bg-zinc-900/50 rounded-2xl p-4 border border-zinc-900 flex items-center justify-between">
                        <div className="space-y-1">
                           <p className="text-[9px] font-black uppercase text-zinc-600">Total Due</p>
                           <p className="text-lg font-mono font-bold text-orange-500">{selectedProduct.priceSats.toLocaleString()} sats</p>
                        </div>
                        <button type="button" className="p-2 bg-zinc-800 rounded-xl text-zinc-400 hover:text-white transition-colors" aria-label="Copy Total Due">
                           <Copy size={16} />
                        </button>
                     </div>

                     <button onClick={closePurchase} className="w-full py-4 text-zinc-600 hover:text-zinc-400 font-bold text-xs uppercase tracking-widest transition-all">
                        Cancel Purchase
                     </button>
                  </>
               )}

               {purchaseStep === 'success' && (
                  <div className="text-center space-y-6 py-4 animate-in zoom-in duration-300">
                     <div className="w-20 h-20 bg-green-500/20 rounded-full flex items-center justify-center mx-auto text-green-500 border border-green-500/20">
                        <CheckCircle2 size={40} />
                     </div>
                     <div>
                        <h3 className="text-2xl font-black text-white uppercase italic tracking-tighter">Payment Verified</h3>
                        <p className="text-xs text-zinc-500 mt-2">Your sovereign goods are ready.</p>
                     </div>

                     <div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-6 text-left space-y-2">
                        <p className="text-[9px] font-black uppercase text-zinc-600">Redemption Code</p>
                        <div className="flex items-center justify-between">
                           <p className="text-xl font-mono font-bold text-zinc-200 tracking-wider">XT92-4B8A-CODE</p>
                           <Copy size={16} className="text-zinc-500 cursor-pointer hover:text-white" />
                        </div>
                        <p className="text-[9px] text-zinc-600 italic border-t border-zinc-800 pt-2 mt-2">
                           Sent by {selectedProduct.provider}. No refund on digital goods.
                        </p>
                     </div>

                     <button 
                        onClick={closePurchase}
                        className="w-full py-4 bg-amber-600 hover:bg-amber-500 text-white font-black rounded-2xl text-[10px] uppercase tracking-widest shadow-xl active:scale-95 transition-all"
                        type="button"
                     >
                        Done
                     </button>
                  </div>
               )}
            </div>
         </div>
      )}
    </div>
  );
};

export default Marketplace;
