import { test, expect } from '@playwright/test';
import { waitForRail, openStack, openTab } from './helpers';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await waitForRail(page);
});

test('overview lists guardrail issues and the services table', async ({ page }) => {
  await openStack(page, 'web');
  await openTab(page, 'Overview');

  // web: 0 blocking, 2 warnings (no healthcheck / no mem_limit).
  await expect(page.locator('#tabbody')).toContainText('0 blocking');
  await expect(page.locator('#tabbody h3', { hasText: 'Issues' })).toBeVisible();
  await expect(page.locator('.issue.warn').first()).toBeVisible();

  // service row present with image + kind.
  const row = page.locator('#tabbody table tr', { hasText: 'web' });
  await expect(row).toContainText('nginx');
  await expect(row.locator('.kind')).toBeVisible();
});

test('a clean stack shows no guardrail issues', async ({ page }) => {
  await openStack(page, 'cache');
  await openTab(page, 'Overview');
  await expect(page.locator('#tabbody')).toContainText('No guardrail issues');
});

test('overview action bar exposes the guarded actions', async ({ page }) => {
  await openStack(page, 'web');
  await openTab(page, 'Overview');
  const bar = page.locator('#tabbody .actionbar').first();
  await expect(bar.getByRole('button', { name: 'Deploy' })).toBeVisible();
  await expect(bar.getByRole('button', { name: /Status/ })).toBeVisible();
  await expect(bar.getByRole('button', { name: 'Back up' })).toBeVisible();
  await expect(bar.getByRole('button', { name: 'Down' })).toBeVisible();
  // draft lifecycle offers Activate + Archive transitions.
  await expect(bar.getByRole('button', { name: 'Activate' })).toBeVisible();
});

test('a blocking stack shows block-severity issues', async ({ page }) => {
  await openStack(page, 'risky');
  await openTab(page, 'Overview');
  await expect(page.locator('#tabbody')).toContainText('2 blocking');
  await expect(page.locator('.issue.block').first()).toBeVisible();
});
