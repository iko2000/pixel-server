const express = require('express');
const env = require('dotenv').config().parsed || {};

const app = express();
const port = env.PORT || 3000;

app.get('/', (req, res) => {
  res.send('Hello World!');
});

app.listen(port, () => {
  console.log(`Example app listening at http://localhost:${port}`);
}); 