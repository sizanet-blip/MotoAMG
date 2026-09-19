'use strict';

const http = require('http');
const crypto = require('crypto');
const { WebSocketServer } = require('ws');
const Redis = require('ioredis');
const jwt = require('jsonwebtoken');

const PORT = Number(process.env.PORT || 7890);
const REDIS_URL = process.env.REDIS_URL || 'redis://127.0.0.1:6379';
const LOCATION_TTL_SEC = Number(process.env.LOCATION_TTL_SEC || 120);
const JWT_SECRET = process.env.JWT_SECRET || '';
const JWT_ISSUER = process.env.JWT_ISSUER || 'motoamg-panel';
const JWT_TTL_SEC = Number(process.env.JWT_TTL_SEC || 21600);
const TOKEN_API_KEY = process.env.TOKEN_API_KEY || '';

if (!JWT_SECRET || JWT_SECRET.length < 32) {
  console.error('JWT_SECRET is required (min 32 chars)');
  process.exit(1);
}

if (!TOKEN_API_KEY) {
  console.error('TOKEN_API_KEY is required (same as panel apiKey)');
  process.exit(1);
}

const redis = new Redis(REDIS_URL, {
  maxRetriesPerRequest: 1,
  enableReadyCheck: true,
});

redis.on('error', (err) => {
  console.error('[redis]', err.message);
});

/** @type {Map<string, Set<import('ws').WebSocket>>} */
const rooms = new Map();

function roomKey(groupId) {
  return `group:${groupId}`;
}

function locKey(groupId, uid) {
  return `loc:${groupId}:${uid}`;
}

function alertKey(groupId, uid) {
  return `alert:${groupId}:${uid}`;
}

function alertsIndexKey(groupId) {
  return `alerts:${groupId}`;
}

function stopKey(groupId, stopId) {
  return `stop:${groupId}:${stopId}`;
}

function stopsIndexKey(groupId) {
  return `stops:${groupId}`;
}

function newId() {
  return crypto.randomBytes(8).toString('hex');
}

function send(socket, payload) {
  if (socket.readyState === 1) {
    socket.send(JSON.stringify(payload));
  }
}

function broadcast(groupId, payload, except) {
  const set = rooms.get(roomKey(groupId));
  if (!set) return;
  const raw = JSON.stringify(payload);
  for (const peer of set) {
    if (peer !== except && peer.readyState === 1) {
      peer.send(raw);
    }
  }
}

/** Broadcast a todos incluidos el emisor (avisos/paradas/voz). */
function broadcastAll(groupId, payload) {
  broadcast(groupId, payload, null);
}

async function snapshotLocations(groupId) {
  const set = rooms.get(roomKey(groupId));
  if (!set || set.size === 0) return [];
  const uids = new Set();
  for (const peer of set) {
    if (peer.meta && peer.meta.uid) uids.add(peer.meta.uid);
  }
  const list = [];
  for (const uid of uids) {
    const raw = await redis.get(locKey(groupId, uid));
    if (!raw) continue;
    try {
      list.push(JSON.parse(raw));
    } catch (_) {}
  }
  return list;
}

async function snapshotIncidents(groupId) {
  const uids = await redis.smembers(alertsIndexKey(groupId));
  const list = [];
  for (const uid of uids) {
    const raw = await redis.get(alertKey(groupId, uid));
    if (!raw) {
      await redis.srem(alertsIndexKey(groupId), uid);
      continue;
    }
    try {
      list.push(JSON.parse(raw));
    } catch (_) {
      await redis.srem(alertsIndexKey(groupId), uid);
    }
  }
  return list;
}

async function snapshotStops(groupId) {
  const ids = await redis.smembers(stopsIndexKey(groupId));
  const list = [];
  for (const stopId of ids) {
    const raw = await redis.get(stopKey(groupId, stopId));
    if (!raw) {
      await redis.srem(stopsIndexKey(groupId), stopId);
      continue;
    }
    try {
      list.push(JSON.parse(raw));
    } catch (_) {
      await redis.srem(stopsIndexKey(groupId), stopId);
    }
  }
  return list;
}

function leaveRoom(socket) {
  const meta = socket.meta;
  if (!meta) return;
  const key = roomKey(meta.groupId);
  const set = rooms.get(key);
  if (set) {
    set.delete(socket);
    if (set.size === 0) rooms.delete(key);
  }
}

async function clearLocation(groupId, uid) {
  await redis.del(locKey(groupId, uid));
  broadcast(groupId, { type: 'clear', uid });
}

/**
 * JWT claims esperados (los emite el panel):
 * - sub: uid del usuario
 * - displayName: nombre visible
 * - groupIds: array de grupos permitidos (opcional)
 * - iss: motoamg-panel
 */
function verifyJoinToken(token, groupId) {
  const payload = jwt.verify(token, JWT_SECRET, {
    algorithms: ['HS256'],
    issuer: JWT_ISSUER,
  });
  const uid = String(payload.sub || '').trim();
  if (!uid) {
    throw new Error('token sin sub');
  }
  const groupIds = Array.isArray(payload.groupIds)
    ? payload.groupIds.map((g) => String(g))
    : null;
  if (groupIds && !groupIds.includes(groupId)) {
    throw new Error('grupo no permitido en token');
  }
  const displayName = String(payload.displayName || uid).trim();
  return { uid, displayName };
}

function readJsonBody(req) {
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
  });
  res.end(payload);
}

function issueToken(uid, displayName, groupId) {
  return jwt.sign(
    {
      displayName: displayName || uid,
      groupIds: [groupId],
    },
    JWT_SECRET,
    {
      algorithm: 'HS256',
      issuer: JWT_ISSUER,
      subject: uid,
      expiresIn: JWT_TTL_SEC,
    },
  );
}

function asFiniteNumber(value) {
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

const server = http.createServer(async (req, res) => {
  const url = (req.url || '').split('?')[0];

  if (url === '/health') {
    let redisOk = false;
    try {
      redisOk = (await redis.ping()) === 'PONG';
    } catch (_) {
      redisOk = false;
    }
    sendJson(res, redisOk ? 200 : 503, {
      ok: redisOk,
      service: 'motoamg-gps',
      redis: redisOk ? 'up' : 'down',
      auth: 'jwt',
    });
    return;
  }

  if (url === '/token' && req.method === 'POST') {
    try {
      const body = await readJsonBody(req);
      const apiKey = String(
        body.apiKey || req.headers['x-motoamg-api-key'] || '',
      ).trim();
      if (!apiKey || apiKey !== TOKEN_API_KEY) {
        sendJson(res, 401, { ok: false, message: 'apiKey inválida' });
        return;
      }
      const uid = String(body.uid || '').trim();
      const groupId = String(body.groupId || '').trim();
      const displayName = String(body.displayName || uid).trim();
      if (!uid || !groupId) {
        sendJson(res, 422, {
          ok: false,
          message: 'uid y groupId son obligatorios',
        });
        return;
      }
      const token = issueToken(uid, displayName, groupId);
      sendJson(res, 200, {
        ok: true,
        token,
        expiresIn: JWT_TTL_SEC,
        wsUrl: 'wss://gps.albertomaestre.es/ws',
        uid,
        groupId,
        displayName,
      });
    } catch (err) {
      sendJson(res, 400, {
        ok: false,
        message: err.message || 'bad request',
      });
    }
    return;
  }

  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('Not found');
});

const wss = new WebSocketServer({ server, path: '/ws' });

wss.on('connection', (socket) => {
  socket.meta = null;

  send(socket, { type: 'hello', message: 'motoamg-gps ok', auth: 'jwt' });

  socket.on('message', async (data) => {
    let msg;
    try {
      msg = JSON.parse(String(data));
    } catch (_) {
      send(socket, { type: 'error', message: 'json invalido' });
      return;
    }

    try {
      if (msg.type === 'join') {
        const groupId = String(msg.groupId || '').trim();
        const token = String(msg.token || '').trim();
        if (!groupId || !token) {
          send(socket, {
            type: 'error',
            message: 'join requiere groupId y token',
          });
          return;
        }

        let identity;
        try {
          identity = verifyJoinToken(token, groupId);
        } catch (err) {
          send(socket, {
            type: 'error',
            message: `token invalido: ${err.message}`,
          });
          return;
        }

        leaveRoom(socket);
        socket.meta = {
          groupId,
          uid: identity.uid,
          displayName: identity.displayName,
        };
        const key = roomKey(groupId);
        if (!rooms.has(key)) rooms.set(key, new Set());
        rooms.get(key).add(socket);

        const [locations, incidents, stops] = await Promise.all([
          snapshotLocations(groupId),
          snapshotIncidents(groupId),
          snapshotStops(groupId),
        ]);
        send(socket, {
          type: 'joined',
          groupId,
          uid: identity.uid,
          locations,
          incidents,
          stops,
        });
        console.log('[ws] join', groupId, identity.uid);
        return;
      }

      if (msg.type === 'publish') {
        if (!socket.meta) {
          send(socket, { type: 'error', message: 'haz join antes' });
          return;
        }
        const { groupId, uid, displayName } = socket.meta;
        const location = {
          uid,
          groupId,
          displayName,
          lat: Number(msg.lat),
          lng: Number(msg.lng),
          heading: Number(msg.heading || 0),
          speed: Number(msg.speed || 0),
          hasSignal: msg.hasSignal !== false,
          updatedAt: Date.now(),
        };
        if (!Number.isFinite(location.lat) || !Number.isFinite(location.lng)) {
          send(socket, { type: 'error', message: 'lat/lng invalidos' });
          return;
        }

        await redis.set(
          locKey(groupId, uid),
          JSON.stringify(location),
          'EX',
          LOCATION_TTL_SEC,
        );
        broadcast(groupId, { type: 'location', location }, socket);
        send(socket, { type: 'published', updatedAt: location.updatedAt });
        return;
      }

      if (msg.type === 'publish_incident') {
        if (!socket.meta) {
          send(socket, { type: 'error', message: 'haz join antes' });
          return;
        }
        const { groupId, uid, displayName } = socket.meta;
        const raw =
          msg.incident && typeof msg.incident === 'object' ? msg.incident : msg;
        const lat = asFiniteNumber(raw.lat);
        const lng = asFiniteNumber(raw.lng);
        if (lat === null || lng === null) {
          send(socket, { type: 'error', message: 'aviso: lat/lng invalidos' });
          return;
        }
        const type = String(raw.type || '').trim();
        if (!type) {
          send(socket, { type: 'error', message: 'aviso: falta type' });
          return;
        }
        const incident = {
          uid,
          type,
          lat,
          lng,
          at: String(raw.at || new Date().toISOString()),
          active: raw.active !== false,
          displayName:
            String(raw.displayName || displayName).trim() || displayName,
        };
        if (raw.severity) {
          incident.severity = String(raw.severity);
        }
        await redis.set(alertKey(groupId, uid), JSON.stringify(incident));
        await redis.sadd(alertsIndexKey(groupId), uid);
        broadcastAll(groupId, { type: 'incident', incident });
        return;
      }

      if (msg.type === 'clear_incident') {
        if (!socket.meta) {
          send(socket, { type: 'error', message: 'haz join antes' });
          return;
        }
        const { groupId, uid } = socket.meta;
        const targetUid = String(msg.uid || uid).trim() || uid;
        if (targetUid !== uid) {
          send(socket, {
            type: 'error',
            message: 'solo puedes quitar tu propio aviso',
          });
          return;
        }
        await redis.del(alertKey(groupId, uid));
        await redis.srem(alertsIndexKey(groupId), uid);
        broadcastAll(groupId, { type: 'incident_cleared', uid });
        return;
      }

      if (msg.type === 'publish_stop') {
        if (!socket.meta) {
          send(socket, { type: 'error', message: 'haz join antes' });
          return;
        }
        const { groupId, uid, displayName } = socket.meta;
        const raw = msg.stop && typeof msg.stop === 'object' ? msg.stop : msg;
        const lat = asFiniteNumber(raw.lat);
        const lng = asFiniteNumber(raw.lng);
        if (lat === null || lng === null) {
          send(socket, { type: 'error', message: 'parada: lat/lng invalidos' });
          return;
        }
        const stopType = String(raw.type || '').trim();
        if (!stopType) {
          send(socket, { type: 'error', message: 'parada: falta type' });
          return;
        }
        const stopId = String(raw.id || '').trim() || newId();
        const stop = {
          id: stopId,
          type: stopType,
          lat,
          lng,
          at: String(raw.at || new Date().toISOString()),
          createdBy: uid,
          displayName:
            String(raw.displayName || displayName).trim() || displayName,
          active: raw.active !== false,
        };
        await redis.set(stopKey(groupId, stopId), JSON.stringify(stop));
        await redis.sadd(stopsIndexKey(groupId), stopId);
        broadcastAll(groupId, { type: 'stop', stop });
        send(socket, { type: 'stop_published', stopId });
        return;
      }

      if (msg.type === 'clear_stop') {
        if (!socket.meta) {
          send(socket, { type: 'error', message: 'haz join antes' });
          return;
        }
        const { groupId } = socket.meta;
        const stopId = String(msg.stopId || '').trim();
        if (!stopId) {
          send(socket, { type: 'error', message: 'falta stopId' });
          return;
        }
        await redis.del(stopKey(groupId, stopId));
        await redis.srem(stopsIndexKey(groupId), stopId);
        broadcastAll(groupId, { type: 'stop_cleared', stopId });
        return;
      }

      if (msg.type === 'publish_voice') {
        if (!socket.meta) {
          send(socket, { type: 'error', message: 'haz join antes' });
          return;
        }
        const { groupId, uid, displayName } = socket.meta;
        const raw =
          msg.announcement && typeof msg.announcement === 'object'
            ? msg.announcement
            : msg;
        const kind = String(raw.kind || '').trim();
        if (!kind) {
          send(socket, { type: 'error', message: 'voz: falta kind' });
          return;
        }
        const announcement = {
          id: newId(),
          uid,
          kind,
          at: String(raw.at || new Date().toISOString()),
          displayName:
            String(raw.displayName || displayName).trim() || displayName,
        };
        broadcastAll(groupId, { type: 'voice', announcement });
        return;
      }

      if (msg.type === 'leave') {
        if (socket.meta) {
          const { groupId, uid } = socket.meta;
          leaveRoom(socket);
          await clearLocation(groupId, uid);
          socket.meta = null;
          send(socket, { type: 'left' });
        }
        return;
      }

      send(socket, { type: 'error', message: 'tipo desconocido' });
    } catch (err) {
      console.error('[ws] handler', err);
      send(socket, { type: 'error', message: 'error interno' });
    }
  });

  socket.on('close', async () => {
    if (!socket.meta) return;
    const { groupId, uid } = socket.meta;
    leaveRoom(socket);
    try {
      await clearLocation(groupId, uid);
    } catch (err) {
      console.error('[ws] clear on close', err.message);
    }
    console.log('[ws] disconnect', groupId, uid);
  });
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`[motoamg-gps] http://127.0.0.1:${PORT}/health`);
  console.log(`[motoamg-gps] ws://127.0.0.1:${PORT}/ws`);
});
