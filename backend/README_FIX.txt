Vercel fix for 3 Patti backend

Extract these files INSIDE your backend folder so you get:
backend/api/index.js
backend/vercel.json

In Vercel keep Root Directory = backend and Framework Preset = Other.
After pushing to GitHub, redeploy. Test:
https://YOUR-PROJECT.vercel.app/health
Expected: {"ok":true,"rooms":0}
