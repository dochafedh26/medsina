import React, { useState } from 'react';
import { 
  ShieldCheck, 
  Lock, 
  Mail, 
  ArrowRight, 
  AlertCircle, 
  Activity, 
  CheckCircle2, 
  Eye, 
  EyeOff, 
  Server,
  Sparkles
} from 'lucide-react';
import { loginAdminWithEmail, sendAdminMagicLink, AdminAuthProfile } from '../../services/supabase';
import logoDark from '../../assets/images/medsina-logo-dark.png';

interface LoginViewProps {
  onLoginSuccess: (admin: AdminAuthProfile) => void;
}

export const LoginView: React.FC<LoginViewProps> = ({ onLoginSuccess }) => {
  const [email, setEmail] = useState('doc.hafedh26@gmail.com');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [isMagicLoading, setIsMagicLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email.trim() || !password) {
      setErrorMessage('Veuillez renseigner votre email et mot de passe administrateur.');
      return;
    }

    setIsLoading(true);
    setErrorMessage(null);
    setSuccessMessage(null);

    const result = await loginAdminWithEmail(email, password);
    setIsLoading(false);

    if (result.success && result.user) {
      onLoginSuccess(result.user);
    } else {
      setErrorMessage(result.message || 'Identifiants invalides ou privilèges insuffisants.');
    }
  };

  const handleSendMagicLink = async () => {
    if (!email.trim()) {
      setErrorMessage('Veuillez spécifier votre adresse email administrateur.');
      return;
    }

    setIsMagicLoading(true);
    setErrorMessage(null);
    setSuccessMessage(null);

    const res = await sendAdminMagicLink(email);
    setIsMagicLoading(false);

    if (res.success) {
      setSuccessMessage(res.message);
    } else {
      setErrorMessage(res.message);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-950 to-teal-950 flex flex-col justify-center items-center px-4 py-12 relative overflow-hidden text-white font-sans">
      {/* Background Glows */}
      <div className="absolute top-1/4 left-1/2 -translate-x-1/2 w-96 h-96 bg-teal-500/10 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute -bottom-10 right-10 w-80 h-80 bg-emerald-500/10 rounded-full blur-3xl pointer-events-none" />

      {/* Main Card */}
      <div className="w-full max-w-md relative z-10 bg-slate-900/80 backdrop-blur-xl border border-slate-800 rounded-3xl p-8 shadow-2xl">
        {/* Header / Real Medsina Brand */}
        <div className="text-center mb-8">
          <div className="flex justify-center items-center mb-4">
            <img 
              src={logoDark} 
              alt="Medsina" 
              className="h-12 sm:h-14 w-auto object-contain drop-shadow-md"
            />
          </div>

          <div className="flex items-center justify-center gap-1.5 mb-1.5">
            <span className="text-xs uppercase font-extrabold px-2.5 py-0.5 rounded-md bg-teal-500/20 text-teal-300 border border-teal-500/30 font-mono tracking-wider">
              Console Administrateur
            </span>
          </div>

          <p className="text-xs text-slate-400 mt-2">
            Plateforme médicale officielle hébergée sur <span className="text-teal-400 font-semibold">Octenium</span>
          </p>
        </div>

        {/* Security Alert Badge */}
        <div className="mb-6 p-3 rounded-xl bg-slate-800/60 border border-slate-700/60 flex items-center gap-2.5 text-xs text-slate-300">
          <Server className="w-4 h-4 text-teal-400 shrink-0" />
          <span>Accès exclusif réservé à l'équipe de direction médicale Medsina.</span>
        </div>

        {/* Success Banner */}
        {successMessage && (
          <div className="mb-6 p-3.5 rounded-xl bg-emerald-950/60 border border-emerald-800/80 text-emerald-200 text-xs flex items-start gap-2.5 animate-in fade-in-50 duration-200">
            <CheckCircle2 className="w-4 h-4 text-emerald-400 shrink-0 mt-0.5" />
            <div className="flex-1">{successMessage}</div>
          </div>
        )}

        {/* Error Banner */}
        {errorMessage && (
          <div className="mb-6 p-3.5 rounded-xl bg-red-950/60 border border-red-800/80 text-red-200 text-xs flex items-start gap-2.5 animate-in fade-in-50 duration-200">
            <AlertCircle className="w-4 h-4 text-red-400 shrink-0 mt-0.5" />
            <div className="flex-1">{errorMessage}</div>
          </div>
        )}

        {/* Login Form */}
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1.5">
              Email Administrateur
            </label>
            <div className="relative">
              <Mail className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
              <input
                type="email"
                required
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="admin@medsina.dz"
                className="w-full bg-slate-950/60 border border-slate-700 rounded-xl pl-10 pr-4 py-2.5 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-teal-500 focus:ring-1 focus:ring-teal-500 transition-all"
              />
            </div>
          </div>

          <div>
            <label className="block text-xs font-semibold text-slate-300 uppercase tracking-wider mb-1.5">
              Mot de Passe Sécurisé
            </label>
            <div className="relative">
              <Lock className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
              <input
                type={showPassword ? 'text' : 'password'}
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••••••"
                className="w-full bg-slate-950/60 border border-slate-700 rounded-xl pl-10 pr-10 py-2.5 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-teal-500 focus:ring-1 focus:ring-teal-500 transition-all"
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-200 cursor-pointer p-1"
              >
                {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
              </button>
            </div>
          </div>

          <button
            type="submit"
            disabled={isLoading || isMagicLoading}
            className="w-full mt-2 py-3 px-4 rounded-xl font-bold text-sm bg-gradient-to-r from-teal-500 to-emerald-600 hover:from-teal-600 hover:to-emerald-700 active:scale-[0.99] text-white shadow-lg shadow-teal-500/25 flex items-center justify-center gap-2 cursor-pointer transition-all disabled:opacity-60"
          >
            {isLoading ? (
              <>
                <div className="w-4 h-4 border-2 border-white/30 border-t-white rounded-full animate-spin" />
                <span>Vérification des privilèges...</span>
              </>
            ) : (
              <>
                <ShieldCheck className="w-4 h-4" />
                <span>Connexion à la Console</span>
                <ArrowRight className="w-4 h-4" />
              </>
            )}
          </button>

          <div className="pt-2 text-center">
            <button
              type="button"
              disabled={isLoading || isMagicLoading}
              onClick={handleSendMagicLink}
              className="text-xs text-slate-400 hover:text-teal-300 transition-colors inline-flex items-center gap-1.5 cursor-pointer disabled:opacity-50"
            >
              {isMagicLoading ? (
                <>
                  <div className="w-3 h-3 border-2 border-teal-400/40 border-t-teal-400 rounded-full animate-spin" />
                  <span>Envoi du lien sécurisé...</span>
                </>
              ) : (
                <>
                  <Mail className="w-3.5 h-3.5 text-teal-400" />
                  <span>Connexion sans mot de passe (Lien Magique Email)</span>
                </>
              )}
            </button>
          </div>
        </form>

        {/* Quick fill helper for admin */}
        <div className="mt-6 pt-5 border-t border-slate-800 text-center">
          <p className="text-[11px] text-slate-400 mb-2">Compte officiel préconfiguré :</p>
          <button
            type="button"
            onClick={() => {
              setEmail('doc.hafedh26@gmail.com');
            }}
            className="inline-flex items-center gap-1.5 px-3 py-1 rounded-lg bg-slate-800 hover:bg-slate-700/80 text-xs font-mono text-teal-300 border border-slate-700 cursor-pointer transition-colors"
          >
            <Sparkles className="w-3 h-3 text-teal-400" />
            doc.hafedh26@gmail.com (Dr. Hafedh)
          </button>
        </div>
      </div>

      {/* Footer Info */}
      <div className="relative z-10 mt-8 text-center text-xs text-slate-500 flex items-center gap-4">
        <span>Medsina v1.0.62</span>
        <span>•</span>
        <span>Octenium Cloud VPS</span>
        <span>•</span>
        <span>HTTPS / TLS 1.3</span>
      </div>
    </div>
  );
};
