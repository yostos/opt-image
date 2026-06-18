# opt-image テストケース

最終更新: 2026-06-18

[`USAGE.md`](./USAGE.md) の仕様に対するテストケース一覧。実装後にこの表で
各ケースを検証する。各ケースは独立して実行できるよう、**専用の入力画像を
コピーしてから**走らせる前提（テストが元画像を上書きするため）。

## 凡例

- **前提**: 実行前に満たすべき状態。
- **期待結果**: 終了コード（0=成功 / 非0=失敗）と、ファイル/標準出力の状態。
- 入力サンプルは `fixtures/` に用意済み（`photo.jpg` は実写 `~/Desktop/R0000435.tif`
  を 2400px に縮小、他は `magick` で合成生成）:

| ファイル | 寸法 | 色数 | 用途 |
|---|---|---|---|
| `photo.jpg` | 2400×1600 | 約6万色 | 写真・UC1。>2000px なので `-n`／リサイズ縮小の両方に使える（N-04 の大解像度も兼ねる） |
| `illust.png` | 1200×800 | 215色 | 平坦色＋エッジのイラスト・UC2 |
| `lineart.png` | 1000×1000 | 線画（AAで多色） | 線画・`-c 2` 等の減色入力 |
| `with space.png` | 1200×800 | 215色 | 名前にスペースを含む画像（回帰 R-01） |
| `broken.png` | 30B | — | 不正データ（拡張子だけ PNG）。O-04 / 異常系入力 |

---

## 1. 正常系: UC1 非可逆 JPEG

| ID | 目的 | コマンド | 前提 | 期待結果 |
|---|---|---|---|---|
| N-01 | 既定で JPEG 最適化 | `opt-image -f jpg photo.png` | `photo.png` 存在 | 終了0。`photo.jpg` 生成、長辺 1800 以下、`photo.png.bak` 残存、`photo.png` 削除 |
| N-02 | `-f` 省略時は jpg | `opt-image photo.png` | 同上 | N-01 と同じ（既定フォーマット=jpg） |
| N-03 | リサイズ画素指定 | `opt-image -f jpg -p 1200 photo.jpg` | `photo.jpg` 存在 | 終了0。長辺 1200 以下 |
| N-04 | リサイズしない | `opt-image -f jpg -n photo.jpg` | `photo.jpg`（2400px） | 終了0。解像度が 2400×1600 のまま |
| N-05 | 白署名 | `opt-image -f jpg -s white photo.jpg` | — | 終了0。右下に白文字署名＋ライセンス |
| N-06 | 暗色署名 | `opt-image -f jpg -s dark photo.jpg` | — | 終了0。右下に暗色署名 |

## 2. 正常系: UC2 可逆 WebP / PNG

| ID | 目的 | コマンド | 前提 | 期待結果 |
|---|---|---|---|---|
| N-07 | WebP 減色なし | `opt-image -f webp illust.png` | `illust.png` 存在 | 終了0。`illust.webp` 生成、色数は元のまま（フルカラー可逆） |
| N-08 | WebP 256 色 | `opt-image -f webp -c 256 illust.png` | — | 終了0。色数 ≤256 |
| N-09 | PNG 4096 色 | `opt-image -f png -c 4096 illust.png` | — | 終了0。`illust.png` を 4096 色で再生成。`magick -colors` 経路（pngquant ではない） |
| N-10 | PNG 2 色（線画） | `opt-image -f png -c 2 lineart.png` | — | 終了0。色数 ≤2 |
| N-11 | 全色数の境界値 | `-c 2 / 16 / 125 / 256 / 4096` を順に | — | いずれも終了0 |
| N-12 | リサイズ＋減色＋署名の併用 | `opt-image -f webp -c 256 -p 1000 -s dark illust.png` | — | 終了0。長辺1000・256色・暗色署名がすべて反映 |
| N-13 | 縮小のみ（拡大しない） | `opt-image -f png illust.png` | `illust.png`（1200px） | 終了0。1200px のまま（既定1800 でも拡大されない） |

## 3. 異常系: バリデーション

| ID | 目的 | コマンド | 期待結果 |
|---|---|---|---|
| E-01 | `-c` が許可リスト外 | `opt-image -f png -c 100 illust.png` | 終了非0。色数エラー（許可値を表示）。**元ファイル不変** |
| E-02 | `-c` が非数値 | `opt-image -f png -c abc illust.png` | 終了非0。エラー |
| E-03 | `-c` を JPEG に指定 | `opt-image -f jpg -c 256 photo.jpg` | 終了非0。「jpg では -c 不可」エラー |
| E-04 | 不正なフォーマット | `opt-image -f gif photo.png` | 終了非0。`jpg/webp/png` のみ許可のエラー |
| E-05 | 入力ファイルなし | `opt-image -f jpg nonexistent.png` | 終了非0。File not found |
| E-06 | 引数なし | `opt-image -f jpg` | 終了非0。ヘルプ表示 |
| E-07 | 入力が複数 | `opt-image a.png b.png` | 終了非0。1ファイルのみ受け付けるエラー（仕様確認: 複数対応するなら要更新） |
| E-08 | 未知のオプション | `opt-image -x photo.png` | 終了非0。Invalid option＋ヘルプ |
| E-09 | `-s` の色が不正 | `opt-image -s blue photo.jpg` | 終了非0。`white/dark` のみのエラー |
| E-10 | `-p` が非数値 | `opt-image -p abc photo.jpg` | 終了非0。エラー |

## 4. オプション相互作用

| ID | 目的 | コマンド | 期待結果 |
|---|---|---|---|
| I-01 | `-p` と `-n` 併用 | `opt-image -n -p 1000 photo.jpg` | `-n` 優先（リサイズしない）。仕様どおりかを確認 |
| I-02 | `-h` は他より優先 | `opt-image -h -f jpg` | 終了0。ヘルプのみ表示し処理しない |

## 5. 入出力・副作用

| ID | 目的 | コマンド | 期待結果 |
|---|---|---|---|
| O-01 | バックアップ生成 | `opt-image -f jpg photo.jpg` | `photo.jpg.bak` が処理前の内容で残る |
| O-02 | 拡張子変更時の挙動 | `opt-image -f jpg photo.png` | 元 `photo.png` 削除、`photo.jpg` 生成、`photo.png.bak` 残存 |
| O-03 | 同フォーマット上書き | `opt-image -f jpg photo.jpg` | `photo.jpg` がその場で最適化版に置き換わる |
| O-04 | 処理失敗時に元を壊さない | `opt-image -f jpg broken.png` | 終了非0。元ファイル/バックアップから復元可能、中間一時ファイルは残さない |

## 6. 回帰（旧スクリプトのバグ）

旧 `~/bin/opt-image` で壊れていた箇所が再発しないことを確認する。

| ID | 目的 | コマンド | 期待結果 |
|---|---|---|---|
| R-01 | **スペースを含むファイル名** | `opt-image -f jpg "with space.png"` | 終了0。正しく処理（旧版の `eval` ではクォートが壊れた） |
| R-02 | 署名のシングルクォート/`©` | `-s` 付きで実行 | 終了0。`©`・特殊文字が崩れずに描画される |
| R-03 | `-s dark` 単独指定 | `opt-image -s dark photo.jpg` | 終了0。暗色署名（旧版は `-sd` を getopts で誤解釈し壊れやすかった） |

## 7. 前提ツール

| ID | 目的 | 手順 | 期待結果 |
|---|---|---|---|
| T-01 | `cjpeg`(mozjpeg) 未導入時 | keg パスを外して `-f jpg` 実行 | 終了非0。導入方法（`brew install mozjpeg`）を案内 |
| T-02 | `oxipng` 未導入時 | PATH から外して `-f png` 実行 | 終了非0。導入方法（`brew install oxipng`）を案内 |
| T-03 | `cwebp` 未導入時 | PATH から外して `-f webp` 実行 | 終了非0。導入方法を案内 |

---

## 実行方法（案）

- 当面は**手動チェックリスト**として本表を消化する。
- 自動化する場合は [bats](https://github.com/bats-core/bats-core) を推奨
  （bash スクリプトの振る舞いテストに素直）。`fixtures/` の小サイズ画像を
  使い、各ケースで生成物の有無・終了コード・`magick identify` による
  寸法/色数を検証する。

## 未確定・要確認

- **E-07（複数入力）**: 1ファイル限定のままか、複数ファイル一括対応にするか。
  対応する場合はテスト・仕様とも更新が必要。
- **O-04（失敗時の復元）**: バックアップからの自動ロールバックまで行うか、
  `.bak` を残すだけに留めるか。
- 色数の検証（N-08 等）は減色経路（`magick -colors` / `pngquant`）により
  実際の色数が指定値ぴったりにならない場合がある。許容誤差の扱いを決める。
