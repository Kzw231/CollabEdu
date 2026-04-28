import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Recommended Supabase setup: run **`supabase/SETUP_RECOMMENDED.sql`**
/// (RPC + members read policy). See comments in that file for options.

Map<String, dynamic>? _asMemberMap(dynamic rpc) {
  if (rpc == null) return null;
  if (rpc is Map<String, dynamic>) return rpc;
  if (rpc is Map) return Map<String, dynamic>.from(rpc);
  return null;
}

/// Looks up [members] by email or member [id] (e.g. M0001).
///
/// Prefer Supabase RPC [invite_lookup_member] (see `supabase/invite_lookup_member_rpc.sql`)
/// so lookup works even when RLS only allows users to read their own `members` row.
/// Falls back to direct table queries if the RPC is not installed.
Future<Map<String, dynamic>?> lookupMemberByIdOrEmail(String raw) async {
  final input = raw.trim();
  if (input.isEmpty) return null;
  final supabase = Supabase.instance.client;

  try {
    final rpc = await supabase.rpc(
      'invite_lookup_member',
      params: {
        'p_email': input.contains('@') ? input : null,
        'p_id': input.contains('@') ? null : input,
      },
    );
    Map<String, dynamic>? fromRpc = _asMemberMap(rpc);
    if (fromRpc == null && rpc is String) {
      final s = (rpc as String).trim();
      if (s.startsWith('{')) {
        try {
          fromRpc = Map<String, dynamic>.from(jsonDecode(s) as Map);
        } catch (_) {}
      }
    }
    if (fromRpc != null && fromRpc['id'] != null) return fromRpc;
  } catch (_) {
    // RPC missing or not granted — use direct select (needs members SELECT RLS).
  }

  if (input.contains('@')) {
    return await supabase
        .from('members')
        .select('id, name, email')
        .eq('email', input)
        .maybeSingle();
  }
  return await supabase.from('members').select('id, name, email').eq('id', input).maybeSingle();
}
