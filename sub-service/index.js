const express = require('express');
const env = require('dotenv').config().parsed || {};

const app = express();
const port = env.PORT || 5000;

app.get('/', (req, res) => {
  res.send('This is PORT 5000 running on dock.!');
});

app.listen(port, () => {
  console.log(`Example app listening at http://localhost:${port}`);
}); 