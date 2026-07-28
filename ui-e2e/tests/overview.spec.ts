import { test, expect } from '@playwright/test';
import { waitForRail, openStack, openTab } from './helpers';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await waitForRail(page);
});

test('overview lists guardrail issues and the services table (no kind column)', async ({ page }) => {
  await openStack(page, 'web');
  await openTab(page, 'Overview');

  await expect(page.locator('#tabbody')).toContainText('0 blocking');
  await expect(page.locator('.issue.warn').first()).toBeVisible();

  // service row shows name + image; the Kind column is gone.
  const row = page.locator('#tabbody table tr', { hasText: 'web' });
  await expect(row).toContainText('nginx');
  await expect(page.locator('#tabbody table th', { hasText: 'Kind' })).toHaveCount(0);
});

test('a clean stack shows no guardrail issues', async ({ page }) => {
  await openStack(page, 'cache');
  await openTab(page, 'Overview');
  await expect(page.locator('#tabbody')).toContainText('No guardrail issues');
});

test('overview action bar exposes the guarded actions', async ({ page }) => {
  await openStack(page, 'web');
  await openTab(page, 'Overview');
  const bar = page.locator('#tabbody .bar').first();
  await expect(bar.getByRole('button', { name: 'Deploy' })).toBeVisible();
  await expect(bar.getByRole('button', { name: /Refresh status/ })).toBeVisible();
  await expect(bar.getByRole('button', { name: 'Back up' })).toBeVisible();
  await expect(bar.getByRole('button', { name: 'Down' })).toBeVisible();
  await expect(bar.getByRole('button', { name: 'Activate' })).toBeVisible();
});

test('a blocking stack shows block-severity issues', async ({ page }) => {
  await openStack(page, 'risky');
  await openTab(page, 'Overview');
  await expect(page.locator('#tabbody')).toContainText('2 blocking');
  await expect(page.locator('.issue.block').first()).toBeVisible();
});

test('inline upgrade form replaces the browser prompt', async ({ page }) => {
  await openStack(page, 'web');
  await openTab(page, 'Overview');
  await page.locator('#tabbody table tr', { hasText: 'web' }).getByRole('button', { name: 'Upgrade…' }).click();
  // an inline row with an image input appears — no dialog.
  await expect(page.locator('tr.upg input')).toBeVisible();
  await expect(page.locator('tr.upg input')).toHaveValue(/nginx/);
  await page.getByRole('button', { name: 'Cancel' }).click();
  await expect(page.locator('tr.upg')).toHaveCount(0);
});
