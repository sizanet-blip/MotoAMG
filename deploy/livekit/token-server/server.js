'use strict';

const http = require('http');
const { AccessToken } = require('livekit-server-sdk');
const admin = require('firebase-admin');

const PORT = Number(process.env.PORT || 7882);
const LIVEKIT_URL = process.env.LIVEKIT_URL || 'wss://livekit.albertomaestre.es';
const LIVEKIT_API_KEY = process.env.LIVEKIT_API_KEY || 'motoamg';
const LIVEKIT_API_SECRET = process.env.LIVEKIT_API_SECRET || '';
const TOKEN_TTL = process.env.TOKEN_TTL || '6h';

if (!LIVEKIT_API_SECRET) {
  console.error('LIVEKIT_API_SECRET is required');
  process.exit(1);
}

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });
}

const db = admin.firestore();

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      const raw = Buffer.concat(chunks).toString('utf8');
      if (!raw) {
        resolve({});
        return;
      }
      try {
        resolve(JSON.parse(raw));
      } catch (err) {
        reject(err);
      }
    });
    req.on('error', reject);
  });
}

function sendJson(res, status, body) {
  const payload = JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(payload),
    'Cache-Control': 'no-store',
  });
  res.end(payload);
}

function bearerToken(req) {
  const header = req.headers.authorization || '';
  const match = /^Bearer\s+(.+)$/i.exec(header);
  return match ? match[1].trim() : '';
}

async function handleToken(req, res) {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Authorization, Content-Type',
    });
    res.end();
    return;
  }

  if (req.method !== 'POST') {
    sendJson(res, 405, { error: 'method_not_allowed' });
    return;
  }

  const idToken = bearerToken(req);
  if (!idToken) {
    sendJson(res, 401, { error: 'missing_authorization' });
    return;
  }

  let body;
  try {
    body = await readBody(req);
  } catch (_) {
    sendJson(res, 400, { error: 'invalid_json' });
    return;
  }

  const groupId = typeof body.groupId === 'string' ? body.groupId.trim() : '';
  if (!groupId) {
    sendJson(res, 400, { error: 'missing_group_id' });
    return;
  }

  let decoded;
  try {
    decoded = await admin.auth().verifyIdToken(idToken);
  } catch (_) {
    sendJson(res, 401, { error: 'invalid_firebase_token' });
    return;
  }

  const uid = decoded.uid;
  const memberRef = db.collection('groups').doc(groupId).collection('members').doc(uid);
  const memberSnap = await memberRef.get();
  if (!memberSnap.exists) {
    sendJson(res, 403, { error: 'not_group_member' });
    return;
  }

  const groupSnap = await db.collection('groups').doc(groupId).get();
  if (!groupSnap.exists) {
    sendJson(res, 404, { error: 'group_not_found' });
    return;
  }
  const groupData = groupSnap.data() || {};
  if (groupData.intercomEnabled !== true) {
    sendJson(res, 403, { error: 'intercom_disabled' });
    return;
  }

  const member = memberSnap.data() || {};
  const displayName =
    (typeof member.displayName === 'string' && member.displayName.trim()) ||
    decoded.name ||
    uid;

  const at = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
    identity: uid,
    name: displayName,
    ttl: TOKEN_TTL,
  });
  at.addGrant({
    roomJoin: true,
    room: groupId,
    canPublish: true,
    canSubscribe: true,
    canPublishData: false,
  });

  const token = await at.toJwt();
  sendJson(res, 200, {
    url: LIVEKIT_URL,
    token,
    room: groupId,
  });
}

const server = http.createServer(async (req, res) => {
  try {
    const path = (req.url || '').split('?')[0];
    if (path === '/health' || path === '/') {
      sendJson(res, 200, { ok: true });
      return;
    }
    if (path === '/token') {
      await handleToken(req, res);
      return;
    }
    sendJson(res, 404, { error: 'not_found' });
  } catch (err) {
    console.error(err);
    sendJson(res, 500, { error: 'internal_error' });
  }
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`motoamg-livekit-token listening on 127.0.0.1:${PORT}`);
});
