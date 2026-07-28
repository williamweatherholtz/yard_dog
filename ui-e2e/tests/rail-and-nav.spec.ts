import { test, expect } from '@playwright/test';
import { waitForRail, openStack, openTab } from './helpers';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await waitForRail(page);
});

test('rail lists the fixture stacks with the right issue badges', async ({ page }) => {
  await expect(page.locator('.stack-item', { hasText: 'web' })).toBeVisible();
  await expect(page.locator('.stack-item', { hasText: 'cache' })).toBeVisible();
  await expect(page.locator('.stack-item', { hasText: 'risky' })).toBeVisible();

  // risky has block-severity guardrails -> red block badge.
  await expect(page.locator('.stack-item', { hasText: 'risky' }).locator('.badge-issue.block')).toBeVisible();
  // web only warns.
  await expect(page.locator('.stack-item', { hasText: 'web' }).locator('.badge-issue.warn')).toBeVisible();
  // cache is clean -> ok check.
  await expect(page.locator('.stack-item', { hasText: 'cache' }).locator('.badge-issue.ok')).toBeVisible();
});

test('filter narrows the rail', async ({ page }) => {
  await page.locator('#filter').fill('web');
  await expect(page.locator('.stack-item', { hasText: 'web' })).toBeVisible();
  await expect(page.locator('.stack-item', { hasText: 'cache' })).toHaveCount(0);
  await page.locator('#filter').fill('');
  await expect(page.locator('.stack-item', { hasText: 'cache' })).toBeVisible();
});

test('notification badge surfaces stacks with blocking issues', async ({ page }) => {
  const notif = page.locator('#notif');
  await expect(notif).toBeVisible();               // risky blocks -> shown
  await expect(page.locator('#notifn')).toHaveText('1');
});

test('selecting a stack marks it active and shows the detail header', async ({ page }) => {
  await openStack(page, 'web');
  await expect(page.locator('.stack-item.active', { hasText: 'web' })).toBeVisible();
  await expect(page.locator('.detail-head h1')).toHaveText('web');
  await expect(page.locator('.badge')).toBeVisible(); // READY / NOT READY
});

test('every detail tab renders its own content', async ({ page }) => {
  await openStack(page, 'web');

  await openTab(page, 'Overview');
  await expect(page.locator('#tabbody')).toContainText('Services');

  await openTab(page, 'Compose');
  await expect(page.locator('#editor')).toBeVisible();

  await openTab(page, 'History');
  await expect(page.locator('#tabbody')).toContainText(/snapshot|No snapshots/i);

  await openTab(page, 'Mounts');
  await expect(page.locator('#tabbody table')).toBeVisible();

  await openTab(page, 'Permissions');
  await expect(page.locator('#tabbody')).toContainText(/COMPLIANT/);

  await openTab(page, 'Backups');
  await expect(page.locator('#tabbody')).toContainText(/recovery point|No recovery points/i);

  await openTab(page, 'Logs');
  await expect(page.locator('#logout')).toBeVisible();

  // the output console lives under every tab
  await expect(page.locator('#console')).toBeVisible();
});

test('theme toggle flips the document theme', async ({ page }) => {
  const html = page.locator('html');
  await page.locator('#theme').click();
  const first = await html.getAttribute('data-theme');
  expect(first === 'dark' || first === 'light').toBeTruthy();
  await page.locator('#theme').click();
  const second = await html.getAttribute('data-theme');
  expect(second).not.toEqual(first);
});
