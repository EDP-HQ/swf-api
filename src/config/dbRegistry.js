/**
 * All SQL Server configs checked on GET /. Add entries when you add new config files.
 */
const localdb = require('./localdb');
const seahq01 = require('./seahq01');
const sfcwrdb = require('./sfcwrdb');

module.exports = [
  { id: 'localdb', label: 'SFC_WR_DB (local)', config: localdb },
  { id: 'sfcwrdb', label: 'SFC_WR_DB (sfcwr / remote)', config: sfcwrdb },
  { id: 'seahq01', label: 'SEAHQ_01_SEC (SEAHQ)', config: seahq01 }
];
