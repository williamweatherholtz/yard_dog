import { Page, expect } from '@playwright/test';

/** Wait until the rail has finished its initial load. */
export async function waitForRail(page: Page) {
  await expect(page.locator('.stack-item').first()).toBeVisible();
}

/** Open a stack from the left rail by its name. */
export async function openStack(page: Page, name: string) {
  await page.locator('.stack-item', { hasText: name }).click();
  await expect(page.locator('.detail-head h1')).toHaveText(name);
}

/** Click a detail tab by its visible label. */
export async function openTab(page: Page, label: string) {
  await page.locator('.tab', { hasText: new RegExp(`^${label}`) }).click();
}

/**
 * Create a new stack via the "+ New stack" flow, answering the two prompts
 * (name, then workload kind). Returns after the compose editor is showing.
 */
export async function newStack(page: Page, name: string, kind = 'web') {
  const answers = [name, kind];
  page.on('dialog', async (d) => {
    if (d.type() === 'prompt') await d.accept(answers.shift() ?? '');
    else await d.accept();
  });
  await page.locator('#newstack').click();
  await expect(page.locator('#editor')).toBeVisible();
}
