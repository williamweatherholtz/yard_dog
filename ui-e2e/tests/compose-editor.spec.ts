import { test, expect } from '@playwright/test';
import { waitForRail, openStack, openTab, newStack } from './helpers';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await waitForRail(page);
});

test('live check reacts to a block-severity guardrail as you type', async ({ page }) => {
  await openStack(page, 'web');
  await openTab(page, 'Compose');

  // A floating :latest tag is block-severity -> Not ready.
  await page.locator('#editor').fill('services:\n  web:\n    image: nginx:latest\n');
  await expect(page.locator('#vpanel .pill')).toHaveText('Not ready');
  await expect(page.locator('#vpanel .issue.block').first()).toBeVisible();

  // A pinned, well-formed service clears the block.
  await page.locator('#editor').fill(
    'services:\n  web:\n    image: nginx:1.27-alpine\n    restart: unless-stopped\n    mem_limit: 128m\n    healthcheck:\n      test: ["CMD", "true"]\n',
  );
  await expect(page.locator('#vpanel .pill')).toHaveText('Ready');
});

test('new stack opens Compose pre-filled with the starter template (no kind)', async ({ page }) => {
  await newStack(page, 'fresh-svc');
  await expect(page.locator('.tab.active')).toHaveText('Compose');
  await expect(page.locator('#editor')).toHaveValue(/fresh-svc/);
  await expect(page.locator('#editor')).toHaveValue(/restart: unless-stopped/);
  await expect(page.locator('#editor')).not.toHaveValue(/kind/);
  await expect(page.locator('.srow', { hasText: 'fresh-svc' })).toBeVisible();
});

test('saving a stack snapshots it and history shows the commit', async ({ page }) => {
  await newStack(page, 'save-me');
  await page.locator('#tabbody').getByRole('button', { name: 'Save snapshot' }).click();
  await expect(page.locator('#console')).toContainText('saved', { timeout: 10_000 });

  await openTab(page, 'History');
  await expect(page.locator('.hist li').first()).toBeVisible();
  await expect(page.locator('.hist li').first()).toContainText(/[0-9a-f]{7}/);
});

test('console output survives a tab switch (persistent buffer)', async ({ page }) => {
  await newStack(page, 'log-keep');
  await page.locator('#tabbody').getByRole('button', { name: 'Save snapshot' }).click();
  await expect(page.locator('#console')).toContainText('saved', { timeout: 10_000 });

  await openTab(page, 'Overview');
  await openTab(page, 'Compose');
  await expect(page.locator('#console')).toContainText('saved');
});
