import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

function toHex(buffer: ArrayBuffer): string {
  return Array.from(new Uint8Array(buffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function timingSafeEqualHex(a: string, b: string): boolean {
  const normA = a.trim().toLowerCase();
  const normB = b.trim().toLowerCase();
  if (normA.length === 0 || normA.length !== normB.length) return false;
  let diff = 0;
  for (let i = 0; i < normA.length; i++) {
    diff |= normA.charCodeAt(i) ^ normB.charCodeAt(i);
  }
  return diff === 0;
}

async function verifyChargilySignature(
  rawBody: string,
  signatureHeader: string,
  secretKey: string,
): Promise<boolean> {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secretKey),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const mac = await crypto.subtle.sign('HMAC', key, encoder.encode(rawBody));
  const computedHex = toHex(mac);
  return timingSafeEqualHex(computedHex, signatureHeader);
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
    const chargilySecretKey = Deno.env.get('CHARGILY_SECRET_KEY') ?? '';

    if (!supabaseUrl || !supabaseServiceKey || !chargilySecretKey) {
      return new Response(JSON.stringify({ error: 'Server secrets not configured' }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const signature = req.headers.get('signature') ?? '';
    const rawBody = await req.text();

    if (!signature || !(await verifyChargilySignature(rawBody, signature, chargilySecretKey))) {
      return new Response(JSON.stringify({ error: 'Invalid webhook signature' }), {
        status: 401,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const payload = JSON.parse(rawBody);
    const eventType = String(payload?.type ?? '');

    if (eventType !== 'checkout.paid') {
      return new Response(
        JSON.stringify({ received: true, ignored: eventType }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      );
    }

    const checkout = payload?.data ?? {};
    const checkoutId = String(checkout?.id ?? '').trim();
    if (!checkoutId) {
      return new Response(JSON.stringify({ error: 'Missing checkout id' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const adminClient = createClient(supabaseUrl, supabaseServiceKey);

    // Look up existing payment row created during checkout initiation
    const { data: existingPayment } = await adminClient
      .from('payments')
      .select('*')
      .or(`chargily_checkout_id.eq.${checkoutId},receipt_reference.eq.${checkoutId}`)
      .maybeSingle();

    if (existingPayment?.status === 'approved') {
      return new Response(
        JSON.stringify({ received: true, idempotent: true, checkout_id: checkoutId }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      );
    }

    const meta = checkout?.metadata ?? {};
    const userId = String(existingPayment?.user_id ?? meta?.user_id ?? '').trim();
    const tier = String(existingPayment?.tier ?? meta?.tier ?? 'resident_elite').trim();
    const durationDays = Number(existingPayment?.duration_days ?? meta?.duration_days ?? 365);
    const amount = Number(existingPayment?.amount ?? checkout?.amount ?? 0);
    const source = String(existingPayment?.acquisition_source ?? meta?.acquisition_source ?? 'in_app');

    if (!userId) {
      return new Response(JSON.stringify({ error: 'Missing user_id on checkout' }), {
        status: 400,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    const nowIso = new Date().toISOString();

    if (existingPayment) {
      await adminClient
        .from('payments')
        .update({
          status: 'approved',
          chargily_checkout_id: checkoutId,
          admin_notes: `Auto-validé par Chargily Pay webhook (${nowIso})`,
          updated_at: nowIso,
        })
        .eq('id', existingPayment.id);
    } else {
      // Insert pending then update to approved so AFTER UPDATE referral reward triggers fire cleanly
      const { data: insertedRow } = await adminClient
        .from('payments')
        .insert({
          user_id: userId,
          user_email: String(meta?.user_email ?? 'resident@medsina.com'),
          user_name: String(meta?.user_name ?? 'Médecin Résident'),
          tier,
          duration_days: durationDays,
          amount,
          currency: 'DZD',
          payment_method: 'chargily_cib',
          chargily_checkout_id: checkoutId,
          receipt_reference: checkoutId,
          acquisition_source: source,
          status: 'pending',
          admin_notes: 'Créé depuis webhook Chargily Pay',
        })
        .select('id')
        .single();

      if (insertedRow?.id) {
        await adminClient
          .from('payments')
          .update({
            status: 'approved',
            admin_notes: `Auto-validé par Chargily Pay webhook (${nowIso})`,
            updated_at: nowIso,
          })
          .eq('id', insertedRow.id);
      }
    }

    // Activate or extend the user's subscription immediately
    const { data: currentSub } = await adminClient
      .from('subscriptions')
      .select('expires_at')
      .eq('user_id', userId)
      .maybeSingle();

    const nowMs = Date.now();
    const existingExpiryMs = currentSub?.expires_at ? Date.parse(currentSub.expires_at) : 0;
    const baseMs = Number.isFinite(existingExpiryMs) && existingExpiryMs > nowMs ? existingExpiryMs : nowMs;
    const newExpiryIso = new Date(baseMs + durationDays * 24 * 60 * 60 * 1000).toISOString();

    await adminClient
      .from('subscriptions')
      .upsert(
        {
          user_id: userId,
          tier,
          status: 'active',
          starts_at: nowIso,
          expires_at: newExpiryIso,
          updated_at: nowIso,
        },
        { onConflict: 'user_id' },
      );

    await adminClient.from('funnel_events').insert({
      event_id: crypto.randomUUID(),
      user_id: userId,
      event_name: 'payment_succeeded',
      properties: {
        plan: tier,
        method: 'chargily_cib',
        amount,
        currency: 'DZD',
        duration_days: durationDays,
        code: source,
        checkout_id: checkoutId,
      },
      device_timestamp: nowIso,
    });

    return new Response(
      JSON.stringify({ received: true, activated: true, checkout_id: checkoutId }),
      { status: 200, headers: { 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('chargily-webhook error:', err);
    return new Response(JSON.stringify({ error: 'Internal webhook error' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    });
  }
});
