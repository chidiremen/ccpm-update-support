# 受領: フロントエンド移管用 I/F 一覧（サーバ側からの実物）

> **この文書は「サーバ側から受け取った事実」だけを書く場所です。**
> こちらの解釈・突き合わせの結果は混ぜません。
> 突き合わせは [`../21-api.md`](../21-api.md) / [`../openapi.yaml`](../openapi.yaml) /
> [`../../90-open-questions.md`](../../90-open-questions.md) の側で行い、結果は
> [`../../CHANGELOG.md`](../../CHANGELOG.md) に残します。

| 項目 | 内容 |
|---|---|
| 受領日 | 2026-09-04 |
| 受け取り方 | 画面の写真（5 枚、1 投目。**2 投目が続く**） |
| 元の文書 | サーバ側リポジトリ `bm3-xml-workbench/docs/frontend-interface-list.md`（ブランチ `release`） |
| 写真の控え | [`2026-09-04-photos/`](2026-09-04-photos/) `batch1-01.jpg` 〜 `batch1-05.jpg`（縮小版） |
| 写し取った範囲 | 元の文書の **1〜159 行目**（`tasks[]` の例の途中まで） |
| 確定度 | 🟢 — サーバ側の文書そのもの。ただし写真からの書き起こしなので、下の「読み取りに自信がない箇所」を参照 |

## 読み取りに自信がない箇所

- 89 行目 `"revision": "bm3-2-..."` — 元の文書でも `...` と省略されているように見える。実際の形式は不明
- 90 行目 `"sourcePath"` — Windows のパス。`\\` の数は写真では確かめられない
- 114 行目 `"color"` の前に色見本の四角が写っているが、これはエディタの表示であって文書の内容ではないと判断した
- 上記以外は判読できた

---

## 書き起こし（1〜159 行目）

````markdown
# フロントエンド移管用 I/F 一覧

## 目的

フロントエンド担当者は、この I/F を織り込めば BM3 XML Workbench の実データを使って UI を作り込める。
画面の見た目、操作感、状態管理はフロント側で自由に変更してよい。ただし、データ取得・保存境界はこの一覧に従う。

## 基本方針

- トップ画面 `/` は既存の進捗会議マトリクスを維持する。
- 新GUIは `/external/` に配置する。
- `/external-host` は新GUIを iframe で開くホスト画面。
- API は同一オリジンの `/api/v1/*` を優先して使う。
- 現時点の新GUI接続は読み込み専用。BM3 XML/BMD への書き込みはまだ行わない。
- 保存ボタンを作る場合も、現時点では画面内ドラフトまたは未実装表示に留める。

## URL I/F

| URL | 用途 | 備考 |
|---|---|---|
| `/` | 既存トップ画面 | 進捗会議マトリクス。維持対象。 |
| `/external/` | 新GUI本体 | 別リポジトリのビルド成果物またはモックを配置する。 |
| `/external-host` | 新GUIホスト | iframeで `/external/` を開く。クエリを引き継ぐ。 |
| `/index.html` | 既存製品群ダッシュボード | 参考/旧画面。 |

### 新GUI起動クエリ

| Query | 型 | 必須 | 意味 |
|---|---|:---:|---|
| `view` | `gantt` / `network` | 任意 | 初期表示タブ。未指定時は `gantt`。 |
| `projectIds` | カンマ区切り文字列 | 推奨 | 表示する BM3 ProjectId。例: `17,49`。未指定で全件取得すると重い。 |
| `teamId` | 文字列 | 任意 | マトリクス側の機能軸選択を引き継ぐ予約項目。現時点の `/api/v1/portfolio` では未使用。 |
| `asOf` | ISO日時文字列 | 任意 | 判定基準日。未指定時はサーバ側の現在時刻または設定値。 |

例:

```text
/external/?view=gantt&projectIds=17,49
/external-host?view=network&projectIds=17,49
```

## API I/F

### GET `/api/v1/health`

疎通確認。

Response:

```json
{
  "status": "ok"
}
```

### GET `/api/v1/meta`

サーバ情報と対応機能を返す。

Response:

```json
{
  "server": "bm3-xml-workbench",
  "version": "0.1.0",
  "capabilities": ["portfolio-mock-read", "bm3-xml-derived-json"],
  "writeEnabled": false
}
```

`writeEnabled=false` の間、フロント側はBM3反映・BMD生成・保存を実行可能にしないこと。

### GET `/api/v1/portfolio`

新GUIが使う主I/F。BM3 XMLの解析結果を、GUIが扱いやすい `projects/tasks/deps` 形式に変換して返す。

Request Query:

| Query | 型 | 必須 | 意味 |
|---|---|:---:|---|
| `projectIds` | カンマ区切り文字列 | 推奨 | 表示対象ProjectId。指定順を保持して返す。 |
| `asOf` | ISO日時文字列 | 任意 | 判定基準日。 |

Response:

```json
{
  "planId": "bm3-portfolio",
  "revision": "bm3-2-...",
  "sourcePath": "C:\\...\\bm3-xml-workbench\\raw",
  "projects": [],
  "tasks": [],
  "deps": [],
  "critical": [],
  "today": "2026-09-04",
  "errors": []
}
```

#### `projects[]`

| Field | 型 | 意味 |
|---|---|---|
| `id` | string | BM3 ProjectId。 |
| `name` | string | BM3プロジェクト名。 |
| `color` | string | 表示用カラー。 |

例:

```json
{
  "id": "17",
  "name": "BEV step3 AMP",
  "color": "#4a7fd0"
}
```

#### `tasks[]`

| Field | 型 | 意味 |
|---|---|---|
| `id` | string | GUI内タスクID。形式は `{ProjectId}:{TaskId}`。 |
| `sourceProjectId` | string | 元BM3 ProjectId。 |
| `sourceTaskId` | string | 元BM3 TaskId。バッファ行では未設定の場合あり。 |
| `sourceBufferId` | string | BM3 MilestoneBuffer由来の行の場合のみ。 |
| `name` | string | タスク名。 |
| `kind` | `task` / `milestone` / `buffer` | 表示種別。 |
| `parentId` | string/null | 親タスクID。親なしは `null`。 |
| `projectId` | string | 所属ProjectId。 |
| `duration` | number | 期間（日）。BM3の分単位値を `MinutesPerDay` で換算。 |
| `start` | string | 開始日 `YYYY-MM-DD`。 |
| `finish` | string | 完了日 `YYYY-MM-DD`。 |
| `progress` | number | 進捗率 0-100。`(duration - remainder) / duration` 由来の暫定値。 |
| `assignees` | string[] | 割当リソース名。BM3 Skill名。複数可。 |
| `wbsCode` | string | BM3 Task Code。 |
| `priority` | string | 暫定表示。Criticalなら `高`、それ以外は `中`。 |
| `phase` | string | 現時点は空。 |
| `note` | string | BM3 Memoまたはバッファ情報。 |
| `createdAt` | string | Project AsOfDate由来。 |
| `updatedAt` | string | Project AsOfDate由来。 |
| `consumed` | number | `kind=buffer` の場合のバッファ消費率。 |
| `protects` | string | `kind=buffer` の場合の保護対象情報。現時点はDependencyId。 |

例:

```json
{
  "id": "17:194",
  "sourceProjectId": "17",
  "sourceTaskId": "194",
  "name": "HILS：マイルストーン集約タスク",
  "kind": "task",
  "parentId": "17:158",
  "projectId": "17",
  "duration": 3,
  "start": "2024-11-20",
  "finish": "2024-11-22",
  "progress": 100,
  "assignees": ["サウンドPAVCT"],
````

（159 行目まで。160 行目以降は 2 投目に続く）
