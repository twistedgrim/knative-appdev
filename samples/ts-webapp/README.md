# ts-webapp

TypeScript sample app for upload/build/deploy demos.

Stack:
- Frontend: Vite + React + TypeScript + Tailwind CSS + shadcn-style component structure
- Backend: Node.js + Express + TypeScript

## Local run
Terminal 1:
```bash
cd samples/ts-webapp/frontend
npm install
npm run build
```

Terminal 2:
```bash
cd samples/ts-webapp/backend
npm install
npm run build
FRONTEND_DIST=../frontend/dist npm start
```

Open [http://localhost:8080](http://localhost:8080).

## Upload via wrapper
From repo root:
```bash
SAMPLE_DIR=samples/ts-webapp SERVICE_NAME=ts-webapp ./scripts/upload-sample-webapp.sh
```

Then open:
- `http://ts-webapp.demo-apps.localhost:8081`
