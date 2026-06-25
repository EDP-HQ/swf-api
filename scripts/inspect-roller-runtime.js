const sql = require('mssql');
const cfg = require('../src/config/sfcwrdb.js');

(async () => {
  const pool = await sql.connect({
    ...cfg,
    options: { ...cfg.options, enableArithAbort: true, trustServerCertificate: true }
  });
  try {
    const names = await pool.request().query(`
      SELECT ROUTINE_NAME
      FROM INFORMATION_SCHEMA.ROUTINES
      WHERE ROUTINE_TYPE = 'PROCEDURE'
        AND (ROUTINE_NAME LIKE '%Roller%' OR ROUTINE_NAME LIKE '%ROLLER%')
      ORDER BY ROUTINE_NAME
    `);
    console.log('Roller SPs:', names.recordset.map((r) => r.ROUTINE_NAME).join('\n'));

    const def = await pool.request().query(`
      SELECT OBJECT_DEFINITION(OBJECT_ID(N'dbo.sp_Roller_Curr_Runtime')) AS def
    `);
    console.log('\n--- sp_Roller_Curr_Runtime ---\n');
    console.log(def.recordset[0]?.def || '(not found)');

    const def2 = await pool.request().query(`
      SELECT OBJECT_DEFINITION(OBJECT_ID(N'dbo.sp_RollerTracker_RecalcRuntime')) AS def
    `);
    console.log('\n--- sp_RollerTracker_RecalcRuntime ---\n');
    console.log(def2.recordset[0]?.def || '(not found)');

    const cols = await pool.request().query(`
      SELECT COLUMN_NAME, DATA_TYPE
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_NAME = 'TB_ROLLER_TRACKER'
      ORDER BY ORDINAL_POSITION
    `);
    console.log('\n--- TB_ROLLER_TRACKER columns ---\n');
    const cols2 = await pool.request().query(`
      SELECT COLUMN_NAME, DATA_TYPE
      FROM INFORMATION_SCHEMA.COLUMNS
      WHERE TABLE_NAME = 'TB_ROLLER_TRACKER_RUNTIME'
      ORDER BY ORDINAL_POSITION
    `);
    console.log('\n--- TB_ROLLER_TRACKER_RUNTIME columns ---\n');
    console.table(cols2.recordset);

    const sampleRt = await pool.request().query(`
      SELECT TOP 3 * FROM dbo.TB_ROLLER_TRACKER_RUNTIME ORDER BY 1 DESC
    `);
    console.log('\n--- TB_ROLLER_TRACKER_RUNTIME sample ---\n');
    console.table(sampleRt.recordset);
  } finally {
    await pool.close();
  }
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
