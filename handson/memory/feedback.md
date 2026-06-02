---
name: feedback
description: 作業上の指示・好み・避けるべきこと
metadata: 
  node_type: memory
  type: feedback
  originSessionId: cc506b2e-6067-4643-a380-d15b3fd654e5
---

# フィードバック・指示

## CE0463は無理に修正しない

Studio Proの「Update all widgets」で解消する方針。mxcliのdef.json調整では根本解決できない。

**Why:** CE0463はテンプレートバージョン不一致が原因で、mxcli側での完全対応が難しい。Studio Proで一括解消できる。  
**How to apply:** CE0463が発生してもテスト・ビルドのブロッカーとして扱わない。Studio Proで解消できることをユーザーに伝えるだけでよい。

## MDLの内容は直接チャットに表示しない

変更内容は箇条書きの自然言語で説明し、承認後にファイルへ書いて実行する。

**Why:** CLAUDE.mdに明記されたルール。  
**How to apply:** MDLコードを見せる前に「見せますか？」と確認するか、見せずに説明のみにする。

## `mxcli docker down` は使わない

panicするバグがある。代わりに `cd .docker && docker compose down` を使う。

**Why:** mxcliのflagバグ（-v shorthand conflict）でpanicする。  
**How to apply:** Dockerを停止するときは常に `docker compose down` を `.docker/` ディレクトリで実行する。

## DataView内の contentparams の正しい式

MDL の contentparams では**属性名だけ**書く。`$currentObject/` も `toString()` も手動で書かない。
MDLが自動変換する: String/DateTime → `$currentObject/Attr`、Enum → `toString($currentObject/Attr)`

**Why:** 手動で `$currentObject/Subject` と書くと `<unbound>`（CE0402）になる。`toString($currentObject/Status)` と書くと `$currentObject/toString($currentObject/Status)`（CE0117）になる。どちらも二重適用になるため。  
**How to apply:** contentparamsは常に `[{1} = Subject]` `[{1} = Status]` のように属性名だけ書く。MDLが正しい式に変換してくれる。
