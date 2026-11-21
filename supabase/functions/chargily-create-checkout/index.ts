import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const VALID_PAID_TIERS = new Set([
  'etudiant',
  'clinical_pro',
  'resident_elite',
  'all_access',
]);

const VALID_DURATIONS = new Set([30, 90, 180, 365, 730]);

const OFFICIAL_GUIDE_PRICING: Record<string, { price_yearly: number; price_monthly: number }> = {
  etudiant: { price_yearly: 3500, price_monthly: 500 },
  clinical_pro: { price_yearly: 5000, price_monthly: 800 },
  resident_elite: { price_yearly: 5600, price_monthly: 900 },
  all_access: { price_yearly: 6500, price_monthly: 1000 },
};

function calculateDurationPrice(
  priceYearly: number,
  priceMonthly: number,
  durationDays: number,
): number {
  switch (durationDays) {
    case 30:
      return priceMonthly > 0 ? priceMonthly : Math.round(priceYearly / 12);
    case 90: {
      const base = priceMonthly > 0 ? priceMonthly * 3 : priceYearly * 0.35;
      return Math.round((base * 0.84) / 50) * 50;
    }
    case 180: {
      if (priceYearly === 1900) return 1400;
      const base = priceYearly > 0 ? priceYearly * 0.70 : priceMonthly * 6 * 0.75;
      return Math.round(base / 100) * 100;
    }
    case 365:
      return priceYearly;
    case 730: {
      const baseTwoYears = priceYearly * 2;
      return Math.round((baseTwoYears * 0.795) / 50) * 50;
    }
    default:
      return priceYearly;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(
      JSON.stringify({ success: false, message: 'Method not allowed' }),
      { status: 405, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const chargilySecretKey = Deno.env.get('CHARGILY_SECRET_KEY') ?? '';
    const chargilyMode = (Deno.env.get('CHARGILY_MODE') ?? 'live').toLowerCase();
    const appUrl = Deno.env.get('CHARGILY_APP_URL') ?? 'https://medsina.medevsync.com';

    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceKey) {
      return new Response(
        JSON.stringify({ success: false, message: 'Server configuration error' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    if (!chargilySecretKey) {
      return new Response(
        JSON.stringify({
          success: false,
          message: 'Passerelle Chargily Pay non configurée (CHARGILY_SECRET_KEY manquant).',
        }),
        { status: 503, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(
        JSON.stringify({ success: false, message: 'Authentification requise.' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: authData, error: authError } = await userClient.auth.getUser();
    if (authError || !authData?.user) {
      return new Response(
        JSON.stringify({ success: false, message: 'Session invalide ou expirée.' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const user = authData.user;
    const body = await req.json();
    const tier = String(body?.tier ?? '').trim().toLowerCase();
    const durationDays = Number(body?.duration_days ?? 365);
    const acquisitionSource = String(body?.acquisition_source ?? 'in_app').trim().slice(0, 80);

    if (!VALID_PAID_TIERS.has(tier)) {
      return new Response(
        JSON.stringify({ success: false, message: 'Formule invalide.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    if (!VALID_DURATIONS.has(durationDays)) {
      return new Response(
        JSON.stringify({ success: false, message: 'Durée d\'abonnement invalide.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // Resolve authoritative plan price server-side so clients cannot tamper with amounts
    const { data: planRow } = await adminClient
      .from('subscription_plans')
      .select('price_yearly, price_monthly')
      .eq('id', tier)
      .maybeSingle();

    const fallbackPlan = OFFICIAL_GUIDE_PRICING[tier];
    const priceYearly = Number(planRow?.price_yearly ?? fallbackPlan.price_yearly);
    const priceMonthly = Number(planRow?.price_monthly ?? fallbackPlan.price_monthly);
    const amountDzd = Math.round(calculateDurationPrice(priceYearly, priceMonthly, durationDays));

    if (!Number.isFinite(amountDzd) || amountDzd < 100) {
      return new Response(
        JSON.stringify({ success: false, message: 'Montant calculé invalide.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const { data: profileRow } = await adminClient
      .from('profiles')
      .select('full_name, email')
      .eq('id', user.id)
      .maybeSingle();

    const userEmail = String(profileRow?.email ?? user.email ?? 'resident@medsina.com');
    const userName = String(
      profileRow?.full_name ?? user.user_metadata?.full_name ?? 'Médecin Résident',
    );

    const chargilyEndpoint = chargilyMode === 'live'
      ? 'https://pay.chargily.net/api/v2/checkouts'
      : 'https://pay.chargily.net/test/api/v2/checkouts';

    const chargilyRes = await fetch(chargilyEndpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${chargilySecretKey}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        amount: amountDzd,
        currency: 'dzd',
        success_url: `${appUrl}?payment=success&tier=${encodeURIComponent(tier)}`,
        failure_url: `${appUrl}?payment=failure`,
        metadata: {
          user_id: user.id,
          user_email: userEmail,
          user_name: userName,
          tier,
          duration_days: durationDays,
          acquisition_source: acquisitionSource,
          app: 'Medsina Résidanat 2027',
        },
      }),
    });

    const chargilyData = await chargilyRes.json();
    if (!chargilyRes.ok || !chargilyData?.checkout_url || !chargilyData?.id) {
      console.error('Chargily API error:', chargilyRes.status, chargilyData);
      return new Response(
        JSON.stringify({
          success: false,
          message: 'Erreur passerelle Chargily Pay. Veuillez réessayer ou contacter le support.',
        }),
        { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const checkoutId = String(chargilyData.id);
    const checkoutUrl = String(chargilyData.checkout_url);

    await adminClient.from('payments').insert({
      user_id: user.id,
      user_email: userEmail,
      user_name: userName,
      tier,
      duration_days: durationDays,
      amount: amountDzd,
      currency: 'DZD',
      payment_method: 'chargily_cib',
      chargily_checkout_id: checkoutId,
      receipt_reference: checkoutId,
      acquisition_source: acquisitionSource,
      status: 'pending',
      admin_notes: `Session Chargily Pay (${chargilyMode}) initiée (ID: ${checkoutId})`,
    });

    await adminClient.from('funnel_events').insert({
      event_id: crypto.randomUUID(),
      user_id: user.id,
      event_name: 'checkout_started',
      properties: {
        plan: tier,
        method: 'chargily_cib',
        amount: amountDzd,
        duration_days: durationDays,
        source: acquisitionSource,
      },
      device_timestamp: new Date().toISOString(),
    });

    return new Response(
      JSON.stringify({
        success: true,
        checkout_url: checkoutUrl,
        checkout_id: checkoutId,
        amount: amountDzd,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('chargily-create-checkout error:', err);
    return new Response(
      JSON.stringify({ success: false, message: 'Erreur interne lors du paiement.' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
