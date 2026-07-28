import { test, expect } from '@playwright/test';
import { waitForRail, openStack, openTab } from './helpers';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await waitForRail(page);
});

test('fleet view aggregates every stack with bulk actions', async ({ page }) => {
  await page.locator('#fleet').click();
  await expect(page.locator('main h1')).toHaveText('Fleet');
  await expect(page.getByRole('button', { name: 'Check all' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Back up all' })).toBeVisible();

  const tbl = page.locator('main table');
  await expect(tbl.locator('tr', { hasText: 'web' })).toBeVisible();
  await expect(tbl.locator('tr', { hasText: 'cache' })).toBeVisible();
  await expect(tbl.locator('tr', { hasText: 'risky' })).toBeVisible();
  // fixtures start unadopted -> managed column shows "unadopted".
  await expect(tbl.locator('.stchip.attn', { hasText: 'unadopted' }).first()).toBeVisible();
});

test('git panel shows the not-connected state and a connect action', async ({ page }) => {
  await page.locator('#git').click();
  await expect(page.locator('main h1')).toHaveText('Git remote sync');
  await expect(page.locator('main')).toContainText('not connected');
  await expect(page.getByRole('button', { name: /Connect a remote/ })).toBeVisible();
});

test('backups tab shows the empty recovery-point state', async ({ page }) => {
  await openStack(page, 'web');
  await openTab(page, 'Backups');
  await expect(page.getByRole('button', { name: 'Back up now' })).toBeVisible();
  await expect(page.locator('#tabbody')).toContainText(/No recovery points|recovery point/i);
});

test('logs tab renders an output panel', async ({ page }) => {
  await openStack(page, 'web');
  await openTab(page, 'Logs');
  await expect(page.getByRole('button', { name: /Refresh/ })).toBeVisible();
  await expect(page.locator('#logout')).toBeVisible();
});
