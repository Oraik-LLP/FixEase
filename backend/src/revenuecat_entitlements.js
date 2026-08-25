export function createRevenueCatEntitlementVerifier({
  apiKey,
  entitlementIds,
  limitedEntitlementDurationsMs = {},
  cacheMs = 300000,
  fetchImpl = globalThis.fetch,
  now = () => Date.now(),
}) {
  const cache = new Map();

  return async function hasVerifiedEntitlement(appUserId) {
    if (!apiKey || !appUserId) return false;

    const cached = cache.get(appUserId);
    if (cached && cached.expiresAt > now()) return cached.active;

    try {
      const response = await fetchImpl(
        `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`,
        {
          headers: {
            Accept: 'application/json',
            Authorization: `Bearer ${apiKey}`,
          },
          signal: AbortSignal.timeout(5000),
        },
      );
      if (!response.ok) return false;

      const payload = await response.json();
      const entitlements = payload?.subscriber?.entitlements || {};
      const active = entitlementIds.some((id) =>
        isRevenueCatEntitlementActive(
          entitlements[id],
          now(),
          limitedEntitlementDurationsMs[id],
        ),
      );
      cache.set(appUserId, { active, expiresAt: now() + cacheMs });
      return active;
    } catch (_) {
      return false;
    }
  };
}

export function isRevenueCatEntitlementActive(
  entitlement,
  nowMs = Date.now(),
  fallbackDurationMs,
) {
  if (!entitlement) return false;
  const expiries = [
    entitlement.expires_date,
    entitlement.grace_period_expires_date,
  ].filter(Boolean);
  if (expiries.length === 0) {
    if (!Number.isFinite(fallbackDurationMs)) return true;
    const purchaseDate =
      entitlement.purchase_date || entitlement.latest_purchase_date;
    const purchaseMs = Date.parse(purchaseDate);
    return (
      Number.isFinite(purchaseMs) && purchaseMs + fallbackDurationMs > nowMs
    );
  }
  return expiries.some((expiry) => {
    const expiryMs = Date.parse(expiry);
    return Number.isFinite(expiryMs) && expiryMs > nowMs;
  });
}
