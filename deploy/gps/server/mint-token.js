'use strict';

/**
 * Genera un JWT de prueba (mismo secreto que el servicio GPS).
 * Uso:
 *   node mint-token.js
 *   node mint-token.js motoA "Moto A" test1
 */
const jwt = require('jsonwebtoken');
const fs = require('fs');
const path = require('path');

function loadEnv() {
  const envPath = path.join(__dirname, '.env');
  if (!fs.existsSync(envPath)) return;
  for (const line of fs.readFileSync(envPath, 'utf8').split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const i = trimmed.indexOf('=');
    if (i < 0) continue;
    const key = trimmed.slice(0, i).trim();
    const value = trimmed.slice(i + 1).trim();
    if (!process.env[key]) process.env[key] = value;
  }
}

loadEnv();

const secret = process.env.JWT_SECRET || '';
const issuer = process.env.JWT_ISSUER || 'motoamg-panel';
if (!secret || secret.length < 32) {
  console.error('JWT_SECRET missing or too short in .env');
  process.exit(1);
}

const uid = process.argv[2] || 'motoA';
const displayName = process.argv[3] || 'Moto A';
const groupId = process.argv[4] || 'test1';

const token = jwt.sign(
  {
    displayName,
    groupIds: [groupId],
  },
  secret,
  {
    algorithm: 'HS256',
    issuer,
    subject: uid,
    expiresIn: '6h',
  },
);

console.log(token);
