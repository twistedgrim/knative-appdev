const express = require('express');
const path = require('path');

const app = express();
const port = Number(process.env.PORT || 3000);
const frontendDir = path.resolve(__dirname, '../frontend');

app.get('/api/message', (_req, res) => {
  res.json({
    message: 'Hello from the sample backend API',
    timestamp: new Date().toISOString(),
  });
});

app.use(express.static(frontendDir));

app.get('*', (_req, res) => {
  res.sendFile(path.join(frontendDir, 'index.html'));
});

app.listen(port, () => {
  console.log(`sample-webapp listening on ${port}`);
});
