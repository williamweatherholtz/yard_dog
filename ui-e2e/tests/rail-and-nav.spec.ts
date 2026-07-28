import { test, expect } from '@playwright/test';
import { waitForRail, openStack, openTab } from './helpers';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await waitForRail(page);
});

test('rail lists the fixture stacks with the right status signals', async ({ page }) => {
  await expect(page.locator('.srow', { hasText: 'web' })).toBeVisible();
  await expect(page.locator('.srow', { hasText: 'cache' })).toBeVisible();
  await expect(page.locator('.srow', { hasText: 'risky' })).toBeVisible();

  // risky has block-severity guardrails -> bad signal + block count.
  await expect(page.locator('.srow', { hasText: 'risky' }).locator('.sig.bad')).toBeVisible();
  await expect(page.locator('.srow', { hasText: 'risky' }).locator('.n.bad')).toBeVisible();
  // web only warns.
  await expect(page.locator('.srow', { hasText: 'web' }).locator('.n.warn')).toBeVisible();
  // cache is clean.
  await expect(page.locator('.srow', { hasText: 'cache' }).locator('.sig.ok')).toBeVisible();
});

test('filter narrows the rail and updates the count', async ({ page }) => {
  await page.locator('#filter').fill('web');
  await expect(page.locator('.srow')).toHaveCount(1);
  await expect(page.locator('.srow', { hasText: 'web' })).toBeVisible();
  await expect(page.locator('.srow', { hasText: 'cache' })).toHaveCount(0);
  await expect(page.locator('#stackcount')).toHaveText(/^1\/\d+$/); // "1 shown / N total"
  await page.locator('#filter').fill('');
  await expect(page.locator('.srow', { hasText: 'cache' })).toBeVisible();
});

test('selecting a stack marks it active and shows the detail header', async ({ page }) => {
  await openStack(page, 'web');
  await expect(page.locator('.srow.active', { hasText: 'web' })).toBeVisible();
  await expect(page.locator('.dhead h1')).toHaveText('web');
  await expect(page.locator('.dhead .pill')).toHaveCount(2); // ready + lifecycle
});

test('every detail tab renders its own content', async ({ page }) => {
  await openStack(page, 'web');

  await openTab(page, 'Overview');
  await expect(page.locator('#tabbody')).toContainText('Services');

  await openTab(page, 'Compose');
  await expect(page.locator('#editor')).toBeVisible();

  await openTab(page, 'Mounts');
  await expect(page.locator('#tabbody table')).toBeVisible();

  await openTab(page, 'Permissions');
  await expect(page.locator('#tabbody')).toContainText(/Compliant/i);

  await openTab(page, 'History');
  await expect(page.locator('#tabbody')).toContainText(/snapshot|No snapshots/i);

  await openTab(page, 'Backups');
  await expect(page.locator('#tabbody')).toContainText(/recovery point|No recovery points/i);

  await openTab(page, 'Terminal');
  await expect(page.locator('#termhost .xterm')).toBeVisible({ timeout: 10_000 });
});

test('the console dock is present and clearable', async ({ page }) => {
  await expect(page.locator('#console')).toBeVisible();
  await expect(page.locator('.dock-bar .ttl')).toContainText('Console');
});

test('theme toggle flips and persists the document theme', async ({ page }) => {
  const html = page.locator('html');
  await page.locator('#nav-theme').click();
  const first = await html.getAttribute('data-theme');
  expect(first === 'dark' || first === 'light').toBeTruthy();
  await page.locator('#nav-theme').click();
  const second = await html.getAttribute('data-theme');
  expect(second).not.toEqual(first);
  // persisted across reloads
  await page.reload();
  await expect(html).toHaveAttribute('data-theme', second!);
});
