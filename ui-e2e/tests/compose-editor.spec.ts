import { test, expect } from '@playwright/test';
import { waitForRail, openStack, openTab, newStack } from './helpers';

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await waitForRail(page);
});

test('validate panel reacts to a block-severity guardrail as you type', async ({ page }) => {
  await openStack(page, 'web');
  await openTab(page, 'Compose');

  // A floating :latest tag is block-severity -> NOT READY.
  await page.locator('#editor').fill('services:\n  web:\n    image: nginx:latest\n');
  await expect(page.locator('#vpanel .v-badge')).toHaveText('NOT READY');
  await expect(page.locator('#vpanel .issue.block').first()).toBeVisible();

  // A pinned, well-formed service clears the block.
  await page.locator('#editor').fill(
    'services:\n  web:\n    image: nginx:1.27-alpine\n    restart: unless-stopped\n    mem_limit: 128m\n    healthcheck:\n      test: ["CMD", "true"]\n',
  );
  await expect(page.locator('#vpanel .v-badge')).toHaveText('READY');
});

test('new stack opens the Compose tab pre-filled with the kind template', async ({ page }) => {
  await newStack(page, 'fresh-web', 'web');
  await expect(page.locator('.tab.active')).toHaveText('Compose');
  await expect(page.locator('#editor')).toHaveValue(/# kind: web/);
  await expect(page.locator('#editor')).toHaveValue(/nginx/);
  // it also appears in the rail immediately.
  await expect(page.locator('.stack-item', { hasText: 'fresh-web' })).toBeVisible();
});

test('saving a stack snapshots it and history then shows the commit', async ({ page }) => {
  await newStack(page, 'save-me', 'worker');
  await page.locator('#tabbody').getByRole('button', { name: 'Save (snapshot)' }).click();
  await expect(page.locator('#console')).toContainText('saved', { timeout: 10_000 });

  await openTab(page, 'History');
  await expect(page.locator('.hist li').first()).toBeVisible();
  await expect(page.locator('.hist li').first()).toContainText(/[0-9a-f]{7}/);
});

test('console output survives a tab switch (persistent buffer)', async ({ page }) => {
  await newStack(page, 'log-keep', 'worker');
  await page.locator('#tabbody').getByRole('button', { name: 'Save (snapshot)' }).click();
  await expect(page.locator('#console')).toContainText('saved', { timeout: 10_000 });

  await openTab(page, 'Overview');
  await openTab(page, 'Compose');
  // output must still be there after leaving and returning.
  await expect(page.locator('#console')).toContainText('saved');
});
