#!/usr/bin/env bash
# tests/verify-category.sh
# Verifies that the Category field was added to Ticket_NewEdit and data is persisted

set -euo pipefail

PW="${PW:-/c/Users/$USERNAME/AppData/Roaming/npm/playwright-cli}"

echo "Opening browser..."
$PW open http://localhost:8080

echo "Logging in as agent..."
$PW fill "#usernameInput" "demo_agent@helpdesk.test"
$PW fill "#passwordInput"  "Dem0Agent#2026"
$PW click "#loginButton"
$PW click ".mx-name-btnNew"

echo "Verifying cbCategory widget is present..."
$PW eval "document.querySelector('.mx-name-cbCategory') !== null || (() => { throw new Error('cbCategory not found') })()"

$PW fill ".mx-name-tbSubject input" "Category Test"

echo "Selecting category: ソフトウェア..."
$PW eval "document.querySelector('.mx-name-cbCategory [role=combobox]').click()"
sleep 1
$PW eval "Array.from(document.querySelectorAll('[role=option]')).find(o => o.textContent.trim() === 'ソフトウェア').click()"
sleep 1

# screenshot saves a PNG file to the report directory
$PW screenshot --filename "reports/verify-category-before-save.png" 2>/dev/null || $PW screenshot

$PW click ".mx-name-btnSave"

# snapshot prints DOM/accessibility tree for debugging (not saved as a file)
$PW snapshot

echo "Verifying data was saved via OQL..."
RESULT=$(./mxcli oql -p Helpdesk2.mpr --json \
  "SELECT Subject, Category FROM HD.Ticket WHERE Subject = 'Category Test'")
echo "OQL result: $RESULT"
echo "$RESULT" | grep -q "Software" || (echo "FAIL: Category not saved" && exit 1)

$PW close
echo "PASS: Category field added, option selected, and value persisted in database"
