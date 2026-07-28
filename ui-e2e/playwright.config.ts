import { defineConfig, devices } from '@playwright/test';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';

// Prepare an ISOLATED serve root (a fresh copy of the fixtures) BEFORE the yd
// webServer launches. Config modules load before the webServer + tests, so this
// runs first. A per-run copy keeps mutating tests (new stack, save) from
// polluting the committed fixtures.
const ROOT = path.join(os.tmpdir(), 'yd-ui-e2e-root');
fs.rmSync(ROOT, { recursive: true, force: true });
fs.cpSync(path.join(__dirname, 'fixtures', 'stacks'), ROOT, { recursive: true });
// The web stack has one EXISTING host-bind (created here) and one MISSING one
// (never created) so the Mounts tab exercises both exists/missing states.
fs.mkdirSync(path.join(ROOT, 'web', 'html'), { recursive: true });
fs.writeFileSync(path.join(ROOT, 'web', 'html', 'index.html'), '<h1>hi</h1>\n');

const PORT = process.env.YD_E2E_PORT || '8788';
const YD = path.resolve(
  __dirname, '..', 'app', 'target', 'release',
  process.platform === 'win32' ? 'yd.exe' : 'yd',
);

export default defineConfig({
  testDir: './tests',
  fullyParallel: false, // one shared serve process + one shared root
  workers: 1,
  timeout: 30_000,
  expect: { timeout: 7_000 },
  reporter: process.env.CI ? 'line' : [['list']],
  use: {
    baseURL: `http://127.0.0.1:${PORT}`,
    trace: 'retain-on-failure',
  },
  webServer: {
    command: `"${YD}" serve --root "${ROOT}" --port ${PORT} --host 127.0.0.1`,
    url: `http://127.0.0.1:${PORT}/`,
    reuseExistingServer: false,
    timeout: 20_000,
    stdout: 'ignore',
    stderr: 'pipe',
  },
  projects: [{ name: 'chromium', use: { ...devices['Desktop Chrome'] } }],
});
