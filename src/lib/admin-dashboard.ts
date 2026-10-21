import type { SupabaseClient } from '@supabase/supabase-js';

export type AdminDashboardMetrics = {
  campaignName: string | null;
  targets: number;
  completed: number;
  pendingReview: number;
  needsRevision: number;
  qualityAlerts: number;
  lastSyncAt: string | null;
};

type CountResult = { count: number | null; error: { message: string } | null };

async function countOrThrow(query: PromiseLike<CountResult>) {
  const { count, error } = await query;
  if (error) throw new Error(error.message);
  return count ?? 0;
}

export async function loadAdminDashboardMetrics(client: SupabaseClient): Promise<AdminDashboardMetrics> {
  const { data: campaign, error: campaignError } = await client
    .from('survey_campaigns')
    .select('id, name')
    .eq('status', 'active')
    .gte('ends_on', new Date().toISOString().slice(0, 10))
    .order('starts_on', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (campaignError) throw new Error(campaignError.message);

  const [targets, completed, pendingReview, needsRevision, qualityAlerts, syncResult] = await Promise.all([
    campaign
      ? countOrThrow(client.from('survey_assignments').select('id', { count: 'exact', head: true }).eq('campaign_id', campaign.id))
      : Promise.resolve(0),
    campaign
      ? countOrThrow(client.from('survey_assignments').select('id', { count: 'exact', head: true }).eq('campaign_id', campaign.id).in('status', ['submitted', 'approved']))
      : Promise.resolve(0),
    countOrThrow(client.from('survey_submissions').select('id', { count: 'exact', head: true }).in('status', ['submitted', 'in_review'])),
    countOrThrow(client.from('survey_submissions').select('id', { count: 'exact', head: true }).eq('status', 'revision_requested')),
    countOrThrow(client.from('survey_quality_flags').select('id', { count: 'exact', head: true }).is('resolved_at', null)),
    client.from('survey_sync_receipts').select('server_received_at').order('server_received_at', { ascending: false }).limit(1).maybeSingle(),
  ]);

  if (syncResult.error) throw new Error(syncResult.error.message);

  return {
    campaignName: campaign?.name ?? null,
    targets,
    completed,
    pendingReview,
    needsRevision,
    qualityAlerts,
    lastSyncAt: syncResult.data?.server_received_at ?? null,
  };
}
