import { Page, expect } from '@playwright/test';

/** Wait until the rail has finished its initial load. */
export async function waitForRail(page: Page) {
  await expect(page.locator('.srow').first()).toBeVisible();
}

/** Open a stack from the left rail by its name. */
export async function openStack(page: Page, name: string) {
  await page.locator('.srow', { hasText: name }).click();
  await expect(page.locator('.dhead h1')).toHaveText(name);
}

/** Click a detail tab by its visible label. */
export async function openTab(page: Page, label: string) {
  await page.locator('.tab', { hasText: new RegExp(`^${label}`) }).click();
}

/**
 * Create a new stack via the inline "+ New stack" panel (no browser popups):
 * fill the name field and press Create. Returns once the compose editor shows.
 */
export async function newStack(page: Page, name: string) {
  await page.locator('#newstack').click();
  await page.locator('.form input').fill(name);
  await page.getByRole('button', { name: 'Create stack' }).click();
  await expect(page.locator('#editor')).toBeVisible();
}
