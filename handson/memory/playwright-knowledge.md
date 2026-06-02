---
name: playwright-knowledge
description: playwright-cli (v0.1.13) をMendixアプリのE2Eテストに使用した際の知見・制約・パターン集
metadata: 
  node_type: memory
  type: reference
  originSessionId: cc506b2e-6067-4643-a380-d15b3fd654e5
---

# playwright-cli × Mendix E2E テスト知見

## 環境

- **バイナリ:** `C:/Users/z004jcbp/AppData/Roaming/npm/playwright-cli`（PATHは未設定）
- **バージョン:** 0.1.13
- **Trace Viewer用:** `npx playwright` (v1.60.0、`npx` 実行時に自動インストール)

---

## コマンドリファレンス（よく使うもの）

```bash
PW="/c/Users/z004jcbp/AppData/Roaming/npm/playwright-cli"

$PW open http://localhost:8080          # ブラウザ起動
$PW close                               # ブラウザを閉じる
$PW close-all                           # 全セッションを閉じる（スクリプト冒頭で実行）
$PW snapshot                            # アクセシビリティツリーを取得
$PW screenshot --filename path.png     # スクリーンショット保存
$PW fill "#selector" "value"           # テキスト入力
$PW click ".mx-name-btnX"              # クリック
$PW eval "JS expression"               # ブラウザ内でJS実行
$PW video-start "path.webm"            # 動画録画開始
$PW video-stop                         # 動画録画停止（戻り値にパスあり）
```

---

## Mendix固有の操作パターン

### ログイン

```bash
$PW open http://localhost:8080
$PW fill "#usernameInput" "demo_agent@helpdesk.test"
$PW fill "#passwordInput" "Dem0Agent#2026"
$PW click "#loginButton"
$PW snapshot   # ページ遷移を待つ
```

ログインページのセレクタ（Mendix全バージョン共通）: `#usernameInput`, `#passwordInput`, `#loginButton`

### ウィジェットのセレクタ

Mendixはウィジェット名をCSS classに `mx-name-{name}` として付与する:

```bash
$PW click ".mx-name-btnNew"          # ボタン
$PW fill ".mx-name-tbSubject input"  # TextBox の input要素
$PW fill ".mx-name-taDescription textarea"  # TextArea
$PW click ".mx-name-btnSubmit"
```

### COMBOBOX（列挙型）の選択

`select` コマンドは Mendix カスタムウィジェットに効かない。`eval` でDOMを操作する:

```bash
# 1. コンボボックスを開く
$PW eval "document.querySelector('.mx-name-cbStatus [role=combobox]').click()"
sleep 1
# 2. オプションをクリック
$PW eval "Array.from(document.querySelectorAll('[role=option]')).find(o => o.textContent.trim() === 'Open').click()"
sleep 1
```

### DataGrid2 の操作

```bash
# 行クリック（選択）
$PW eval "document.querySelector('.mx-name-dgAgents [role=\"row\"]:has([role=\"gridcell\"])').click()"

# 同名ボタンが複数行にある場合（btnAssign など）→ 最初の要素
$PW eval "document.querySelector('.mx-name-btnAssign').click()"
```

### ポップアップ内のボタン（同名ボタンが背面と重複する場合）

```bash
# 背面のボタン（Ticket_Detail の btnEscalate）
$PW click ".mx-name-btnEscalate"

# ポップアップ内のボタン（EscalationStart_Form の btnEscalate）
# → querySelectorAll でインデックス指定
$PW eval "document.querySelectorAll('.mx-name-btnEscalate')[1].click()"
```

### Ticket_Detail を開く（Edit ボタン経由）

```bash
# DataGrid の Edit ボタン → Ticket_Detail が開く
$PW click "button:has-text('Edit')"
```

---

## 制約・落とし穴

| 問題 | 現象 | 対処 |
|---|---|---|
| セッションが残る | 次回起動時に "browser not open" エラー | スクリプト冒頭で `$PW close-all 2>/dev/null \|\| true` |
| `select` が効かない | Mendixのカスタムウィジェット（COMBOBOX等）は `<select>` 非使用 | `eval` でDOMクリック |
| strict mode violation | 同名ウィジェットが複数ある（行ボタンなど） | `eval "document.querySelector('.mx-name-X').click()"` で最初の要素 |
| ポップアップと背面で同名ボタンが競合 | `locator('...')` が複数マッチ | `querySelectorAll(...)[1].click()` でインデックス指定 |
| `eval` で `await new Promise(...)` 不可 | SyntaxError | `sleep N`（bash）で代替 |
| `/p/PageName` の直接URLアクセスが効かない | パラメータ必須ページはホームにリダイレクト | ナビゲーション操作でページを開く |

---

## スクリーンショット保存

```bash
shot() {
  local name="$1"
  local path="${REPORT_DIR}/${name}.png"
  $PW screenshot --filename "${path}" >/dev/null 2>&1 || true  # stdout を捨てる
  echo "${path}"  # IMG=$(shot "name") でパスだけ取得できる
}
IMG=$(shot "01_login")
```

**注意:** `$PW screenshot` の stdout を捨てないと、`IMG=$(shot "...")` にplaywright-cliの出力が混入してパスが壊れる。

---

## 動画録画

```bash
$PW video-start "${REPORT_DIR}/video.webm"
# ... 操作 ...
VSTOP=$($PW video-stop 2>&1 || true)
VPATH=$(echo "${VSTOP}" | grep -oP '(?<=\[Video\]\()[^)]+\.webm(?=\))' | sed 's|\\|/|g')
if [ -n "${VPATH}" ] && [ -f "${VPATH}" ]; then
  cp "${VPATH}" "${REPORT_DIR}/video.webm"
fi
```

- 出力形式: WebM（Chrome/Edge/Firefoxで再生可）
- `video-stop` の出力: `- [Video](./path/to/file.webm)` → パスを抽出してコピー

---

## Trace Viewer について

playwright-cli の `tracing-start/stop` で生成される `.trace` ファイルは、`npx playwright show-trace` が期待するPlaywright Test形式と **非互換**。

- playwright-cli の trace → 独自形式（Trace Viewerで開けない）
- **動画録画（`video-start/stop`）の方が実用的**

---

## HTMLレポート自動生成パターン

```bash
# base64でPNG埋込（HTMLを1ファイルで完結させる）
b64=$(base64 -w 0 "${img_path}")
img_tag="<img src='data:image/png;base64,${b64}' />"

# OQLデータをHTMLテーブルに変換
TICKET=$(./mxcli oql -p App.mpr --json "SELECT Subject, Status FROM HD.Ticket WHERE ...")
```

---

## OQLでのデータ確認・クリーンアップ

```bash
# データ確認
./mxcli oql -p Helpdesk2.mpr --json "SELECT Subject, Status FROM HD.Ticket WHERE Subject = 'xxx'"

# mxcli oql は DELETE 非対応 → docker exec で直接削除
docker exec docker-db-1 psql -U mendix mendix \
  -c "DELETE FROM hd\$ticket WHERE subject = 'xxx';"

# テーブル名: Mendixのモジュール名 + $ + エンティティ名（小文字）
# 例: HD.Ticket → hd$ticket, HD.EscalationRequest → hd$escalationrequest
```
