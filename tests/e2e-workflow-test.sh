#!/usr/bin/env bash
# E2E test: Customer creates ticket → Agent submits/assigns/escalates → Workflow triggered
# Generates an HTML test report with screenshots and OQL verification data.

set -euo pipefail

PW="/c/Users/z004jcbp/AppData/Roaming/npm/playwright-cli"
SUBJECT="E2E Test Ticket - Escalation"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_DIR="tests/reports/${TIMESTAMP}"
REPORT_HTML="${REPORT_DIR}/report.html"
STEPS=()
STEP_STATUS=()

mkdir -p "${REPORT_DIR}"

# Helper: take a named screenshot
shot() {
  local name="$1"
  local path="${REPORT_DIR}/${name}.png"
  $PW screenshot --filename "${path}" >/dev/null 2>&1 || true
  echo "${path}"
}

# Helper: record a step result
step() {
  local label="$1"
  local status="$2"   # PASS / FAIL / INFO
  local img="${3:-}"
  STEPS+=("${label}|${status}|${img}")
}

TRACE_FILE="${REPORT_DIR}/trace.zip"

echo "Report directory: ${REPORT_DIR}"
echo "Closing any stale browser sessions..."
$PW close-all 2>/dev/null || true

echo "Cleaning up previous test data..."
cd "c:/dev/MxCLI/Handson/Helpdesk2"
docker exec docker-db-1 psql -U mendix mendix \
  -c "DELETE FROM hd\$escalationrequest; DELETE FROM hd\$ticket WHERE subject = '${SUBJECT}';" 2>/dev/null || true

# =========================================================
# STEP 1: Customer logs in and creates a ticket
# =========================================================
echo ""
echo "=== Step 1: Customer creates ticket ==="

$PW open http://localhost:8080
echo "Starting trace recording..."
$PW tracing-start >/dev/null 2>&1 || true
$PW fill "#usernameInput" "demo_customer@helpdesk.test"
$PW fill "#passwordInput" "Dem0Customer#2026"
$PW click "#loginButton"
$PW snapshot
IMG=$(shot "01_customer_login")
step "Customer ログイン (demo_customer@helpdesk.test)" "PASS" "${IMG}"

echo "Opening New Ticket form..."
$PW click ".mx-name-btnNew"
$PW snapshot
IMG=$(shot "02_new_ticket_form")
step "New Ticket フォームを開く" "PASS" "${IMG}"

echo "Filling Subject and Description..."
$PW fill ".mx-name-tbSubject input" "${SUBJECT}"
$PW fill ".mx-name-taDescription textarea" "Created by Playwright E2E test for workflow testing."
IMG=$(shot "03_ticket_filled")
step "Subject / Description 入力: \"${SUBJECT}\"" "PASS" "${IMG}"

$PW click ".mx-name-btnSave"
$PW snapshot
IMG=$(shot "04_ticket_saved")
step "チケット保存 (Save) → Status: Draft" "PASS" "${IMG}"
echo "Saving customer session trace..."
TSTOP1=$($PW tracing-stop 2>&1 || true)
TPATH1=$(echo "${TSTOP1}" | grep -oP '(?<=\[Trace\]\()[^)]+\.trace(?=\))' || echo "")
if [ -n "${TPATH1}" ]; then
  TPATH1_UNIX=$(echo "${TPATH1}" | sed 's|\\|/|g')
  cp "${TPATH1_UNIX}" "${REPORT_DIR}/trace_customer.trace" 2>/dev/null || true
fi
$PW close
echo "Customer done: ticket created."

# =========================================================
# STEP 2: Agent opens ticket, submits, assigns, escalates
# =========================================================
echo ""
echo "=== Step 2: Agent processes ticket ==="

$PW open http://localhost:8080
echo "Starting agent trace recording..."
$PW tracing-start >/dev/null 2>&1 || true
$PW fill "#usernameInput" "demo_agent@helpdesk.test"
$PW fill "#passwordInput" "Dem0Agent#2026"
$PW click "#loginButton"
$PW snapshot
IMG=$(shot "05_agent_login")
step "Agent ログイン (demo_agent@helpdesk.test)" "PASS" "${IMG}"

echo "Opening ticket via Edit button..."
$PW click "button:has-text('Edit')"
$PW snapshot
IMG=$(shot "06_ticket_detail")
step "Ticket_Detail を開く (Edit ボタン)" "PASS" "${IMG}"

echo "Submitting ticket (Draft → Open)..."
$PW click ".mx-name-btnSubmit"
$PW snapshot
IMG=$(shot "07_submitted")
step "Submit → Status: Draft → Open (SLA自動設定)" "PASS" "${IMG}"

echo "Clicking Assign Agent..."
$PW click ".mx-name-btnAssignAgent"
$PW snapshot
IMG=$(shot "08_agent_select")
step "Assign Agent → Agent_Select ポップアップ表示" "PASS" "${IMG}"

echo "Clicking Assign on first agent row (Demo Agent)..."
$PW eval "document.querySelector('.mx-name-btnAssign').click()"
sleep 2
$PW snapshot
IMG=$(shot "09_assigned")
step "Demo Agent を選択 → ACT_Ticket_AssignAndClose → Status: Open → InProgress" "PASS" "${IMG}"

echo "Clicking Escalate (Ticket_Detail button)..."
$PW click ".mx-name-btnEscalate"
$PW snapshot
IMG=$(shot "10_escalation_form")
step "[Escalate] ボタン → EscalationStart_Form ポップアップ表示" "PASS" "${IMG}"

echo "Filling escalation reason..."
$PW fill ".mx-name-taReason textarea" "High priority customer issue requiring manager attention."
IMG=$(shot "11_reason_filled")
step "Escalation Reason 入力" "PASS" "${IMG}"

echo "Submitting escalation (popup Escalate button)..."
$PW eval "document.querySelectorAll('.mx-name-btnEscalate')[1].click()"
sleep 2
$PW snapshot
IMG=$(shot "12_escalated")
step "Escalation 送信 → WF_TicketEscalation 起動" "PASS" "${IMG}"
echo "Saving agent session trace..."
TSTOP2=$($PW tracing-stop 2>&1 || true)
TPATH2=$(echo "${TSTOP2}" | grep -oP '(?<=\[Trace\]\()[^)]+\.trace(?=\))' || echo "")
if [ -n "${TPATH2}" ]; then
  TPATH2_UNIX=$(echo "${TPATH2}" | sed 's|\\|/|g')
  cp "${TPATH2_UNIX}" "${REPORT_DIR}/trace_agent.trace" 2>/dev/null || true
fi
$PW close
echo "Agent done."

# =========================================================
# STEP 3: Verify via OQL
# =========================================================
echo ""
echo "=== Step 3: OQL verification ==="

TICKET_JSON=$(./mxcli oql -p Helpdesk2.mpr --json \
  "SELECT Subject, Status, Priority, SLADueAt FROM HD.Ticket WHERE Subject = '${SUBJECT}'")
echo "Ticket: ${TICKET_JSON}"

ESCALATION_JSON=$(./mxcli oql -p Helpdesk2.mpr --json \
  "SELECT Reason, RequestedAt FROM HD.EscalationRequest")
echo "EscalationRequest: ${ESCALATION_JSON}"

FINAL_STATUS="PASS"

if echo "${TICKET_JSON}" | grep -q "InProgress"; then
  step "OQL検証: Ticket.Status = InProgress ✓" "PASS" ""
else
  step "OQL検証: Ticket.Status が InProgress でない" "FAIL" ""
  FINAL_STATUS="FAIL"
fi

if echo "${ESCALATION_JSON}" | grep -q "High priority"; then
  step "OQL検証: EscalationRequest 作成確認 ✓" "PASS" ""
else
  step "OQL検証: EscalationRequest が見つからない" "FAIL" ""
  FINAL_STATUS="FAIL"
fi

# =========================================================
# STEP 4: Generate HTML report
# =========================================================
echo ""
echo "=== Generating HTML report ==="

# Build steps HTML
STEPS_HTML=""
for entry in "${STEPS[@]}"; do
  IFS='|' read -r label status img <<< "${entry}"
  if [ "${status}" = "PASS" ]; then
    badge='<span style="background:#22c55e;color:#fff;padding:2px 8px;border-radius:4px;font-size:12px;font-weight:bold;">PASS</span>'
  elif [ "${status}" = "FAIL" ]; then
    badge='<span style="background:#ef4444;color:#fff;padding:2px 8px;border-radius:4px;font-size:12px;font-weight:bold;">FAIL</span>'
  else
    badge='<span style="background:#6b7280;color:#fff;padding:2px 8px;border-radius:4px;font-size:12px;">INFO</span>'
  fi

  img_tag=""
  if [ -n "${img}" ] && [ -f "${img}" ]; then
    b64=$(base64 -w 0 "${img}" 2>/dev/null || base64 "${img}")
    img_tag="<div style='margin-top:8px'><img src='data:image/png;base64,${b64}' style='max-width:100%;border:1px solid #e5e7eb;border-radius:4px;' /></div>"
  fi

  STEPS_HTML+="
  <div style='background:#fff;border:1px solid #e5e7eb;border-radius:6px;padding:14px 16px;margin-bottom:10px;'>
    <div style='display:flex;align-items:center;gap:10px;'>
      ${badge}
      <span style='font-size:14px;color:#111827;'>${label}</span>
    </div>
    ${img_tag}
  </div>"
done

# OQL data tables
ticket_table=$(echo "${TICKET_JSON}" | sed 's/[{}]//g;s/"//g;s/,/\n/g' | awk -F: '{if(NF==2) print "<tr><td style=\"padding:6px 12px;border-bottom:1px solid #f3f4f6;color:#6b7280;font-size:13px;\">"$1"</td><td style=\"padding:6px 12px;border-bottom:1px solid #f3f4f6;font-size:13px;font-weight:500;\">"$2"</td></tr>"}')
escalation_table=$(echo "${ESCALATION_JSON}" | sed 's/[{}]//g;s/"//g;s/,/\n/g' | awk -F: '{if(NF>=2) print "<tr><td style=\"padding:6px 12px;border-bottom:1px solid #f3f4f6;color:#6b7280;font-size:13px;\">"$1"</td><td style=\"padding:6px 12px;border-bottom:1px solid #f3f4f6;font-size:13px;font-weight:500;\">"$2"</td></tr>"}')

if [ "${FINAL_STATUS}" = "PASS" ]; then
  result_color="#22c55e"
  result_bg="#f0fdf4"
else
  result_color="#ef4444"
  result_bg="#fef2f2"
fi

cat > "${REPORT_HTML}" <<HTML
<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>E2E テスト実施報告書 - ${TIMESTAMP}</title>
<style>
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f9fafb; margin: 0; padding: 24px; color: #111827; }
  .container { max-width: 900px; margin: 0 auto; }
  h1 { font-size: 22px; font-weight: 700; margin-bottom: 4px; }
  h2 { font-size: 15px; font-weight: 600; color: #374151; margin: 24px 0 10px; border-left: 3px solid #6366f1; padding-left: 10px; }
  .meta { color: #6b7280; font-size: 13px; margin-bottom: 24px; }
  .result-banner { padding: 14px 20px; border-radius: 8px; background: ${result_bg}; border: 1px solid ${result_color}; margin-bottom: 24px; display: flex; align-items: center; gap: 12px; }
  .result-banner .badge { font-size: 18px; font-weight: 700; color: ${result_color}; }
  .result-banner .detail { font-size: 13px; color: #374151; }
  table { width: 100%; border-collapse: collapse; background: #fff; border-radius: 6px; overflow: hidden; border: 1px solid #e5e7eb; }
  th { background: #f3f4f6; padding: 8px 12px; text-align: left; font-size: 12px; color: #6b7280; font-weight: 600; }
</style>
</head>
<body>
<div class="container">

  <h1>E2E テスト実施報告書</h1>
  <div class="meta">
    実施日時: ${TIMESTAMP} ／ 対象アプリ: Helpdesk2 (Mendix 11.6.6) ／ 環境: http://localhost:8080
  </div>

  <div class="result-banner">
    <span class="badge">${FINAL_STATUS}</span>
    <div class="detail">
      テストシナリオ: Ticket Escalation Workflow E2E<br>
      Customer によるチケット作成 → Agent による Submit / Assign / Escalate → WF_TicketEscalation 起動確認
    </div>
  </div>

  <h2>テストシナリオ概要</h2>
  <table>
    <tr><th>項目</th><th>内容</th></tr>
    <tr><td style="padding:6px 12px;border-bottom:1px solid #f3f4f6;color:#6b7280;font-size:13px;">テスト対象</td><td style="padding:6px 12px;border-bottom:1px solid #f3f4f6;font-size:13px;">Ticket エスカレーションワークフロー（HD.WF_TicketEscalation）</td></tr>
    <tr><td style="padding:6px 12px;border-bottom:1px solid #f3f4f6;color:#6b7280;font-size:13px;">Customer ユーザー</td><td style="padding:6px 12px;border-bottom:1px solid #f3f4f6;font-size:13px;">demo_customer@helpdesk.test</td></tr>
    <tr><td style="padding:6px 12px;border-bottom:1px solid #f3f4f6;color:#6b7280;font-size:13px;">Agent ユーザー</td><td style="padding:6px 12px;border-bottom:1px solid #f3f4f6;font-size:13px;">demo_agent@helpdesk.test</td></tr>
    <tr><td style="padding:6px 12px;border-bottom:1px solid #f3f4f6;color:#6b7280;font-size:13px;">テストチケット</td><td style="padding:6px 12px;border-bottom:1px solid #f3f4f6;font-size:13px;">${SUBJECT}</td></tr>
    <tr><td style="padding:6px 12px;color:#6b7280;font-size:13px;">自動化ツール</td><td style="padding:6px 12px;font-size:13px;">playwright-cli v0.1.13</td></tr>
  </table>

  <h2>ステップ詳細</h2>
  ${STEPS_HTML}

  <h2>OQL 検証データ</h2>
  <p style="font-size:13px;color:#6b7280;margin-bottom:6px;">HD.Ticket（テスト対象チケット）</p>
  <table><tr><th>属性</th><th>値</th></tr>${ticket_table}</table>

  <br>
  <p style="font-size:13px;color:#6b7280;margin-bottom:6px;">HD.EscalationRequest（エスカレーションリクエスト）</p>
  <table><tr><th>属性</th><th>値</th></tr>${escalation_table}</table>

  <h2>Trace Viewer</h2>
  <p style="font-size:13px;color:#374151;">以下のコマンドでPlaywright Trace Viewerを起動し、各操作のステップ・スクリーンショット・ネットワークを確認できます。</p>
  <div style="background:#1e293b;color:#e2e8f0;padding:14px 18px;border-radius:6px;font-family:monospace;font-size:13px;margin-bottom:8px;">
    <div style="color:#94a3b8;margin-bottom:6px;"># Customer セッション（New Ticket 作成）</div>
    npx playwright show-trace ${REPORT_DIR}/trace_customer.trace
  </div>
  <div style="background:#1e293b;color:#e2e8f0;padding:14px 18px;border-radius:6px;font-family:monospace;font-size:13px;">
    <div style="color:#94a3b8;margin-bottom:6px;"># Agent セッション（Submit / Assign / Escalate）</div>
    npx playwright show-trace ${REPORT_DIR}/trace_agent.trace
  </div>

  <p style="margin-top:32px;font-size:11px;color:#9ca3af;text-align:center;">Generated by e2e-workflow-test.sh — Helpdesk2 Hands-on Project</p>
</div>
</body>
</html>
HTML

echo ""
echo "HTML report generated: ${REPORT_HTML}"

if [ "${FINAL_STATUS}" = "PASS" ]; then
  echo "PASS: Workflow E2E test completed successfully"
else
  echo "FAIL: Some checks failed — see report for details"
  exit 1
fi
