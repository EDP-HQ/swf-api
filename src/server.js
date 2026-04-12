const { createApp } = require('./app');

const DEFAULT_PORT = 3200;

function start() {
  const app = createApp();
  const port = process.env.PORT || DEFAULT_PORT;
  const server = app.listen(port, () => {
    console.log('swf-api listening on port', server.address().port);
  });
  return server;
}

module.exports = { start };
