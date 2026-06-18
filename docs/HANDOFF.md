# opt-image リライト Handoff

最終更新: 2026-06-18

## このドキュメントの目的

既存の `~/bin/opt-image`（Optimage 依存のシェルスクリプト）を、Optimage に
依存しない形へ作り直すための引き継ぎメモ。次セッションはこのプロジェクト
（`~/ghq/github.com/yostos/opt-image/`）で実装を進める。

## 背景・なぜ作り直すのか

現行 `~/bin/opt-image` は画像最適化を **Optimage.app** に丸投げしている
（`open -a Optimage` でアプリを起動し、吐き出した jpg を拾う方式）。
この Optimage が事実上メンテ停止しており、将来動かなくなる見込み。

調査で判明した事実:

- **個人開発のクローズドソース**プロジェクト（作者: Vlad Danilov、販売は Gumroad）。
  GitHub `vmdanilov/Optimage` は README 1ファイル・1コミットのみの宣伝用リポジトリで、
  ソースも Issue 導線もない。
- **2021年リリース（3.5.x）を最後に更新ゼロ・公の発言ゼロ**。
  公式 Version History もそこで止まっている。
- バイナリは **x86_64 専用**（手元のは 3.5.1 / build 195、min OS 10.9）。
  Apple Silicon ネイティブではなく **Rosetta 2 で動作中**。
- MacUpdate に「M1/M2 非対応、いつ対応？」という要求（2023-12）があるが**作者は無反応**。
- **Rosetta 2 は macOS 28（2027年秋予定）でほぼ廃止**見込み → そこで Optimage は寿命。

→ 復活に賭ける根拠はなく、**Rosetta 廃止前に脱 Optimage する**方針で確定。

### 検討して見送った代替

- **OPTPiX imésta（ウェブテクノロジ社）**: 減色品質は国内最高クラスでゲーム業界の
  デファクトだが、**法人向け価格帯で費用対効果が見合わない**ため見送り。
- 結論: **無料・CLI 完結・macOS arm64 ネイティブ**のツールで組む。

## 要件（用途は2パターン）

### パターン1: 減色 → WebP または PNG
イラスト・スクショ・ロゴなど色数の限られる画像向け。

- 減色（色数の量子化）を行ったうえで **WebP** または **PNG** で出力する。
- 色数は**可変だが選択肢を絞る**: `2, 16, 125, 256, 4096` から選ぶ
  （範囲外はエラー扱いにする想定）。125=5³, 4096=16³。
- 注意: `pngquant` はパレットPNG前提で**上限256色**のため 4096 色は不可。
  256超も統一的に扱うには **`magick -colors N`** を主軸にする。
  （≤256 のときだけ高品質な `pngquant` に切り替える余地は残してよい）

### パターン2: JPEG 最適化
写真・グラデーション主体の画像向け。

- 知覚品質ベースで Optimage に思想が近い **`cjpegli`（jpegli / libjxl 付属）** で最適化。
  - **更新 (2026-06-18)**: `cjpegli` は homebrew で入手不可（`jpeg-xl` には含まれず、
    独立 formula も無い）と判明。同じく知覚最適化された **`mozjpeg`（`cjpeg`）** に変更して確定。
    詳細は [`USAGE.md`](./USAGE.md) を参照。
- リサイズ・署名は現行の `magick` 処理をそのまま流用。

## CLI 設計案（暫定）

出力フォーマットで分岐させる:

```
opt-image -f jpg  img.png    # パターン2（デフォルト）: magick → cjpegli
opt-image -f webp img.png    # パターン1: magick -colors N → cwebp
opt-image -f png  img.png    # パターン1: magick -colors N → oxipng
```

現行から引き継ぐ／追加するオプション:

| オプション | 意味 | 備考 |
|---|---|---|
| `-f <jpg\|webp\|png>` | 出力フォーマット | 新規。既定 `jpg` |
| `-c <色数>` | 減色の色数 | 新規。`2/16/125/256/4096` から選択 |
| `-p <pixels>` | リサイズ画素 | 現行踏襲。既定 1800 |
| `-n` | リサイズしない | 新規（現行はリサイズ必須） |
| `-s` / `-sd` | 署名（白／暗色） | 現行踏襲。`© 2024 ...` 文字列は要更新検討 |
| `-h` | ヘルプ | 現行踏襲 |

## ツール導入状況（2026-06-18 時点、本マシン）

| ツール | 状況 | 用途 |
|---|---|---|
| `magick` (IM 7.1.2, aarch64) | ✅ | リサイズ・署名・減色 |
| `pngquant` | ✅ | ≤256色の高品質減色（任意） |
| `cwebp` | ✅ | WebP 出力 |
| `avifenc` | ✅ | 将来 AVIF 用 |
| `cjpegli` | ❌ 未導入 | **要 `brew install jpeg-xl`** |
| `oxipng` | ❌ 未導入 | **要 `brew install oxipng`** |

いずれも arm64 ネイティブ・無料・Rosetta 非依存。

## 次セッションでやること（TODO）

1. 不足ツールを導入: `brew install jpeg-xl oxipng`
2. CLI 設計案に沿って `opt-image`（新規）を実装
   - パターン2: `magick`(resize+署名) → `cjpegli`
   - パターン1: `magick -colors N` → `cwebp`（webp）／`oxipng`（png）
   - `-c` の値バリデーション（許可リスト外はエラー）
   - `-n`（リサイズなし）追加
3. サンプル画像で各パターンの出力サイズ・画質を確認
4. README 整備、署名文字列（© 年・氏名・ライセンス表記）の見直し
5. 配布: 旧 `~/bin/opt-image` の置き換え方法を決める
   - 旧ファイルは **chezmoi 管理外の野良ファイル**だった点に注意
     （同じ `~/bin` の `aif2flac.sh` は chezmoi 管理下）。
   - 本プロジェクト（git/GitHub: `yostos/opt-image`）で管理する前提に移行。

## 参考リンク

- Optimage 公式 Version History: https://optimage.app/history
- Optimage About（作者・経緯）: https://optimage.app/about
- GitHub `vmdanilov/Optimage`（README のみ）: https://github.com/vmdanilov/Optimage
- Rosetta 2 廃止（macOS 28 / 2027秋）: https://www.macworld.com/article/3063982/apple-ends-rosetta-support-macos-28.html
- OPTPiX（ウェブテクノロジ社）: https://www.webtech.co.jp/products/index.html

## 付録: 現行スクリプトの要点（`~/bin/opt-image`）

- `-p`(既定1800) / `-s`(白署名) / `-sd`(暗色署名) / `-h`
- 処理: バックアップ作成 → `magick -resize WxH` (+署名) → 中間TIFF → Optimage で最適化
  → 出てきた jpg で元ファイルを上書き
- 署名文字列: `© 2024 Toshiyuki Yoshida` / `CC BY-NC-SA 4.0`
- Optimage 依存箇所: `open "$temp_tiff" -W -n -a Optimage --args -exit YES`（これを廃止する）
