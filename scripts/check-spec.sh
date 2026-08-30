#!/bin/sh
# 仕様ドキュメントの健全性をチェックする。
#
#   使い方:  bash scripts/check-spec.sh
#
# 何をするか:
#   1. 確定度マーカー(🟢🟡🔴)を集計し、合わせ込みの進み具合を出す
#   2. 本文で参照している Q-xxx が確認事項一覧に定義済みかを照合する
#   3. 書きかけの目印(TBD)が残っていないかを調べる
#
# 依存ライブラリはありません。技術スタックが未定のため、
# Node や Python を必要としない作りにしています。

set -u

DOCS_DIR="docs"
QUESTIONS="docs/90-open-questions.md"
exit_code=0

if [ ! -d "$DOCS_DIR" ]; then
  echo "エラー: $DOCS_DIR がありません。リポジトリの最上位で実行してください。" >&2
  exit 1
fi

echo "======================================================"
echo " 仕様ドキュメントのチェック"
echo "======================================================"
echo

# --- 1. 確定度の集計 ------------------------------------------------
echo "[1] 確定度の集計"
echo

# 凡例や手順の説明で使われているマーカーは数えない。
# それらの行には <!--legend--> を付ける約束にしている
# (Markdown では表示されないため、読み手には見えません)。
count_marker() {
  grep -rh "$1" "$DOCS_DIR" | grep -v '<!--legend-->' | grep -oh "$1" | wc -l | tr -d ' '
}

green=$(count_marker '🟢')
yellow=$(count_marker '🟡')
red=$(count_marker '🔴')
total=$((green + yellow + red))

printf '    🟢 確定  %4d\n' "$green"
printf '    🟡 暫定  %4d\n' "$yellow"
printf '    🔴 推測  %4d\n' "$red"
printf '    ------------\n'
printf '       合計  %4d\n' "$total"
echo

if [ "$total" -gt 0 ]; then
  pct=$((green * 100 / total))
  printf '    確定率: %d%%\n' "$pct"
  if [ "$green" -eq 0 ]; then
    echo "    → まだサーバ側との突き合わせが行われていません。"
    echo "      $QUESTIONS を持って確認を進めてください。"
  fi
fi
echo

# --- 2. 確認事項 ID の整合性 ----------------------------------------
echo "[2] 確認事項 ID (Q-xxx) の整合性"
echo

if [ ! -f "$QUESTIONS" ]; then
  echo "    エラー: $QUESTIONS がありません。" >&2
  exit 1
fi

tmp_defined=$(mktemp)
tmp_referenced=$(mktemp)
trap 'rm -f "$tmp_defined" "$tmp_referenced"' EXIT

# 「## Q-001 ...」という見出しを定義とみなす
grep -oE '^## Q-[0-9]{3}' "$QUESTIONS" | sed 's/^## //' | sort -u > "$tmp_defined"

# 確認事項一覧そのものを除く全ドキュメントからの参照を集める
grep -rhoE 'Q-[0-9]{3}' "$DOCS_DIR" --exclude="$(basename "$QUESTIONS")" \
  | sort -u > "$tmp_referenced"

defined_count=$(wc -l < "$tmp_defined" | tr -d ' ')
printf '    定義済み: %s 件\n' "$defined_count"

# 参照されているが定義がないもの → これは誤りなので失敗させる
undefined=$(comm -13 "$tmp_defined" "$tmp_referenced")
if [ -n "$undefined" ]; then
  echo
  echo "    ✗ 定義のない ID が参照されています:"
  for q in $undefined; do
    echo "        $q"
    grep -rn "$q" "$DOCS_DIR" --exclude="$(basename "$QUESTIONS")" \
      | head -3 | sed 's/^/          /'
  done
  echo
  echo "      → $QUESTIONS に「## $q ...」の見出しを追加してください。"
  exit_code=1
else
  echo "    ✓ 参照されている ID はすべて定義済みです"
fi

# 定義はあるが本文から参照されていないもの → 参考情報にとどめる
unreferenced=$(comm -23 "$tmp_defined" "$tmp_referenced")
if [ -n "$unreferenced" ]; then
  echo
  echo "    ⓘ 本文から参照されていない ID (問題ではありません):"
  for q in $unreferenced; do
    title=$(grep -E "^## $q " "$QUESTIONS" | sed "s/^## $q //")
    echo "        $q  $title"
  done
  echo "      → 単独の確認事項として残す場合はこのままで構いません。"
fi
echo

# --- 3. 項目カタログとモックの一致 ----------------------------------
echo "[3] 項目カタログとモックの一致"
echo

CATALOG="docs/interface/24-field-catalog.md"
MOCK="mock/index.html"

if [ -f "$CATALOG" ] && [ -f "$MOCK" ]; then
  tmp_doc=$(mktemp); tmp_mock=$(mktemp)
  # 設計書の「項目の一覧」の節だけを見る。
  # 属性の説明表にも `key` の形が出てくるため、節で区切らないと拾ってしまう。
  sed -n '/^## 項目の一覧/,/^---$/p' "$CATALOG" \
    | grep -oE '^\| `[a-zA-Z0-9_]+`' | tr -d '|` ' | sort -u > "$tmp_doc"
  # モックの FIELDS から key を拾う
  sed -n '/^const FIELDS = \[/,/^\];/p' "$MOCK" \
    | grep -oE "key:'[a-zA-Z0-9_]+'" | sed "s/key:'//; s/'//" | sort -u > "$tmp_mock"

  d=$(wc -l < "$tmp_doc" | tr -d ' ')
  m=$(wc -l < "$tmp_mock" | tr -d ' ')
  printf '    設計書 %s 件 / モック %s 件\n' "$d" "$m"

  only_doc=$(comm -23 "$tmp_doc" "$tmp_mock")
  only_mock=$(comm -13 "$tmp_doc" "$tmp_mock")
  if [ -n "$only_doc" ] || [ -n "$only_mock" ]; then
    echo
    echo "    ✗ 食い違っています:"
    [ -n "$only_doc" ]  && { echo "      設計書だけにある:"; echo "$only_doc" | sed 's/^/        /'; }
    [ -n "$only_mock" ] && { echo "      モックだけにある:"; echo "$only_mock" | sed 's/^/        /'; }
    echo
    echo "      → 項目を足すときは両方に足してください（$CATALOG が正）"
    exit_code=1
  else
    echo "    ✓ 一致しています"
  fi
  rm -f "$tmp_doc" "$tmp_mock"
else
  echo "    ⓘ 対象のファイルがないため省略しました"
fi
echo

# --- 4. 書きかけの目印 ----------------------------------------------
echo "[4] 書きかけの目印 (TBD)"
echo

tbd=$(grep -rn 'TBD' "$DOCS_DIR" 2>/dev/null)
if [ -n "$tbd" ]; then
  echo "    ⚠ TBD が残っています:"
  echo "$tbd" | sed 's/^/        /'
  echo
  echo "      → 確認事項なら Q-xxx を振って $QUESTIONS に移してください。"
  exit_code=1
else
  echo "    ✓ 残っていません"
fi
echo

# --- まとめ ---------------------------------------------------------
echo "======================================================"
if [ "$exit_code" -eq 0 ]; then
  echo " 問題は見つかりませんでした"
else
  echo " 対応が必要な項目があります（上を確認してください）"
fi
echo "======================================================"

exit "$exit_code"
