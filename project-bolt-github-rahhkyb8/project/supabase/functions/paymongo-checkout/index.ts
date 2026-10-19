// PayMongo checkout edge function (TEST MODE).
// If PAYMONGO_SECRET_KEY is configured, creates a real PayMongo Checkout Session.
// Otherwise, simulates a successful test payment and credits coins directly.
// Either way, coins are credited to the demo user via the service role client.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Client-Info, Apikey",
};

const DEMO_USER_ID = "00000000-0000-0000-0000-000000000001";

const PACKS: Record<string, { amount_php: number; coins: number; label: string }> = {
  single: { amount_php: 15, coins: 20, label: "Single Episode" },
  mini: { amount_php: 50, coins: 75, label: "Mini Pack" },
  full: { amount_php: 150, coins: 250, label: "Full Series Unlock" },
};

import { createClient } from "npm:@supabase/supabase-js@2.58.0";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") as string;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") as string;
    const paymongoKey = Deno.env.get("PAYMONGO_SECRET_KEY");

    const body = await req.json().catch(() => ({}));
    const packId = body?.packId as string | undefined;
    const action = (body?.action as string) || "create"; // "create" | "confirm"
    const pack = packId ? PACKS[packId] : undefined;

    if (!pack) {
      return new Response(JSON.stringify({ error: "Invalid pack id" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false },
    });

    // If a real PayMongo key is present, create a real checkout session.
    if (paymongoKey && action === "create") {
      const checkoutRes = await fetch("https://api.paymongo.com/v1/checkout_sessions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Basic ${btoa(paymongoKey)}`,
        },
        body: JSON.stringify({
          data: {
            attributes: {
              description: `DramaMania — ${pack.label}`,
              amount: Math.round(pack.amount_php * 100),
              currency: "PHP",
              send_email_receipt: false,
              payment_method_types: ["gcash", "maya", "card", "qrph", "atome"],
            },
          },
        }),
      });

      if (!checkoutRes.ok) {
        const errText = await checkoutRes.text();
        return new Response(JSON.stringify({ error: `PayMongo error: ${errText}` }), {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const json = await checkoutRes.json();
      const checkoutUrl = json?.data?.attributes?.checkout_url;
      const sessionId = json?.data?.id;

      // Record a pending transaction (coins added on confirm/webhook).
      await supabase.from("transactions").insert({
        user_id: DEMO_USER_ID,
        type: "purchase_pending",
        description: `${pack.label} (P${pack.amount_php})`,
        amount_php: pack.amount_php,
        coins_change: 0,
      });

      return new Response(
        JSON.stringify({ checkoutUrl, sessionId, mode: "paymongo" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // TEST MODE (no PayMongo key): simulate success and credit coins immediately.
    // Small artificial delay so the UI can show a processing state.
    await new Promise((r) => setTimeout(r, 600));

    // Credit coins to the demo user.
    const { data: userRow } = await supabase
      .from("users")
      .select("id, coin_balance")
      .eq("id", DEMO_USER_ID)
      .maybeSingle();

    const newBalance = (userRow?.coin_balance ?? 0) + pack.coins;

    await supabase.from("users").update({ coin_balance: newBalance }).eq("id", DEMO_USER_ID);

    await supabase.from("transactions").insert({
      user_id: DEMO_USER_ID,
      type: "purchase",
      description: `${pack.label} — ${pack.coins} credits (TEST MODE)`,
      amount_php: pack.amount_php,
      coins_change: pack.coins,
    });

    return new Response(
      JSON.stringify({
        success: true,
        mode: "test",
        coinsAdded: pack.coins,
        newBalance,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: err?.message || "Unknown error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
