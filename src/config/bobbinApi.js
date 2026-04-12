/**
 * Fixed parameters for USP_SFC_KPRD010_R10. Only LC_CD comes from the HTTP request.
 * Optional env overrides: BOBBIN_API_COMPANY, BOBBIN_API_FACTORY, BOBBIN_API_LANG
 */
module.exports = {
  company: process.env.BOBBIN_API_COMPANY || 'KSB',
  factory: process.env.BOBBIN_API_FACTORY || 'F002',
  lang: process.env.BOBBIN_API_LANG || 'ENG'
};
