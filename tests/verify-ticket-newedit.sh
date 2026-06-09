#!/usr/bin/env bash
# tests/verify-ticket-newedit.sh
# Verifies that Ticket_NewEdit page renders correctly, saves data, and confirms persistence

set -euo pipefail

PW="${PW:-/c/Users/$USERNAME/AppData/Roaming/npm/playwright-cli}"

echo "Opening browser..."
$PW open http://localhost:8080

echo "Logging in as agent..."
$PW fill "#usernameInput" "demo_agent@helpdesk.test"
$PW fill "#passwordInput" "Dem0Agent#2026"
$PW click "#loginButton"
$PW snapshot

echo "Clicking New Ticket button..."
$PW click ".mx-name-btnNew"

echo "Verifying widgets are present..."
$PW eval "document.querySelector('.mx-name-tbSubject') !== null || (() => { throw new Error('tbSubject not found') })()"
$PW eval "document.querySelector('.mx-name-taDescription') !== null || (() => { throw new Error('taDescription not found') })()"
$PW eval "document.querySelector('.mx-name-cbStatus') !== null || (() => { throw new Error('cbStatus not found') })()"
$PW eval "document.querySelector('.mx-name-cbPriority') !== null || (() => { throw new Error('cbPriority not found') })()"
$PW eval "document.querySelector('.mx-name-dpSLADueAt') !== null || (() => { throw new Error('dpSLADueAt not found') })()"

echo "Filling Subject and Description..."
$PW fill ".mx-name-tbSubject input" "Test Ticket from Playwright"
$PW fill ".mx-name-taDescription textarea" "This is a test description created by automated test."

echo "Setting Status to Open..."
$PW eval "document.querySelector('.mx-name-cbStatus [role=combobox]').click()"
sleep 1
$PW eval "Array.from(document.querySelectorAll('[role=option]')).find(o => o.textContent.trim() === 'Open').click()"
sleep 1

echo "Setting Priority to High..."
$PW eval "document.querySelector('.mx-name-cbPriority [role=combobox]').click()"
sleep 1
$PW eval "Array.from(document.querySelectorAll('[role=option]')).find(o => o.textContent.trim() === 'High').click()"
sleep 1

echo "Setting SLA Due At..."
$PW fill ".mx-name-dpSLADueAt input" "6/30/2026, 12:00 PM"
$PW press "Escape"

echo "Taking screenshot before save..."
$PW screenshot

echo "Clicking Save..."
$PW click ".mx-name-btnSave"
$PW snapshot

echo "Verifying data was saved via OQL..."
RESULT=$(./mxcli oql -p Helpdesk2.mpr --json \
  "SELECT Subject, Status, Priority FROM HD.Ticket WHERE Subject = 'Test Ticket from Playwright' AND Status = 'Open'")
echo "OQL result: $RESULT"
echo "$RESULT" | grep -q "Test Ticket from Playwright" || (echo "FAIL: Ticket not found in database" && exit 1)
echo "$RESULT" | grep -q "Open" || (echo "FAIL: Status not set to Open" && exit 1)
echo "$RESULT" | grep -q "High" || (echo "FAIL: Priority not set to High" && exit 1)

$PW close
echo "PASS: Ticket_NewEdit - form filled, saved, and data confirmed in database"
