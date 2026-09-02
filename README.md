# ccpm-update-support

XML 形式の計画ファイルを編集するツール。

利用者のパソコンの中だけで動きます。計画の内容が外部へ送られることはありません。

```
計画ファイル(XML) ──▶ ガントチャート / ネットワーク図 ──▶ 更新 ──▶ 差分を確認 ──▶ 保存
```

**複数のプロジェクトを一度に表示できます。**
並べ方を「担当者別」に変えると、**同じ人の作業が全プロジェクト横断で
1 本の時間軸に並びます** — リソースの調整はここで行います。

> このツールは**資源の取り合いを自動で判定しません。**
> 見えるようにするところまでが役目で、どう動かすかは人が決めます。
> 理由は [`docs/ui/15-multi-project.md`](docs/ui/15-multi-project.md) に書いてあります。

---

## ⚠️ いまの状態

**このリポジトリには、まだ仕様とモックしかありません。**

サーバ側（バックエンド）はすでにあらかた実装されていますが、
**その I/F 仕様がまだ入手できていません。**

そのため、ここに書かれている内容は
**ほぼすべてこちら側の想定（推測）です。**
サーバ側の実物と突き合わせて、順次差し替えていきます。

現在の確定率は `bash scripts/check-spec.sh` で確認できます。

---

## どこから読むか

**初めての方は、上から順に読んでください。**

| 順 | ファイル | 内容 |
|:---:|---|---|
| 1 | [`docs/00-glossary.md`](docs/00-glossary.md) | **用語集。まずここから。** 略語も含めて全部説明しています |
| 2 | [`docs/01-overview.md`](docs/01-overview.md) | 全体像。何をするツールで、どういう構成か |
| 3 | [`docs/ui/10-screens.md`](docs/ui/10-screens.md) | 画面一覧。どんな画面があり、何ができるか |
| 4 | [`docs/interface/21-api.md`](docs/interface/21-api.md) | 画面側とサーバ側のやり取り |
| 5 | [`docs/90-open-questions.md`](docs/90-open-questions.md) | **確認事項の一覧。いま何が未確定か** |

### 目的別

| やりたいこと | 見る場所 |
|---|---|
| 画面のイメージを見たい | [`mock/index.html`](mock/index.html) をブラウザで開く |
| サーバ側に何を確認すべきか知りたい | [`docs/90-open-questions.md`](docs/90-open-questions.md) |
| API の正確な定義が欲しい | [`docs/interface/openapi.yaml`](docs/interface/openapi.yaml) |
| 計画ファイルの構造を知りたい | [`docs/interface/20-data-model.md`](docs/interface/20-data-model.md) |
| タスクが持つ項目を足したい・変えたい | [`docs/interface/24-field-catalog.md`](docs/interface/24-field-catalog.md) |
| 複数プロジェクトとリソース調整を知りたい | [`docs/ui/15-multi-project.md`](docs/ui/15-multi-project.md) |
| エラー時の挙動を知りたい | [`docs/interface/22-errors.md`](docs/interface/22-errors.md) |
| 処理の流れを追いたい | [`docs/interface/23-sequences.md`](docs/interface/23-sequences.md) |

---

## 画面のモックを見る

**ビルドも準備も要りません。** ファイルをブラウザで開くだけです。

```sh
# Windows
start mock\index.html

# macOS
open mock/index.html

# Linux
xdg-open mock/index.html
```

**ガントチャート**と**ネットワーク図**をタブで切り替えて見られます。
変更内容はこの 2 つの画面に重ねて表示されるので、独立したタブはありません。

データは架空のものが埋め込まれています（3 プロジェクト）。
表のセル編集・コピー＆ペースト・接続・並べ方の切り替えまで実際に試せます。

> このモックは**画面の形を確認するためのもの**です。実装ではありません。
> サーバ側とは通信しません。

---

## 仕様をチェックする

```sh
bash scripts/check-spec.sh
```

- 確定度（🟢確定 / 🟡暫定 / 🔴推測）の集計
- 確認事項 ID の整合性
- 書きかけの目印が残っていないか

---

## ディレクトリ構成

```
docs/
  00-glossary.md          用語集（最初に読む）
  01-overview.md          全体像
  90-open-questions.md    確認事項の一覧（社内でこれを持って聞く）
  CHANGELOG.md            仕様の変更履歴
  ui/                     画面仕様
    10-screens.md           画面一覧と操作 ID の索引
    11-gantt.md             ガントチャート画面
    12-network.md           ネットワーク図画面
    13-diff.md              変更内容の見せ方（画面に重ねる）
    14-navigation.md        画面遷移
    15-multi-project.md     複数プロジェクトとリソースの調整
    16-adjust.md            調整パネル（1 人に特化して、試して・決めて・記録する）
  interface/              画面側とサーバ側の境界の仕様
    20-data-model.md        計画ファイルの構造
    21-api.md               API の解説版
    22-errors.md            エラーの扱い
    23-sequences.md         処理の流れ
    24-field-catalog.md     ★ タスクが持つ項目の正（画面はここから作られる）
    openapi.yaml            ★ API の正（機械可読）
    examples/               要求・応答の例
mock/                     触れる画面モック（ビルド不要）
scripts/
  check-spec.sh           仕様の健全性チェック
CLAUDE.md                 仕様を保守するときの規約
```

---

## これから決めること

- **サーバ側の実物との突き合わせ** → [`docs/90-open-questions.md`](docs/90-open-questions.md)
- **画面側の技術スタック** → 未定。仕様が固まってから決めます

画面側の実装コードはまだありません。
仕様とモックで形を固めてから着手します。
