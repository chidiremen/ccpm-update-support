# 主要な処理の流れ

> 用語は [`../00-glossary.md`](../00-glossary.md) で定義しています。

この章は、画面側とサーバ側のやり取りを時系列で示します。
**実装するときは、この図の通りに動くかを確かめてください。**

---

## 1. 開いて、見て、保存する（正常系）

```mermaid
sequenceDiagram
    autonumber
    actor U as 利用者
    participant F as 画面側
    participant S as サーバ側
    participant X as 計画ファイル

    Note over F,S: 起動時
    F->>S: GET /health
    S-->>F: 200 ok
    F->>S: GET /meta
    S-->>F: 200 版と対応機能

    Note over U,X: 計画を開く
    U->>F: ファイルを指定
    F->>S: POST /plans
    S->>X: 読み込む
    X-->>S: XML
    S-->>F: 201 planId, revision "r7", xml

    F->>F: XML を解釈する
    F->>F: 読み込み時の状態を保持<br/>（差分の計算に使う）
    F-->>U: ガントチャートを表示

    Note over U,F: 見る・編集する（通信なし）
    U->>F: ネットワーク図に切り替え
    U->>F: タスクの期間を変更
    F->>F: 画面側のメモリ上で変更をためる

    Note over U,X: 保存する
    U->>F: 保存
    F-->>U: 変更内容の確認画面（6 件）
    U->>F: 内容を確認して確定
    F->>S: POST /plans/{id}/validate
    S-->>F: 200 valid: true
    F->>S: PUT /plans/{id}  If-Match: "r7"
    S->>X: 書き込む
    S-->>F: 200 新しい revision "r8"
    F->>F: revision を "r8" に更新<br/>読み込み時の状態も更新
    F-->>U: 保存できました
```

### この図の要点

- **編集中はサーバ側と通信しません。** 変更は画面側にためておき、保存時にまとめて送ります
- **`revision` は保存のたびに更新します。** 古いまま持っていると、次の保存が必ず衝突します
- **読み込み時の状態も保存後に更新します。** 更新し忘れると、
  次の差分表示に「もう保存済みの変更」が出続けます

---

## 2. 保存が衝突する（`UI-DIFF-06`）

**このツールで最も重要な流れです。** ここを誤ると、利用者の作業が失われます。

```mermaid
sequenceDiagram
    autonumber
    actor U as 利用者 A
    participant F as 画面側
    participant S as サーバ側
    actor B as 利用者 B

    U->>F: 計画を開く
    F->>S: POST /plans
    S-->>F: 201 revision "r7"

    Note over B,S: この間に B が保存する
    B->>S: PUT /plans/{id}  If-Match: "r7"
    S-->>B: 200 revision "r8"

    Note over U,S: A が保存しようとする
    U->>F: 保存
    F->>S: PUT /plans/{id}  If-Match: "r7"
    S-->>F: 409 REVISION_CONFLICT<br/>currentRevision "r8"

    rect rgb(255, 244, 230)
        Note over F,S: 復帰の手順
        F->>S: GET /plans/{id}
        S-->>F: 200 最新の xml, revision "r8"
        F->>F: 3 つを突き合わせる<br/>①A が読んだ時点 ②A の変更 ③最新
        F-->>U: 「他の変更と重なっています」<br/>両方の変更を並べて表示
        U->>F: どちらを採るか選ぶ
    end

    F->>S: PUT /plans/{id}  If-Match: "r8"
    S-->>F: 200 revision "r9"
    F-->>U: 保存できました
```

### この図の要点

> ⛔ **`409` を受け取ったとき、利用者の変更を捨ててはいけません。**

- 必ず**最新を取り直して**から突き合わせます
- 突き合わせるのは **3 つ**です。「自分の変更」と「最新」の 2 つでは、
  **どちらが変更した箇所なのかが分かりません**
- 再試行するときの `If-Match` は、**取り直した新しい版**（`"r8"`）です。
  古い `"r7"` のままだと、また `409` になります

### 3 つを突き合わせる意味

```
①読み込み時   基本設計 12d,  実装 20d
②自分の変更   基本設計 15d,  実装 20d    ← 基本設計だけ変えた
③最新         基本設計 12d,  実装 25d    ← 他人は実装だけ変えた

→ 触れている箇所が重なっていない
→ 両方を活かせる: 基本設計 15d, 実装 25d
```

重なっていなければ**自動で両立できます。**
重なっている場合だけ、利用者に選ばせます。

⚠️ サーバ側が `revision` に対応していない場合、この流れは成立しません（→ `Q-005`）。

---

## 3. 壊れた XML を保存しようとする

```mermaid
sequenceDiagram
    autonumber
    actor U as 利用者
    participant F as 画面側
    participant S as サーバ側

    U->>F: 保存
    F->>F: 画面側でできる検証<br/>（XML の妥当性、循環参照）
    F->>S: POST /plans/{id}/validate
    S-->>F: 200 valid: false<br/>issues: [循環依存 T003→T005→T003]

    F-->>U: エラー 1 件のため保存できません<br/>該当箇所を表示
    Note over F,S: PUT は送りません

    U->>F: 依存関係を直す
    U->>F: 再度保存
    F->>S: POST /plans/{id}/validate
    S-->>F: 200 valid: true, issues: [警告 1 件]
    F-->>U: 警告 1 件あります。保存しますか？
    U->>F: 保存する
    F->>S: PUT /plans/{id}  If-Match: "r7"
    S-->>F: 200 revision "r8"
```

### この図の要点

- **エラーがあれば `PUT` を送りません。** 送っても拒否されるだけで、
  やり取りが無駄になります
- **警告は保存を止めません。** 利用者に判断を委ねます
- 検証の結果に問題があっても、**HTTP は `200`** です。
  「検証できたこと」自体は成功だからです
  （[`22-errors.md`](22-errors.md) 参照）

---

## 4. サーバ側に繋がらない

```mermaid
sequenceDiagram
    autonumber
    actor U as 利用者
    participant F as 画面側
    participant S as サーバ側

    U->>F: 保存
    F->>S: PUT /plans/{id}
    Note over S: 応答なし（起動していない・落ちた）
    S--xF: 通信の失敗

    F->>F: 未保存の変更を保持したまま
    F-->>U: サーバ側に繋がりません<br/>[ 再試行 ]

    Note over U,S: サーバ側が復帰する
    U->>F: 再試行
    F->>S: PUT /plans/{id}  If-Match: "r7"
    S-->>F: 200 revision "r8"
    F-->>U: 保存できました
```

### この図の要点

> ⛔ **通信が失敗しても、未保存の変更は絶対に捨てないでください。**

サーバ側が復帰すれば、そのまま保存できます。
ここで変更を失うと、利用者の作業がすべて無駄になります。

⚠️ サーバ側の起動方法が未確認のため、利用者への案内文は未確定です（→ `Q-002`）。


---

## 5. 調整パネルで試して、適用して、保存する（`UI-ADJ-*`）

```mermaid
sequenceDiagram
    autonumber
    actor U as 利用者
    participant F as 画面側
    participant S as サーバ側

    Note over U,F: 調整パネルを開く（通信なし）
    U->>F: 担当者のまとめ行をダブルクリック
    F->>F: 開いた時点の状態を控える<br/>（「破棄」で戻す先）
    F-->>U: その人の作業をレーンで表示

    Note over U,F: 案を試す（通信なし）
    U->>F: 帯を引きずって着手日を動かす
    F->>F: その帯だけ動かす（後続は動かない）
    U->>F: 別の人へ移す
    F-->>U: 「この調整での変更」に 2 件

    alt 破棄
        U->>F: 破棄
        F->>F: 控えた状態へ戻す（何も残らない）
    else 適用
        U->>F: 適用
        F->>F: 変更を計画に入れる<br/>（元に戻すで 1 回に戻せる）
    end

    Note over U,S: 保存は別の操作（流れ 1 と同じ）
    U->>F: 保存
    F-->>U: 変更内容の確認
    F->>S: PUT /plans/{id}  If-Match
    S-->>F: 200
```

### この図の要点

- **「適用」は計画への反映であって、保存ではありません。** 保存は流れ 1 の通り、
  変更内容を見せてから `PUT` で送ります。段階が 2 つあることを利用者に隠しません
- **調整パネルの中はサーバ側と通信しません。** 試すたびに通信すると、
  「やっぱり無し」が重くなります
- **後続タスクは動きません。** 日程の再計算はサーバ側の役目です（→ `Q-026`）。
  再計算をサーバ側に頼めるようになったら、「適用」の直後に頼むのが自然な位置です
- 調整メモは計画ファイルに入りません。残す場所は未確認です（→ `Q-037`）
