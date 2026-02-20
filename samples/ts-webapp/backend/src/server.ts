import express from "express";
import path from "node:path";

const app = express();
const port = Number(process.env.PORT || 8080);
const frontendDist = process.env.FRONTEND_DIST || path.resolve(process.cwd(), "../frontend/dist");

let counter = 0;

app.get("/api/message", (_req, res) => {
  counter += 1;
  res.json({
    message: "Hello from TypeScript Node backend",
    counter,
    timestamp: new Date().toISOString()
  });
});

app.use(express.static(frontendDist));

app.get("*", (_req, res) => {
  res.sendFile(path.join(frontendDist, "index.html"));
});

app.listen(port, () => {
  console.log(`ts-webapp backend listening on ${port}`);
});
