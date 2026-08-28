/**
 * SWF API — roller monitoring, bobbin monitoring, shared SQL Server access.
 */
const express = require('express');
const rollerRoutes = require('./routes/roller');
const componentsRoutes = require('./routes/components');
const bobbinRoutes = require('./routes/bobbin');
const efficiencyRoutes = require('./routes/efficiency');
const dbRegistry = require('./config/dbRegistry');
const database = require('./db/database');

function createApp() {
  const app = express();

  app.use(express.json());

  app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Methods', 'GET,HEAD,OPTIONS,POST,PUT');
    res.header(
      'Access-Control-Allow-Headers',
      'Origin, X-Requested-With, contentType, Content-Type, Accept, Authorization'
    );
    next();
  });

  app.get('/', async (req, res) => {
    const results = await Promise.all(
      dbRegistry.map(async ({ id, label, config }) => {
        const outcome = await database.testConnection(config);
        return {
          id,
          label,
          server: config.server,
          database: config.database,
          connected: outcome.ok,
          latencyMs: outcome.latencyMs,
          ...(outcome.ok ? {} : { error: outcome.error })
        };
      })
    );

    res.json({
      name: 'swf-api',
      description: 'Kiswire SWF API (roller & bobbin monitoring)',
      databaseConnections: results,
      allConnected: results.every((r) => r.connected),
      areas: {
        roller: {
          prefix: '/roller',
          example: 'GET /roller/list',
          updateRuntime: 'POST /roller/updateruntime',
          production: 'GET /roller/sfcwr/list (sfcwrdb on 194.1.31.3)'
        },
        components: {
          prefix: '/components',
          example: 'GET /components/select',
          replace: 'POST /components/replace',
          updateRuntime: 'POST /components/updateruntime',
          updateRuntimeLimit: 'POST /components/updateruntimelimit',
          insert: 'POST /components/insert',
          runtimeWorker: 'GET /components/sfcwr/runtime-worker',
          production: 'GET /components/sfcwr/select (sfcwrdb on 194.1.31.3)'
        },
        bobbin: { prefix: '/bobbin', example: 'GET /bobbin' },
        efficiency: {
          prefix: '/efficiency',
          example: 'GET /efficiency/sfcwr/bundle?dateFrom=2026-08-19&dateTo=2026-08-19&process=DRAWING',
          note: 'Read-only USP_SFC_KPRD060_R10 + USP_SFC_CALL031_R10'
        }
      }
    });
  });

  app.use('/roller', rollerRoutes);
  app.use('/components', componentsRoutes);
  app.use('/bobbin', bobbinRoutes);
  app.use('/efficiency', efficiencyRoutes);

  return app;
}

module.exports = { createApp };
