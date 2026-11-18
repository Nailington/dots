import http from 'node:http';
import net from 'node:net';
import fs from 'node:fs';
import crypto from 'node:crypto';
import { pathToFileURL } from 'node:url';

const domains = ['openai.com', 'anthropic.com', 'claude.ai', 'chatgpt.com', 'oaistatic.com'];
// Claude renews OAuth tokens here; permit this exact host, not all of claude.com.
const exactHosts = ['platform.claude.com'];

export function allowedTarget(value) {
  const target = /^([a-z0-9.-]+):443$/i.exec(value || '');
  const host = target?.[1].toLowerCase();
  return host && (exactHosts.includes(host) || domains.some(domain => host === domain || host.endsWith('.' + domain))) ? host : null;
}

export function createProxy({ token, allowedClients, dial = options => net.connect(options) }) {
if (!token || token.length < 32) throw new Error('The connection key must be at least 32 characters');
if (!allowedClients?.length || allowedClients.some(address => !net.isIP(address))) throw new Error('Specify the hub IP with --allow-client');
const active = new Set();
const server = http.createServer((request, response) => {
  response.writeHead(405, { Connection: 'close' });
  response.end();
});
server.on('connect', (request, client, head) => {
  const auth = request.headers['proxy-authorization'] || '';
  const supplied = auth.startsWith('Basic ') ? Buffer.from(auth.slice(6), 'base64').toString().split(':', 1)[0] : '';
  const expectedBytes = Buffer.from(token);
  const suppliedBytes = Buffer.from(supplied);
  const authorized = suppliedBytes.length === expectedBytes.length && crypto.timingSafeEqual(expectedBytes, suppliedBytes);
  const host = allowedTarget(request.url);
  const allowed = !!host;
  if (!authorized || !allowed) {
    client.end(`HTTP/1.1 ${authorized ? 403 : 407} Rejected\r\nContent-Length: 0\r\nConnection: close\r\n\r\n`);
    return;
  }
  if (active.size >= 64) {
    client.end('HTTP/1.1 503 Busy\r\nContent-Length: 0\r\nConnection: close\r\n\r\n');
    return;
  }
  active.add(client);
  let connected = false;
  const upstream = dial({ host, port: 443 });
  upstream.setTimeout(5000);
  upstream.setKeepAlive(true, 30000);
  client.setKeepAlive(true, 30000);
  upstream.once('connect', () => {
    connected = true;
    upstream.setTimeout(0);
    client.write('HTTP/1.1 200 Connection Established\r\n\r\n');
    if (head.length) upstream.write(head);
    client.pipe(upstream);
    upstream.pipe(client);
  });
  upstream.on('timeout', () => upstream.destroy(new Error('Connection unavailable')));
  upstream.on('error', () => {
    if (!connected && client.writable) client.end('HTTP/1.1 502 Bad Gateway\r\nContent-Length: 0\r\nConnection: close\r\n\r\n');
    else client.destroy();
  });
  client.on('error', () => upstream.destroy());
  client.on('close', () => {
    active.delete(client);
    upstream.destroy();
  });
  upstream.on('close', () => {
    if (connected) client.destroy();
  });
});
server.on('connection', socket => {
  const address = (socket.remoteAddress || '').replace(/^::ffff:/, '');
  if (!allowedClients.includes(address)) socket.destroy();
});
server.on('clientError', (_, socket) => socket.destroy());
server.headersTimeout = 10000;
server.requestTimeout = 10000;
server.stop = () => {
  for (const socket of active) socket.destroy();
  return new Promise(resolve => server.close(resolve));
};
return server;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const options = Object.fromEntries(process.argv.slice(2).reduce((pairs, value, index, args) => {
    if (index % 2 === 0) pairs.push([value, args[index + 1]]);
    return pairs;
  }, []));
  const listen = options['--listen'];
  const tokenFile = options['--token-file'];
  if (!listen || !tokenFile) throw new Error('--listen and --token-file are required');
  const token = fs.readFileSync(tokenFile, 'utf8').trim();
  const allowedClients = (options['--allow-client'] || '').split(',').filter(Boolean);
  const server = createProxy({ token, allowedClients });
  server.listen(Number(options['--port'] || 8320), listen);
  const shutdown = () => server.stop().then(() => process.exit(0));
  process.on('SIGTERM', shutdown);
  process.on('SIGINT', shutdown);
}
