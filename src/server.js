const express = require('express');

const app = express();

app.get('/', (req, res) => {
  res.status(200).send('<h1>Docker Image Optimization Demo</h1>');
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'healthy' });
});

const PORT = process.env.PORT || 3000;

if (require.main === module) {
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
  });
}

module.exports = app;
