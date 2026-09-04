# 処理の流れ — 画面側とサーバ側のやり取りを時系列で

> 用語は [`../00-glossary.md`](../00-glossary.md) で定義しています。
> API の定義は [`openapi.yaml`](openapi.yaml)、解説は [`21-api.md`](21-api.md)。

## この章の現在の状態

**2026-09-04 にサーバ側の I/F 一覧を受領し、流れ 1 を実物に合わせました。**
保存に関わる流れ（2・3）は、保存 I/F が未実装のため**将来の流れ**として残しています。

---

## 1. 起動して、見て、編集する 🟢（保存は未実装）

```mermaid
sequenceDiagram
    autonumber
    actor U as 利用者
    participant H as ホスト画面<br/>(既存トップ画面)
    participant F as 新 GUI<br/>(/external/)
    participant S as サーバ側

    U->>H: プロジェクトを選ぶ
    H->>F: iframe で開く<br/>/external/?view=gantt&projectIds=17,49
    Note over F: 起動クエリを読む (UI-COMMON-10)

    F->>S: GET /api/v1/health
    S-->>F: 200 { status: ok }
    F->>S: GET /api/v1/meta
    S-->>F: 200 { writeEnabled: false, ... }
    Note over F: writeEnabled=false → 保存は「未実装」表示に (UI-DIFF-09)

    F->>S: GET /api/v1/portfolio?projectIds=17,49
    Note over S: BM3 の XML を解析し JSON に変換
    S-->>F: 200 { revision, projects, tasks, deps, critical, today, errors }

    F->>F: id を変えずに内部状態へ<br/>revision を保持<br/>読み込み時点の状態を控える（差分用）
    alt errors[] が空でない
        F-->>U: 「プロジェクト 99 が読み込めませんでした」の帯 (UI-COMMON-11)
    end
    F-->>U: ガントチャートを表示（today の線）

    Note over U,F: 見る・編集する（通信なし）
    U->>F: 並べ方をリソース別に / 調整パネルで試す / セルを編集
    F->>F: 画面側のメモリ上で変更をためる（画面内ドラフト）

    U->>F: 保存
    F-->>U: 変更内容の一覧 ＋「サーバ側が書き込みに対応するまで保存できません」
```

### この図の要点

- **「ファイルを開く」は無い。** どのプロジェクトを見るかは、ホスト画面からクエリで渡されてくる
- **XML は画面側に来ない。** サーバ側が JSON に変換して返す
- **編集はできるが、保存はできない**（`writeEnabled=false`）。変更は画面内ドラフトで、ブラウザを閉じると消える。
  この事実を利用者に隠さない
- **`today` はサーバ側から来る。** 画面側の時計を使わない
- `revision` は使い道がまだ無いが、**保持しておく**（将来の保存 I/F で使う予定）

---

## 2. 保存が衝突する（`UI-DIFF-06`）🔴 将来の流れ

**保存 I/F が未実装のため、いまは起きません。** 実装されたときのために残しています。
`revision` が `GET /portfolio` の応答に含まれるので、この照合は実現できる見込みです（`Q-005`）。

```mermaid
sequenceDiagram
    autonumber
    actor A as 利用者 A
    actor B as 利用者 B
    participant F as 新 GUI（A の画面）
    participant S as サーバ側

    A->>S: GET /portfolio → revision "bm3-2-..."
    B->>S: （別の画面で）保存 → サーバ側は "bm3-3-..." に
    A->>F: 保存
    F->>S: PUT /plans/bm3-portfolio  If-Match: "bm3-2-..."
    S-->>F: 409 REVISION_CONFLICT { currentRevision: "bm3-3-..." }
    F->>S: GET /portfolio（最新を取り直す）
    S-->>F: 200 revision "bm3-3-..."
    F->>F: 3 つを突き合わせる<br/>（読み込み時点 / A の変更 / 最新）
    F-->>A: 見比べ画面で、A の変更を最新に乗せ直す
```

### 3 つを突き合わせる意味

A の変更を**捨てさせない**ために、「読み込み時点」「A がいま持っているもの」「最新」の 3 つを比べます。
A が触っていない箇所は最新をそのまま採り、触った箇所だけ A の変更を乗せ直します。
両方が同じ箇所を触っていれば、利用者に選ばせます。

---

## 3. 壊れた計画を保存しようとする 🔴 将来の流れ

**保存 I/F が未実装のため、いまは起きません。**

画面側でできる検証（依存の循環）は、接続を作った瞬間に画面側で止めています（`UI-CONNECT-04`）。
サーバ側の検証（`POST /validate`）が実装されたら、保存の直前に呼ぶ位置にします。

---

## 4. サーバ側に繋がらない 🟢

```mermaid
sequenceDiagram
    autonumber
    actor U as 利用者
    participant F as 新 GUI
    participant S as サーバ側

    F->>S: GET /api/v1/health
    S--xF: （応答なし）
    F-->>U: 「サーバ側に接続できません」（画面全体）<br/>＋ ホスト画面へ戻る案内
```

### この図の要点

- 新 GUI はサーバ側から配信されているので、**画面が出ているのに API が返らない**のは
  サーバ側が途中で止まった場合に限られる。起動直後よりも、長時間開いたままのときに起きやすい
- 復帰の基本は**ホスト画面に戻ってやり直す**こと

---

## 5. 調整パネルで試して、適用する（`UI-ADJ-*`）🟢（保存は未実装）

```mermaid
sequenceDiagram
    autonumber
    actor U as 利用者
    participant F as 新 GUI

    Note over U,F: 調整パネルを開く（通信なし）
    U->>F: リソースのまとめ行をダブルクリック
    F->>F: 開いた時点の状態を控える<br/>（「破棄」で戻す先）
    F-->>U: そのリソースの作業をレーンで表示

    Note over U,F: 案を試す（通信なし）
    U->>F: 帯を引きずって着手日を動かす
    F->>F: その帯だけ動かす（後続は動かない）
    U->>F: 別のリソースへ移す
    F-->>U: 「この調整での変更」に 2 件

    alt 破棄
        U->>F: 破棄
        F->>F: 控えた状態へ戻す（何も残らない）
    else 適用
        U->>F: 適用
        F->>F: 変更を計画（画面内ドラフト）に入れる<br/>（元に戻すで 1 回に戻せる）
    end

    Note over U,F: 保存はできない（writeEnabled=false）
```

### この図の要点

- **「適用」は画面内ドラフトへの反映であって、保存ではありません。** いまはその先が無い
- 調整パネルの中はサーバ側と通信しません
- **後続タスクは動きません。** 日程の再計算はサーバ側の役目です（→ `Q-026`）
- 調整メモは計画に入りません。残す場所は未確認です（→ `Q-037`）
