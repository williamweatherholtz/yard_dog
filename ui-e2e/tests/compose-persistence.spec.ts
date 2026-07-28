import { test, expect } from '@playwright/test';
import { waitForRail, openStack, openTab, newStack } from './helpers';

// The headline reported bug: "when switching tabs after starting a new stack,
// all the compose is lost". Root cause: the editor content lived only in the DOM
// textarea, and every tab switch re-rendered from server state (which, for an
// unsaved stack, is empty). These tests pin the fix: a client-side draft buffer.

test.beforeEach(async ({ page }) => {
  await page.goto('/');
  await waitForRail(page);
});

test('new stack: typed compose survives a tab round-trip (the reported bug)', async ({ page }) => {
  await newStack(page, 'brand-new', 'web');

  const marker = 'services:\n  brand-new:\n    image: nginx:1.27-alpine  # MY-EDIT-MARKER\n';
  await page.locator('#editor').fill(marker);

  // Leave the Compose tab and come back.
  await openTab(page, 'Overview');
  await openTab(page, 'Compose');

  await expect(page.locator('#editor')).toHaveValue(marker);
});

test('existing stack: unsaved compose edits survive a tab round-trip', async ({ page }) => {
  await openStack(page, 'web');
  await openTab(page, 'Compose');

  const original = await page.locator('#editor').inputValue();
  const edited = original + '\n# unsaved edit marker\n';
  await page.locator('#editor').fill(edited);

  await openTab(page, 'History');
  await openTab(page, 'Compose');

  await expect(page.locator('#editor')).toHaveValue(edited);
});

test('drafts are per-stack: editing one stack does not bleed into another', async ({ page }) => {
  await openStack(page, 'web');
  await openTab(page, 'Compose');
  await page.locator('#editor').fill('services:\n  web:\n    image: WEB-DRAFT\n');

  await openStack(page, 'cache');
  await openTab(page, 'Compose');
  // cache must show its own compose, not web's draft.
  // NB: assert on .value (toHaveValue), not textContent (toContainText) — a
  // textarea's text is set via .value and its textContent stays empty.
  await expect(page.locator('#editor')).toHaveValue(/redis/);
  await expect(page.locator('#editor')).not.toHaveValue(/WEB-DRAFT/);

  // web's draft is still intact when we return.
  await openStack(page, 'web');
  await openTab(page, 'Compose');
  await expect(page.locator('#editor')).toHaveValue('services:\n  web:\n    image: WEB-DRAFT\n');
});
