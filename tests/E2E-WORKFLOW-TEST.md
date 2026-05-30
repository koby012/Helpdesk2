# E2E Workflow Test: Ticket Escalation

## 概要

`tests/e2e-workflow-test.sh` は、Customerがチケットを作成してAgentがエスカレーションワークフローを起動するまでの一連のフローをブラウザ自動操作で検証するE2Eテストです。

## 前提条件

| 項目 | 内容 |
|---|---|
| アプリ | http://localhost:8080 で起動中であること |
| playwright-cli | `/c/Users/z004jcbp/AppData/Roaming/npm/playwright-cli` |
| Docker DB | `docker-db-1` コンテナが起動中であること |
| デモデータ | AfterStartup で HD.Customer / HD.Agent が作成済みであること |

起動コマンド:
```bash
./mxcli docker run -p Helpdesk2.mpr --wait
```

## テストフロー

```
Customer ログイン
  └─ New Ticket 作成（Subject / Description 入力）
       └─ Save → Draft で保存

Agent ログイン
  └─ チケット一覧 → Edit ボタンで Ticket_Detail を開く
       └─ [Submit] → Status: Draft → Open（SLA自動設定）
       └─ [Assign Agent] → Agent_Select ポップアップ
            └─ Demo Agent の [Assign] → Status: Open → InProgress
       └─ [Escalate] → EscalationStart_Form ポップアップ
            └─ Reason 入力 → [Escalate] 送信
                 └─ WF_TicketEscalation 起動 → EscalationRequest 作成

OQL 検証
  ├─ Ticket.Status = InProgress を確認
  └─ EscalationRequest.Reason に入力値が存在することを確認
```

## 実行方法

```bash
cd "c:/dev/MxCLI/Handson/Helpdesk2"
bash tests/e2e-workflow-test.sh
```

## 実装上の注意点

テスト作成中に判明したMendix/playwright-cli固有の制約を記録します。

### playwright-cli

| 問題 | 対処 |
|---|---|
| セッションが残ると次回起動時エラー | スクリプト冒頭で `playwright-cli close-all` を実行 |
| 同名ウィジェットが複数ある場合 strict mode violation | `eval "document.querySelector('.mx-name-X').click()"` で最初の要素を指定 |
| ポップアップ背後のボタンと同名ボタンが競合 | `eval "document.querySelectorAll('.mx-name-btnEscalate')[1].click()"` でインデックス指定 |
| `eval` で `await new Promise(...)` は使えない | `sleep N` で代替 |
| COMBOBOX（Mendixカスタムウィジェット）は `select` コマンド非対応 | `eval` でDOMクリックしてから `[role=option]` を選択 |

### MDL / Mendix

| 問題 | 対処 |
|---|---|
| `action: microflow X() close_page` 連鎖構文は未サポート | ラッパーマイクロフロー（ACT_Ticket_AssignAndClose）に `CLOSE PAGE` を内包 |
| `Agent` はMDL予約キーワード | パラメータ名を `SelectedAgent` にリネーム |
| DataGrid2 controlbarボタンで `$currentObject` が microflow引数に使えない (CE0117) | `column (ShowContentAs: customContent)` に actionbutton を入れて `$currentObject` を渡す |
| `RETURNS Ticket AS $Ticket` + `$Ticket = CREATE HD.Ticket()` は二重宣言エラー | CREATE出力変数を別名（例: `$NewTicket`）にする |
| CustomerRole は Status/Priority への書き込み権限なし | チケット作成時は Subject/Description のみ入力可。Submit はAgentが行う |

### OQL

| 制約 | 対処 |
|---|---|
| `mxcli oql` は DELETE 非対応 | `docker exec docker-db-1 psql -U mendix mendix -c "DELETE FROM ..."` で直接削除 |

## テストで使用するユーザー

| ユーザー | パスワード | ロール |
|---|---|---|
| `demo_customer@helpdesk.test` | `Dem0Customer#2026` | Customer |
| `demo_agent@helpdesk.test` | `Dem0Agent#2026` | Agent |

## 関連ファイル

| ファイル | 説明 |
|---|---|
| `tests/e2e-workflow-test.sh` | 本テストスクリプト |
| `tests/verify-ticket-newedit.sh` | Ticket_NewEditページの単体確認テスト |
| `mdlsource/escalation-form.mdl` | EscalationStart_Form実装スクリプト |
| `mdlsource/fix-agent-select.mdl` | Agent_Select修正スクリプト |
| `mdlsource/link-demo-users.mdl` | デモユーザー紐付けスクリプト |
