import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createRevenueCatEntitlementVerifier,
  isRevenueCatEntitlementActive,
} from '../src/revenuecat_entitlements.js';

test('accepts lifetime and future RevenueCat entitlements', () => {
  const now = Date.parse('2026-08-24T00:00:00Z');
  assert.equal(isRevenueCatEntitlementActive({ expires_date: null }, now), true);
  assert.equal(
    isRevenueCatEntitlementActive({ expires_date: '2026-08-25T00:00:00Z' }, now),
    true,
  );
});

test('rejects missing and expired RevenueCat entitlements', () => {
  const now = Date.parse('2026-08-24T00:00:00Z');
  assert.equal(isRevenueCatEntitlementActive(null, now), false);
  assert.equal(
    isRevenueCatEntitlementActive({ expires_date: '2026-08-23T00:00:00Z' }, now),
    false,
  );
});

test('uses a valid grace period after the normal expiry', () => {
  const now = Date.parse('2026-08-24T00:00:00Z');
  assert.equal(
    isRevenueCatEntitlementActive(
      {
        expires_date: '2026-08-23T00:00:00Z',
        grace_period_expires_date: '2026-08-25T00:00:00Z',
      },
      now,
    ),
    true,
  );
});

test('verifies and caches the configured premium entitlement', async () => {
  let calls = 0;
  const verify = createRevenueCatEntitlementVerifier({
    apiKey: 'server-secret',
    entitlementIds: ['ENTITLEMENT_PRO'],
    now: () => Date.parse('2026-08-24T00:00:00Z'),
    fetchImpl: async (url, options) => {
      calls += 1;
      assert.match(url, /subscribers\/device-1$/);
      assert.equal(options.headers.Authorization, 'Bearer server-secret');
      return {
        ok: true,
        json: async () => ({
          subscriber: {
            entitlements: { ENTITLEMENT_PRO: { expires_date: null } },
          },
        }),
      };
    },
  });

  assert.equal(await verify('device-1'), true);
  assert.equal(await verify('device-1'), true);
  assert.equal(calls, 1);
});

test('fails closed when RevenueCat is unavailable or unconfigured', async () => {
  const unavailable = createRevenueCatEntitlementVerifier({
    apiKey: 'server-secret',
    entitlementIds: ['ENTITLEMENT_PRO'],
    fetchImpl: async () => {
      throw new Error('network down');
    },
  });
  const unconfigured = createRevenueCatEntitlementVerifier({
    apiKey: '',
    entitlementIds: ['ENTITLEMENT_PRO'],
    fetchImpl: async () => assert.fail('fetch should not run'),
  });

  assert.equal(await unavailable('device-1'), false);
  assert.equal(await unconfigured('device-1'), false);
});
