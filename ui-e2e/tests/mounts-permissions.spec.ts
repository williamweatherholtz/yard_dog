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
  await expect(existing.locator('.type.host-bind')).toBeVisible();
  await expect(existing.locator('.chip.ok', { hasText: 'exists' })).toBeVisible();

  // the missing bind is LABELED with the specific problem, not just "missing".
  const missing = page.locator('#tabbody table tr', { hasText: '/data' });
  await expect(missing.locator('.chip.bad', { hasText: 'Missing directory' })).toBeVisible();
  await expect(missing.locator('.auto')).toBeVisible(); // marked auto-fixable
});

test('directory mitigation: a labeled issue + a one-click Apply fixes action', async ({ page }) => {
  await openStack(page, 'web');
  await openTab(page, 'Mounts');
  // the summary surfaces the path-issue count and the apply-all mitigation.
  await expect(page.locator('#tabbody')).toContainText(/path issue/);
  await expect(page.getByRole('button', { name: /Apply fixes/ })).toBeVisible();
});

test('a missing host-bind opens an inline details/fix panel (no popup)', async ({ page }) => {
  await openStack(page, 'web');
  await openTab(page, 'Mounts');
  await page.locator('#tabbody table tr', { hasText: '/data' }).getByRole('button', { name: 'Details…' }).click();
  await expect(page.locator('tr.fixr')).toContainText('Missing directory');
  await expect(page.locator('tr.fixr')).toContainText('Suggested fix');
  await page.getByRole('button', { name: 'Close' }).click();
  await expect(page.locator('tr.fixr')).toHaveCount(0);
});

test('mounts tab classifies a named volume', async ({ page }) => {
  await openStack(page, 'cache');
  await openTab(page, 'Mounts');
  const row = page.locator('#tabbody table tr', { hasText: 'cache-data' });
  await expect(row.locator('.type.named-volume')).toBeVisible();
});

test('permissions tab flags the risky stack as non-compliant', async ({ page }) => {
  await openStack(page, 'risky');
  await openTab(page, 'Permissions');
  await expect(page.locator('#tabbody .pill', { hasText: 'Not compliant' })).toBeVisible();
  await expect(page.locator('#tabbody .issue').first()).toBeVisible();
  await expect(page.locator('#tabbody')).toContainText(/privileged|socket/i);
});

test('permissions tab passes a clean stack', async ({ page }) => {
  await openStack(page, 'cache');
  await openTab(page, 'Permissions');
  await expect(page.locator('#tabbody .pill', { hasText: 'Compliant' })).toBeVisible();
});
