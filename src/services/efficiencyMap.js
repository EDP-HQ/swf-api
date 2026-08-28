/**
 * Live mapping: USP_SFC_KPRD060_R10 + USP_SFC_CALL031_R10 → efficiency UI models.
 * READ-ONLY — does not alter SPs.
 *
 * KPRD060 → ProductionRun
 *   PROD_LC_CD          → bobbin
 *   MACHINE_DESC        → machine
 *   WO_PROCESS_ID DW/ST → DRAWING / STRANDING
 *   START_DT / FINISH_DT→ start / end
 *   MATERIAL_DESC       → matDes
 *   WO_SPEED            → speed (m/s Drawing, RPM Stranding)
 *   WO_LENGTH           → orderLen
 *   PROD_LENGTH         → prodLen
 *   PROD_WT             → prodWt
 *   PROD_TIME (hours)   → actTimeMin (*60)
 *   PROD_TP PLANED|ABNORMAL → nc NORMAL|ABNORMAL
 *   EMP_SNAME           → operator
 *   PITCH               → Stranding PE input
 *   BLOCK_MEMO/REMARKS  → abnormal text
 *
 * CALL031 → MachineCall
 *   CALL_ISSUE_DT       → callTime
 *   CALL_TP_NM / CALL_TP→ reason
 *   CALL_MEMO           → remark
 *   CALL_SETTLE_MEMO    → handleRemark
 *   CALL_EMP_NM         → caller
 *   CALL_ISSUE→SETTLE   → durMin
 *   MACHINE_DESC        → join key to production machine name
 */

function toIso(v) {
  if (v == null || v === '') return null;
  const d = v instanceof Date ? v : new Date(v);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString();
}

function ymdToSpDate(ymd) {
  return String(ymd || '').replace(/-/g, '').slice(0, 8);
}

function processToWoId(process) {
  const p = String(process || '').toUpperCase();
  if (p === 'DRAWING' || p === 'DW') return 'DW';
  if (p === 'STRANDING' || p === 'ST') return 'ST';
  return p;
}

function woIdToProcess(woId) {
  const p = String(woId || '').toUpperCase();
  if (p === 'DW') return 'DRAWING';
  if (p === 'ST') return 'STRANDING';
  return p;
}

function strandTypeFromMachine(name) {
  const n = String(name || '').toUpperCase();
  if (n.includes('BUN')) return 'Bucher';
  return 'Tubular';
}

function mapNc(prodTp) {
  const t = String(prodTp || '').toUpperCase();
  if (t === 'ABNORMAL') return 'ABNORMAL';
  return 'NORMAL';
}

function calcPe({ process, speed, pitch, prodLen, actTimeHr }) {
  const act = Number(actTimeHr) || 0;
  const len = Number(prodLen) || 0;
  const spd = Number(speed) || 0;
  const pit = Number(pitch) || 0;

  let expectedHr = 0;
  if (process === 'DRAWING') {
    if (spd > 0) expectedHr = len / (spd * 3600);
  } else if (process === 'STRANDING') {
    const linear = spd * (pit / 1000) * 60;
    if (linear > 0) expectedHr = len / linear;
  }

  const expMin = expectedHr * 60;
  const actMin = act * 60;
  let pe = 0;
  if (act > 0 && expectedHr > 0) {
    pe = Math.min(100, Math.round((expectedHr / act) * 1000) / 10);
  }
  const procFlag = expectedHr > 0 && act > 0 && act < expectedHr * 0.5;
  return {
    pe,
    expTimeMin: Math.round(expMin * 10) / 10,
    actTimeMin: Math.round(actMin * 10) / 10,
    procFlag
  };
}

function mapProductionRow(row) {
  const process = woIdToProcess(row.WO_PROCESS_ID);
  const machine = row.MACHINE_DESC || '';
  const actTimeHr = Number(row.PROD_TIME) || 0;
  const speed = Number(row.WO_SPEED) || 0;
  const pitch = Number(row.PITCH) || 0;
  const prodLen = Number(row.PROD_LENGTH) || 0;
  const { pe, expTimeMin, actTimeMin, procFlag } = calcPe({
    process,
    speed,
    pitch,
    prodLen,
    actTimeHr
  });

  const nc = mapNc(row.PROD_TP);
  const abnormalParts = [row.BLOCK_MEMO, row.BLOCK_REMARKS].filter((x) => x && String(x).trim());

  return {
    bobbin: String(row.PROD_LC_CD || row.PROD_PL_NO || '').trim() || '—',
    machine,
    process,
    strandType: process === 'STRANDING' ? strandTypeFromMachine(machine) : undefined,
    start: toIso(row.START_DT),
    end: toIso(row.FINISH_DT),
    matDes: row.MATERIAL_DESC || '',
    speed,
    orderLen: Number(row.WO_LENGTH) || 0,
    prodLen,
    prodWt: Number(row.PROD_WT) || 0,
    expTimeMin,
    actTimeMin,
    nc,
    pe,
    operator: row.EMP_SNAME || '',
    abnormal: abnormalParts.length ? abnormalParts.join(' / ') : undefined,
    procFlag: procFlag || undefined,
    machineCd: null,
    woProcessId: row.WO_PROCESS_ID || null,
    prodTp: row.PROD_TP || null,
    pitch
  };
}

function mapCallRow(row) {
  const issue = row.CALL_ISSUE_DT ? new Date(row.CALL_ISSUE_DT) : null;
  const settle = row.CALL_SETTLE_DT ? new Date(row.CALL_SETTLE_DT) : null;
  let durMin;
  if (issue && settle && !Number.isNaN(issue.getTime()) && !Number.isNaN(settle.getTime())) {
    durMin = Math.max(0, Math.round((settle.getTime() - issue.getTime()) / 60000));
  }
  const reason =
    row.CALL_TP_NM ||
    row.CALL_SETTLE_TP_NM2 ||
    (row.CALL_TP ? `Type ${row.CALL_TP}` : 'Call');

  return {
    callTime: toIso(row.CALL_ISSUE_DT),
    settleTime: toIso(row.CALL_SETTLE_DT),
    reason: String(reason),
    remark: row.CALL_MEMO || undefined,
    handleRemark: row.CALL_SETTLE_MEMO || undefined,
    caller: row.CALL_EMP_NM || undefined,
    durMin,
    machine: row.MACHINE_DESC || '',
    machineCd: row.MACHINE_CD || null,
    woProcessId: row.WO_PROCESS_ID || null
  };
}

function attachCallsToRuns(runs, calls) {
  return runs.map((run) => {
    if (!run.start || !run.end) return { ...run, calls: [] };
    const matched = calls.filter(
      (c) =>
        c.machine === run.machine &&
        c.callTime &&
        c.callTime >= run.start &&
        c.callTime <= run.end
    );
    return { ...run, calls: matched };
  });
}

module.exports = {
  ymdToSpDate,
  processToWoId,
  mapProductionRow,
  mapCallRow,
  attachCallsToRuns,
  calcPe
};
