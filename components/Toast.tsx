
import React, { useEffect, useState } from 'react';
import { X, CheckCircle2, AlertTriangle, Info, ShieldAlert } from 'lucide-react';

export type ToastType = 'success' | 'error' | 'warning' | 'info';

export interface ToastMessage {
  id: string;
  type: ToastType;
  message: string;
  duration?: number;
}

interface ToastProps {
  toasts: ToastMessage[];
  removeToast: (id: string) => void;
}

const ToastContainer: React.FC<ToastProps> = ({ toasts, removeToast }) => {
  return (
    <div className="fixed bottom-6 right-6 z-[200] flex flex-col gap-3 pointer-events-none">
      {toasts.map((toast) => (
        <div 
          key={toast.id}
          className="pointer-events-auto bg-zinc-950/90 backdrop-blur-md border border-zinc-800 p-4 rounded-2xl shadow-2xl flex items-center gap-4 min-w-[300px] animate-in slide-in-from-bottom-5 fade-in duration-300"
        >
          <div className={`p-2 rounded-xl ${
            toast.type === 'success' ? 'bg-green-500/10 text-green-500' :
            toast.type === 'error' ? 'bg-red-500/10 text-red-500' :
            toast.type === 'warning' ? 'bg-orange-500/10 text-orange-500' :
            'bg-blue-500/10 text-blue-500'
          }`}>
            {toast.type === 'success' && <CheckCircle2 size={18} />}
            {toast.type === 'error' && <ShieldAlert size={18} />}
            {toast.type === 'warning' && <AlertTriangle size={18} />}
            {toast.type === 'info' && <Info size={18} />}
          </div>
          <p className="flex-1 text-xs font-bold text-zinc-200">{toast.message}</p>
          <button 
            onClick={() => removeToast(toast.id)}
            className="text-zinc-600 hover:text-zinc-400 transition-colors"
          >
            <X size={14} />
          </button>
        </div>
      ))}
    </div>
  );
};

export default ToastContainer;
