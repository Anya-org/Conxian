
import React, { useState, useRef, useEffect } from 'react';
import { Terminal, Send, Bot, Loader2, X, Sparkles, ChevronRight } from 'lucide-react';
import { GoogleGenAI } from "@google/genai";

const SatoshiAIChat: React.FC = () => {
  const [isOpen, setIsOpen] = useState(false);
  const [messages, setMessages] = useState<{ role: 'user' | 'ai'; content: string }[]>([
    { role: 'ai', content: "I am Satoshi AI. Ask me about your sovereign risk, L2 alpha, or the genesis block secrets." }
  ]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (scrollRef.current) scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
  }, [messages]);

  const handleSend = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!input.trim() || isLoading) return;

    const userMessage = input;
    setInput('');
    setMessages(prev => [...prev, { role: 'user', content: userMessage }]);
    setIsLoading(true);

    try {
      const ai = new GoogleGenAI({ apiKey: process.env.API_KEY });
      const response = await ai.models.generateContent({
        model: 'gemini-3-flash-preview',
        contents: userMessage,
        config: {
          systemInstruction: "You are Satoshi AI, a master of Bitcoin technology and sovereign finance. You are concise, technical, and prioritize user privacy. You help users understand Bitcoin layers and risk. Use a terminal-style tone.",
        }
      });

      setMessages(prev => [...prev, { role: 'ai', content: response.text || "Connection to the network lost." }]);
    } catch (error) {
      setMessages(prev => [...prev, { role: 'ai', content: "An error occurred in the mempool. Try again later." }]);
    } finally {
      setIsLoading(false);
    }
  };

  if (!isOpen) {
    return (
      <button 
        onClick={() => setIsOpen(true)}
        className="fixed bottom-24 right-4 md:bottom-8 md:right-8 w-12 h-12 md:w-14 md:h-14 bg-orange-600 text-white rounded-2xl shadow-2xl shadow-orange-600/40 flex items-center justify-center hover:scale-110 active:scale-95 transition-all z-[60] border border-orange-500/20"
      >
        <Bot size={24} className="md:w-7 md:h-7" />
      </button>
    );
  }

  return (
    <div className="fixed bottom-24 right-4 md:bottom-8 md:right-8 w-[calc(100vw-2rem)] md:w-96 h-[500px] bg-zinc-950 border border-zinc-800 rounded-[2.5rem] shadow-2xl z-[70] flex flex-col overflow-hidden animate-in slide-in-from-bottom-8 duration-300">
      <div className="p-5 border-b border-zinc-900 bg-zinc-900/50 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <Terminal size={18} className="text-orange-500" />
          <h3 className="font-bold text-sm tracking-tight">Satoshi Terminal</h3>
        </div>
        <button onClick={() => setIsOpen(false)} className="p-1 hover:bg-zinc-800 rounded-lg text-zinc-500">
          <X size={18} />
        </button>
      </div>

      <div ref={scrollRef} className="flex-1 overflow-y-auto p-5 space-y-4 custom-scrollbar bg-[radial-gradient(circle_at_center,_#09090b_0%,_#000000_100%)]">
        {messages.map((m, i) => (
          <div key={i} className={`flex ${m.role === 'user' ? 'justify-end' : 'justify-start'}`}>
            <div className={`max-w-[85%] p-3 rounded-2xl text-xs leading-relaxed ${
              m.role === 'user' 
                ? 'bg-orange-600 text-white shadow-lg' 
                : 'bg-zinc-900 border border-zinc-800 text-zinc-300 font-mono'
            }`}>
              {m.role === 'ai' && <ChevronRight size={12} className="inline mr-1 text-orange-500" />}
              {m.content}
            </div>
          </div>
        ))}
        {isLoading && (
          <div className="flex justify-start">
            <div className="bg-zinc-900 border border-zinc-800 p-3 rounded-2xl text-orange-500 flex items-center gap-2">
              <Loader2 size={14} className="animate-spin" />
              <span className="text-[10px] font-mono uppercase">Thinking...</span>
            </div>
          </div>
        )}
      </div>

      <form onSubmit={handleSend} className="p-4 bg-zinc-950 border-t border-zinc-900 flex gap-2">
        <input 
          autoFocus
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="Ask Satoshi anything..."
          className="flex-1 bg-zinc-900 border border-zinc-800 rounded-xl px-4 py-2 text-xs focus:outline-none focus:ring-1 focus:ring-orange-500/50 text-zinc-200"
        />
        <button 
          disabled={isLoading || !input.trim()}
          type="submit" 
          className="w-10 h-10 bg-orange-600 text-white rounded-xl flex items-center justify-center disabled:opacity-50 hover:bg-orange-500 transition-colors"
        >
          <Send size={16} />
        </button>
      </form>
    </div>
  );
};

export default SatoshiAIChat;
