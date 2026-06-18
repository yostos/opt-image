# test/

`opt-image` の自動テスト（[bats-core](https://github.com/bats-core/bats-core)）。
ケースの意図と一覧は [`../docs/TEST-CASES.md`](../docs/TEST-CASES.md) を参照。

## 実行

```bash
brew install bats-core   # 未導入なら
bats test/               # 全ケール実行
bats test/opt-image.bats # ファイル指定
```

`opt-image`（リポジトリ直下）が未実装のうちは全ケースが **skip** される。
実装が入ると自動的に有効化される（TDD）。

## 実装が満たすべき契約

`opt-image.bats` の冒頭コメントに記載。要点:

- 対象は直下の `opt-image`（bash）。`OPT_IMAGE` 環境変数で上書き可。
- 外部ツールのパスを環境変数で差し替え可能にする
  （`MAGICK` / `CJPEG` / `CWEBP` / `OXIPNG` / `PNGQUANT`）。T-01..03 が依存。
- UC2（webp/png）出力は可逆（`cwebp -lossless` / `oxipng`）。
- バリデーション失敗時は入力を変更する前に非0終了（`.bak`・中間ファイルを作らない）。
- 既定フォーマット jpg、既定リサイズ長辺 1800。

## フィクスチャ

`../fixtures/` を使用。各テストは fixtures を `$BATS_TEST_TMPDIR` に
コピーしてから実行するため、元の fixtures は上書きされない。
