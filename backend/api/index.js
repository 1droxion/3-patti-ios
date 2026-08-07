import { handle } from '../game.js';

export default async function handler(req, res) {
  return handle(req, res);
}
