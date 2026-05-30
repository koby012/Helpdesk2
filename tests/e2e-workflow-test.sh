#!/usr/bin/env bash
# E2E test: Customer creates ticket → Agent submits/assigns/escalates → Workflow triggered

set -euo pipefail

PW="/c/Users/z004jcbp/AppData/Roaming/npm/playwright-cli"
SUBJECT="E2E Test Ticket - Escalation"

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
$PW fill "#usernameInput" "demo_customer@helpdesk.test"
$PW fill "#passwordInput" "Dem0Customer#2026"
$PW click "#loginButton"
$PW snapshot

echo "Opening New Ticket form..."
$PW click ".mx-name-btnNew"
$PW snapshot

echo "Filling Subject and Description..."
$PW fill ".mx-name-tbSubject input" "${SUBJECT}"
$PW fill ".mx-name-taDescription textarea" "Created by Playwright E2E test for workflow testing."

$PW screenshot
$PW click ".mx-name-btnSave"
$PW snapshot
$PW close
echo "Customer done: ticket created."

# =========================================================
# STEP 2: Agent opens ticket, submits, assigns, escalates
# =========================================================
echo ""
echo "=== Step 2: Agent processes ticket ==="

$PW open http://localhost:8080
$PW fill "#usernameInput" "demo_agent@helpdesk.test"
$PW fill "#passwordInput" "Dem0Agent#2026"
$PW click "#loginButton"
$PW snapshot

echo "Opening ticket via Edit button..."
$PW click "button:has-text('Edit')"
$PW snapshot
$PW screenshot

echo "Submitting ticket (Draft → Open)..."
$PW click ".mx-name-btnSubmit"
$PW snapshot

echo "Clicking Assign Agent..."
$PW click ".mx-name-btnAssignAgent"
$PW snapshot

echo "Clicking Assign on first agent row (Demo Agent)..."
$PW snapshot
$PW eval "document.querySelector('.mx-name-btnAssign').click()"
sleep 2
$PW snapshot
$PW screenshot

echo "Clicking Escalate (Ticket_Detail button)..."
$PW click ".mx-name-btnEscalate"
$PW snapshot

echo "Filling escalation reason..."
$PW fill ".mx-name-taReason textarea" "High priority customer issue requiring manager attention."
$PW screenshot

echo "Submitting escalation (popup Escalate button)..."
$PW eval "document.querySelectorAll('.mx-name-btnEscalate')[1].click()"
sleep 2
$PW snapshot
$PW screenshot
$PW close
echo "Agent done."

# =========================================================
# STEP 3: Verify via OQL
# =========================================================
echo ""
echo "=== Step 3: OQL verification ==="

TICKET=$(./mxcli oql -p Helpdesk2.mpr --json \
  "SELECT Subject, Status FROM HD.Ticket WHERE Subject = '${SUBJECT}'")
echo "Ticket: $TICKET"
echo "$TICKET" | grep -q "InProgress" || (echo "FAIL: Ticket not InProgress" && exit 1)

ESCALATION=$(./mxcli oql -p Helpdesk2.mpr --json \
  "SELECT Reason FROM HD.EscalationRequest")
echo "EscalationRequest: $ESCALATION"
echo "$ESCALATION" | grep -q "High priority" || (echo "FAIL: EscalationRequest not found" && exit 1)

echo ""
echo "PASS: Workflow E2E test completed successfully"
