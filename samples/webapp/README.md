# Sample Web App

Very small demo app with:
- `frontend/`: static HTML/CSS/JS that calls backend API.
- `backend/`: Node/Express server exposing `/api/message` and serving frontend assets.

## Run locally
```bash
cd samples/webapp/backend
npm install
npm start
```

Then open [http://localhost:3000](http://localhost:3000).

## Upload to prototype API
Use `/Users/jamescobb/GitHub/knative-appdev/scripts/upload-sample-webapp.sh`.

This sample includes a `Dockerfile` so it can be built and deployed by the real upload flow.
