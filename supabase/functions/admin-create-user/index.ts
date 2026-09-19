// Creates a learner account on an admin's behalf and sets how long their
// access lasts.
//
// This has to live server-side: creating a user requires the service_role
// key, which bypasses every row-level security policy. That key must never
// reach the app, so the app calls this function instead, and the function
// checks that the caller really is an admin before doing anything.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function fail(message: string, status = 400) {
  return new Response(JSON.stringify({ error: message }), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!;

    // 1. Who is calling? Use their own token, so RLS applies to this check.
    const authHeader = req.headers.get('Authorization') ?? '';
    if (!authHeader.startsWith('Bearer ')) return fail('Not signed in', 401);

    const asCaller = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userError } = await asCaller.auth.getUser();
    if (userError || !userData?.user) return fail('Not signed in', 401);

    const { data: profile } = await asCaller
      .from('profiles')
      .select('role')
      .eq('id', userData.user.id)
      .maybeSingle();

    if (profile?.role !== 'admin') return fail('Admins only', 403);

    // 2. Create the account with the privileged key.
    const { email, password, fullName, accessUntil } = await req.json();
    if (!email || typeof email !== 'string') return fail('Email is required');
    if (!password || typeof password !== 'string' || password.length < 6) {
      return fail('Password must be at least 6 characters');
    }

    const admin = createClient(supabaseUrl, serviceKey);

    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email: email.trim(),
      password,
      // Created by an admin, so there is nobody to confirm the address.
      email_confirm: true,
      user_metadata: fullName ? { full_name: fullName } : undefined,
    });

    if (createError) return fail(createError.message);
    const newUser = created?.user;
    if (!newUser) return fail('User was not created');

    // 3. Apply the access window. The profile row itself is created by the
    //    trigger on auth.users, which may land a moment later.
    const patch: Record<string, unknown> = {
      access_until: accessUntil ?? null,
      is_blocked: false,
    };
    if (fullName) patch.full_name = fullName;

    let updated = false;
    for (let attempt = 0; attempt < 5 && !updated; attempt++) {
      const { error } = await admin.from('profiles').update(patch).eq('id', newUser.id);
      if (!error) {
        updated = true;
        break;
      }
      await new Promise((r) => setTimeout(r, 300));
    }

    return new Response(
      JSON.stringify({
        id: newUser.id,
        email: newUser.email,
        accessUntil: accessUntil ?? null,
        profileUpdated: updated,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (e) {
    return fail(String(e instanceof Error ? e.message : e), 500);
  }
});
