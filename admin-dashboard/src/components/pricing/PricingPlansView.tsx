import React, { useState } from 'react';
import { 
  Tag, 
  Check, 
  Edit3, 
  Save, 
  CreditCard, 
  Sparkles, 
  Building2, 
  ShieldCheck,
  Percent
} from 'lucide-react';
import { PricingPlan } from '../../types/medsina';

interface PricingPlansViewProps {
  plans: PricingPlan[];
  onUpdatePlan: (updatedPlan: PricingPlan) => void;
}

export const PricingPlansView: React.FC<PricingPlansViewProps> = ({
  plans,
  onUpdatePlan
}) => {
  const [editingPlanId, setEditingPlanId] = useState<string | null>(null);
  const [editPrice, setEditPrice] = useState<number>(0);
  const [editOriginalPrice, setEditOriginalPrice] = useState<number>(0);
  const [editDurationDays, setEditDurationDays] = useState<number>(365);
  const [saveToast, setSaveToast] = useState(false);

  const startEdit = (plan: PricingPlan) => {
    setEditingPlanId(plan.id);
    setEditPrice(plan.priceDZD);
    setEditOriginalPrice(plan.originalPriceDZD || plan.priceDZD);
    setEditDurationDays(plan.durationDays);
  };

  const handleSaveEdit = (plan: PricingPlan) => {
    const updated: PricingPlan = {
      ...plan,
      priceDZD: editPrice,
      originalPriceDZD: editOriginalPrice,
      durationDays: editDurationDays,
      durationLabel: `${editDurationDays} Jours d'accès illimité`
    };
    onUpdatePlan(updated);
    setEditingPlanId(null);
    setSaveToast(true);
    setTimeout(() => setSaveToast(false), 2500);
  };

  return (
    <div className="space-y-6">
      {/* View Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-2 border-b border-slate-200 dark:border-slate-800">
        <div>
          <h1 className="text-xl md:text-2xl font-bold tracking-tight text-slate-900 dark:text-white">
            Tarifs & Formules d'Abonnement 🏷️
          </h1>
          <p className="text-xs md:text-sm text-slate-500 dark:text-slate-400 mt-0.5">
            Gestion des forfaits d'adhésion en Dinars Algériens (DZD), durées et coordonnées bancaires officielles.
          </p>
        </div>

        {saveToast && (
          <span className="text-xs font-semibold text-emerald-600 dark:text-emerald-400 flex items-center gap-1.5 animate-in fade-in">
            <Check className="w-4 h-4" />
            Tarifs sauvegardés avec succès
          </span>
        )}
      </div>

      {/* Official Payment Channel Notice (BaridiMob & CCP) */}
      <div className="p-4 bg-teal-50/60 dark:bg-teal-950/40 rounded-xl border border-teal-200 dark:border-teal-900/60 flex flex-col md:flex-row md:items-center justify-between gap-3 text-xs">
        <div className="flex items-center gap-3">
          <div className="p-2 bg-teal-100 dark:bg-teal-900/80 text-teal-800 dark:text-teal-200 rounded-lg shrink-0">
            <CreditCard className="w-4 h-4" />
          </div>
          <div>
            <p className="font-bold text-teal-950 dark:text-teal-200">
              Coordonnées Officielles de Paiement Medsina (Algérie Poste)
            </p>
            <p className="text-teal-800 dark:text-teal-300 font-mono mt-0.5">
              Compte CCP : <strong>0021489012 Clé 45</strong> · RIP BaridiMob : <strong>00799999002148901245</strong> · Tél : +213 550 26 26 26
            </p>
          </div>
        </div>
        <span className="font-mono text-[11px] text-teal-700 dark:text-teal-300 bg-white dark:bg-slate-900 px-3 py-1.5 rounded-lg border border-teal-200 dark:border-teal-800 font-semibold shrink-0">
          Devise : DZD (Dinar Algérien)
        </span>
      </div>

      {/* 4 Pricing Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        {plans.map((plan) => {
          const isEditing = editingPlanId === plan.id;
          const discountPct = plan.originalPriceDZD && plan.originalPriceDZD > plan.priceDZD
            ? Math.round(((plan.originalPriceDZD - plan.priceDZD) / plan.originalPriceDZD) * 100)
            : 0;

          return (
            <div
              key={plan.id}
              className={`p-5 rounded-2xl border transition-all flex flex-col justify-between bg-white dark:bg-slate-900 ${
                plan.isPopular
                  ? 'border-purple-500 ring-2 ring-purple-500/20 shadow-md'
                  : 'border-slate-200 dark:border-slate-800 shadow-2xs'
              }`}
            >
              <div>
                {/* Header */}
                <div className="flex items-center justify-between gap-2">
                  <h3 className="font-bold text-sm text-slate-900 dark:text-white">
                    {plan.title}
                  </h3>
                  {plan.isPopular && (
                    <span className="px-2 py-0.5 rounded text-[10px] font-bold uppercase bg-purple-100 text-purple-800 dark:bg-purple-950 dark:text-purple-300">
                      Top Concours
                    </span>
                  )}
                </div>

                <p className="text-[11px] text-slate-500 dark:text-slate-400 mt-1">
                  {plan.subtitle}
                </p>

                {/* Price Display / Form */}
                <div className="mt-4 p-3 bg-slate-50 dark:bg-slate-800/50 rounded-xl border border-slate-200 dark:border-slate-800">
                  {isEditing ? (
                    <div className="space-y-2 text-xs">
                      <div>
                        <span className="text-[10px] text-slate-400 font-semibold block">Prix Actuel (DZD)</span>
                        <input
                          type="number"
                          step="1000"
                          value={editPrice}
                          onChange={(e) => setEditPrice(Number(e.target.value))}
                          className="w-full px-2 py-1 bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded font-mono font-bold"
                        />
                      </div>
                      <div>
                        <span className="text-[10px] text-slate-400 font-semibold block">Prix Barré (DZD)</span>
                        <input
                          type="number"
                          step="1000"
                          value={editOriginalPrice}
                          onChange={(e) => setEditOriginalPrice(Number(e.target.value))}
                          className="w-full px-2 py-1 bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded font-mono text-slate-500"
                        />
                      </div>
                      <div>
                        <span className="text-[10px] text-slate-400 font-semibold block">Durée (Jours)</span>
                        <input
                          type="number"
                          value={editDurationDays}
                          onChange={(e) => setEditDurationDays(Number(e.target.value))}
                          className="w-full px-2 py-1 bg-white dark:bg-slate-900 border border-slate-300 dark:border-slate-700 rounded font-mono"
                        />
                      </div>
                      <div className="flex justify-end gap-1.5 pt-1">
                        <button
                          onClick={() => setEditingPlanId(null)}
                          className="px-2 py-0.5 text-slate-400 hover:text-slate-600 cursor-pointer"
                        >
                          Annuler
                        </button>
                        <button
                          onClick={() => handleSaveEdit(plan)}
                          className="px-3 py-1 bg-teal-600 text-white rounded font-semibold cursor-pointer"
                        >
                          Sauvegarder
                        </button>
                      </div>
                    </div>
                  ) : (
                    <div>
                      <div className="flex items-baseline gap-2">
                        <span className="text-2xl font-bold font-mono text-slate-900 dark:text-white tabular-nums">
                          {plan.priceDZD.toLocaleString()}
                        </span>
                        <span className="text-xs font-semibold text-slate-500">DZD</span>
                        {plan.originalPriceDZD && plan.originalPriceDZD > plan.priceDZD && (
                          <span className="text-xs line-through text-slate-400 font-mono">
                            {plan.originalPriceDZD.toLocaleString()} DZD
                          </span>
                        )}
                      </div>
                      <div className="flex items-center justify-between mt-1 text-[11px] text-slate-500">
                        <span>{plan.durationLabel}</span>
                        {discountPct > 0 && (
                          <span className="font-mono text-emerald-600 font-bold">-{discountPct}%</span>
                        )}
                      </div>
                    </div>
                  )}
                </div>

                {/* Features List */}
                <div className="mt-4 space-y-2 text-xs">
                  <span className="font-semibold text-slate-700 dark:text-slate-300 block text-[11px] uppercase tracking-wider">
                    Fonctionnalités Incluses :
                  </span>
                  <ul className="space-y-1.5 text-slate-600 dark:text-slate-400 text-[11px]">
                    {plan.features.map((feat, idx) => (
                      <li key={idx} className="flex items-start gap-2">
                        <Check className="w-3.5 h-3.5 text-teal-600 dark:text-teal-400 shrink-0 mt-0.5" />
                        <span>{feat}</span>
                      </li>
                    ))}
                  </ul>
                </div>
              </div>

              {/* Edit Plan Button */}
              {!isEditing && (
                <div className="mt-5 pt-3 border-t border-slate-100 dark:border-slate-800">
                  <button
                    onClick={() => startEdit(plan)}
                    className="w-full flex items-center justify-center gap-1.5 py-2 px-3 text-xs font-semibold text-slate-700 dark:text-slate-300 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 rounded-lg transition-colors cursor-pointer"
                  >
                    <Edit3 className="w-3.5 h-3.5" />
                    <span>Modifier Tarification</span>
                  </button>
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
};
