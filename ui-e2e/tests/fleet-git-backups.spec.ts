import { test, expect } from '@playwright/test';
import { waitForRail, openStack, openTab } from './helpers';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await waitForRail(page);
});

test('all-stacks (fleet) view aggregates every stack with bulk actions', async ({ page }) => {
  await page.locator('#nav-all').click();
  await expect(page.locator('.dhead h1')).toHaveText('All stacks');
  await expect(page.locator('main')).toContainText('Every stack under the served root'); // self-explanatory intro
  await expect(page.getByRole('button', { name: 'Check all' })).toBeVisible();
  await expect(page.getByRole('button', { name: 'Back up all' })).toBeVisible();

  const tbl = page.locator('main table');
  await expect(tbl.locator('tr', { hasText: 'web' })).toBeVisible();
  await expect(tbl.locator('tr', { hasText: 'cache' })).toBeVisible();
  await expect(tbl.locator('tr', { hasText: 'risky' })).toBeVisible();
  // fixtures start unadopted.
  await expect(tbl.locator('.chip.warn', { hasText: 'unadopted' }).first()).toBeVisible();
});

test('git panel shows the not-connected state and an inline connect form (no prompt)', async ({ page }) => {
  await page.locator('#nav-git').click();
  await expect(page.locator('.dhead h1')).toHaveText('Git remote');
  await expect(page.locator('main .pill', { hasText: 'Not connected' })).toBeVisible();
  await expect(page.locator('.form input')).toBeVisible(); // remote URL field, inline
  await expect(page.getByRole('button', { name: 'Connect' })).toBeVisible();
  await expect(page.locator('main')).toContainText(/system Git credentials/i);
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
