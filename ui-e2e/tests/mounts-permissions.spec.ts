import { test, expect } from '@playwright/test';
import { waitForRail, openStack, openTab } from './helpers';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await waitForRail(page);
});

test('mounts tab types each mount and reports host-bind existence', async ({ page }) => {
  await openStack(page, 'web');
  await openTab(page, 'Mounts');

  const existing = page.locator('#tabbody table tr', { hasText: '/usr/share/nginx/html' });
  await expect(existing).toContainText('host-bind');
  await expect(existing.locator('.stchip.ok', { hasText: 'exists' })).toBeVisible();

  const missing = page.locator('#tabbody table tr', { hasText: '/data' });
  await expect(missing.locator('.stchip.bad', { hasText: 'missing' })).toBeVisible();
});

test('mounts tab classifies a named volume', async ({ page }) => {
  await openStack(page, 'cache');
  await openTab(page, 'Mounts');
  const row = page.locator('#tabbody table tr', { hasText: 'cache-data' });
  await expect(row).toContainText('named-volume');
});

test('permissions tab flags the risky stack as non-compliant', async ({ page }) => {
  await openStack(page, 'risky');
  await openTab(page, 'Permissions');
  await expect(page.locator('#tabbody .badge', { hasText: 'NOT COMPLIANT' })).toBeVisible();
  await expect(page.locator('#tabbody .issue').first()).toBeVisible();
  await expect(page.locator('#tabbody')).toContainText(/privileged|socket/i);
});

test('permissions tab passes a clean stack', async ({ page }) => {
  await openStack(page, 'cache');
  await openTab(page, 'Permissions');
  await expect(page.locator('#tabbody .badge', { hasText: 'COMPLIANT' })).toBeVisible();
});
