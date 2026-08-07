import http from 'node:http';
import { handle, json } from './game.js';

const PORT = Number(process.env.PORT || 8080);

const server = http.createServer((req, res) => {
  handle(req, res).catch(err => json(res, 500, { error: err.message }));
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`3 Patti server listening on http://0.0.0.0:${PORT}`);
});
