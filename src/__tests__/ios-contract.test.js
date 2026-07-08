const { describe, expect, it } = require('@jest/globals');
const { readFileSync } = require('node:fs');
const path = require('node:path');

const iosSource = readFileSync(
  path.join(__dirname, '../../ios/NaverLogin.mm'),
  'utf8'
);

describe('iOS native promise contract', () => {
  it('keeps in-progress login and refreshToken calls as resolved failures', () => {
    expect(iosSource).not.toContain('reject(@"LOGIN_IN_PROGRESS"');
    expect(iosSource).not.toContain('reject(@"REFRESH_IN_PROGRESS"');
    expect(iosSource).toContain(
      '@"message": @"A login request is already in progress."'
    );
    expect(iosSource).toContain(
      '@"message": @"A refreshToken request is already in progress."'
    );
  });
});
