# ado-skills

オンプレミスの **Azure DevOps Server 2022** を使った開発を、人間が承認点で監督する
ループ（human-on-the-loop）として回すためのエージェントスキル。ループの定義は
[`dev-loop`](.claude/skills/dev-loop/SKILL.md) スキルにあり、各スキルと手順はその段に
仕える。

| スキル | ループでの位置 | 何をするか |
| --- | --- | --- |
| `dev-loop` | ループの定義 | 段・入口条件・成果物・人間の承認点と制御点 |
| `issue-design` | 設計の段 | アイデアを、受け入れ基準まで埋まった作業アイテムに落とす |
| `issue-implement` | 実装の段 | 作業アイテムを実装し、プルリクエストを作る |
| `pr-review` | レビューの段 | プルリクエストをレビューし、優先度付きの指摘を投稿する |
| `pr-fix` | 修正の段 | レビュー指摘に対応し、同じブランチに push する |
| `issue-research` | 支援工程（調査） | コードを変えずに調べ、判断材料を作業アイテムに報告する |
| `issue-plan` | 支援工程（分解） | フィーチャーを、1 本の PR で完結する子ストーリーに分ける |
| `issue-review` | 支援工程（チケットレビュー） | 着手前の作業アイテムを、親・兄弟とまとめてレビューする |
| `azure-devops` | 能力層（段を持たない） | ADO の操作方法。REST クライアントと、ビルド調査の手順 |
| `coding-rules` | ループ外 | プロジェクトのコーディング規約を整備する |
| `output-contract` / `artifact-writing` / `git-conventions` | 共通規約 | 工程スキルが読む出力・成果物・git の規約 |
| `ui-copy` | 共通規約 | 工程スキルが、ユーザーに見える文言の変更を文言規約と照合する手順 |

## 構成

```
.claude/skills/
├── dev-loop/SKILL.md         # ループの定義
├── issue-design/SKILL.md     # 設計: アイデアを作業アイテムに落とす
├── issue-implement/SKILL.md  # 実装: 作業アイテムを実装する
├── pr-review/SKILL.md        # レビュー: プルリクエストをレビューする
├── pr-fix/SKILL.md           # 修正: レビュー指摘に対応する
├── issue-research/SKILL.md   # 調査: 調べて判断材料を報告する
├── issue-plan/SKILL.md       # 分解: フィーチャーを子ストーリーに分ける
├── issue-review/SKILL.md     # チケットレビュー: 着手前の作業アイテムを親・兄弟とまとめて見る
├── azure-devops/             # 能力層。工程スキルがスキル名で引く
│   ├── SKILL.md              # ADO の操作コマンドと、その使い分け
│   ├── scripts/ado.py        # REST クライアント。Python 3 標準ライブラリのみ
│   └── references/
│       ├── recipes.md        # WIQL の書き方、頻出フロー、トラブルシュート
│       └── fields/           # 生成されるフィールド定義（コミットしない）
├── coding-rules/SKILL.md     # 規約の抽出手順と、埋める欄の定義
├── output-contract/          # 出力規約
├── artifact-writing/         # 成果物の記述規約
├── git-conventions/          # ブランチ名とコミットメッセージの規約
└── ui-copy/                  # ユーザーに見える文言の照合手順

scripts/
├── install.sh                # スキルをホームディレクトリに配置する（macOS / Linux）
└── install.ps1               # 同（Windows）

VERSION                       # 書き出した版
```

## このリポジトリについて

このリポジトリの中身は、作者が別に管理しているスキル群から Azure DevOps で使うものだけを
書き出したもの。どの版を書き出したかは `VERSION` にある。

**中身は手で編集しない。** 書き出しのたびに置き換わるため、このリポジトリへの
プルリクエストは取り込まない。直したいことは Issue で知らせる。

OSS ライセンスは付けていない。

工程スキルは、基盤ごとに違う操作を「チケットを読む」「PR を作る」のような操作名で
書いている。Azure DevOps での実行方法は `azure-devops` の `SKILL.md`「工程スキルが引く
操作」が持つ。

## 工程と能力を分ける

スキルの境界は `dev-loop` の段に従う。

| 層 | 置き場所 | 何を書くか |
| --- | --- | --- |
| 工程 | `issue-design` / `issue-implement` / `pr-review` / `pr-fix`、支援工程の `issue-research` / `issue-plan` / `issue-review` | その段の入口条件と手順。段固有の優先度・出力規約・上限 |
| 共通 | `output-contract` / `artifact-writing` | 報告と成果物の書き方。各段はここに固有の上限を足す |
| 共通 | `git-conventions` | ブランチ名とコミットメッセージの規約。対象リポジトリの規約が優先 |
| 共通 | `ui-copy` | ユーザーに見える文言の変更を、リポジトリの文言規約と画面単位で照合する手順 |
| 能力 | `azure-devops` の `SKILL.md` と `scripts/ado.py` | ADO を操作する方法。コマンドと、その使い分け。工程スキルが引く操作の実装 |

工程を語彙に持つのは段スキルの description だけにする。ユーザーの依頼は「設計したい」
「実装に着手」といった工程の言葉で来るので、発火の語彙を工程側に寄せ、`azure-devops` は
ADO の名詞（作業アイテム、PR、WIQL…）だけで発火する能力層に徹する。

工程スキルは能力層をスキル名 `azure-devops` で引く。工程スキルと能力層は同じ skills
ディレクトリに揃えて配置する。一部だけを配置すると、工程スキルから操作が引けずに手順が
途中で止まる。

ループの段に対応しない手順は配布物に含めない。`coding-rules` はループの外だが、
実装の段が読む `CLAUDE.md` を整備する道具としてここに同居している。

## Claude と GitHub Copilot の両方で動く

1 コピーで両対応する。GitHub Copilot はスキルを `.github/skills`、`.claude/skills`、
`.agents/skills` から読み込むため、この構成がそのまま Copilot coding agent・Copilot CLI・
VS Code の agent mode で認識される。Claude Code も同じディレクトリを読む。

そのため `SKILL.md` は道具非依存に書いてある。同梱スクリプトの実行を指示するだけで、
特定ベンダのツール名には一切触れない。

## 導入

### 1. 実行環境に clone する

Azure DevOps Server に到達できる環境（社内の開発マシンなど）に、このリポジトリを clone
する。以下では `~/src/ado-skills` に置いたものとして書く。

```sh
git clone https://github.com/mis-o-ramen/ado-skills.git ~/src/ado-skills
```

新しい版は `git pull` で取り込む。

### 2. スキルをホームディレクトリに配置する

配布物を置いただけでは、そのディレクトリを開いているときしかスキルが発火しない。
実際には別のコードリポジトリで作業しながら使うため、ホームディレクトリ配下に配置する。

付属のスクリプトが `.claude/skills/` 直下のスキルをすべて、ディレクトリ単位の
シンボリックリンクで `~/.claude/skills`・`~/.copilot/skills`・`~/.agents/skills` に張る。`git pull` が
そのまま反映される。

```sh
~/src/ado-skills/scripts/install.sh          # macOS / Linux
```

```powershell
# Windows。シンボリックリンクには開発者モードか管理者権限が要る
powershell -ExecutionPolicy Bypass -File $HOME\src\ado-skills\scripts\install.ps1
```

**新しい版を `git pull` したら、必ずもう一度実行する。**
リンクはスキルごとに張るので、新しいスキルは実行するまで配置されない。エージェントからは
「そんなスキルは無い」に見え、工程の手順を読まずに能力層だけで作業を始める。スクリプトは
何度実行してもよく、この配布物を指したまま切れたリンクは外す。

権限が得られない場合はコピーでもよい。ただし `git pull` のたびにコピーし直す必要があり、
生成済みのフィールド定義はコピー先に置かれるため上書きに注意する。

```powershell
Copy-Item -Recurse -Force "$HOME\src\ado-skills\.claude\skills\*" `
          "$HOME\.claude\skills\"
```

ファイル単位のリンクやコピーにはしない。スクリプトは自身の位置を基準にフィールド定義を
書き出すため、ディレクトリ構造が保たれている必要がある。また、スキルは全部まとめて
同じディレクトリに配置する。工程スキルは能力層 `azure-devops` を兄弟参照する
ため、一部だけ配置すると参照が壊れる。

### 3. 環境変数を設定する

```sh
export ADO_ORG_URL="https://tfs.example.com/tfs/DefaultCollection"
export ADO_PAT="<個人用アクセストークン>"
export ADO_PROJECT="My Project"
export ADO_CA_BUNDLE="/etc/ssl/certs/internal-ca.pem"   # 社内 CA を使っている場合
```

必要な PAT のスコープ: *Work Items (read & write)*、プルリクエストには
*Code (read & write)*、ビルド調査には *Build (read)*。

### 4. 疎通とフィールド定義の生成

```sh
python3 ~/.claude/skills/azure-devops/scripts/ado.py wit types
python3 ~/.claude/skills/azure-devops/scripts/ado.py wit describe-type --type "User Story" --save
```

1 つ目で型の一覧が返れば、URL・PAT・TLS 信頼が通っている。2 つ目でそのサーバの実際の
フィールド定義が `references/fields/` に生成される。扱う型ぶんを実行しておく。

### 5. 実行時ゲートを設定する（推奨、Claude Code のみ）

スキルの規約は散文なので、遵守は確率的になる。取り返しの利かない操作は、実行時に
人間の確認を挟む permission 設定を重ねて決定論的に止める。`~/.claude/settings.json`
（またはプロジェクトの `.claude/settings.json`）に追加する。

```json
{
  "permissions": {
    "ask": [
      "Bash(* ado.py wit create *)",
      "Bash(* ado.py wit set-state *)",
      "Bash(* ado.py pr create *)",
      "Bash(* ado.py request POST *)",
      "Bash(* ado.py request PATCH *)",
      "Bash(* ado.py request PUT *)",
      "Bash(* ado.py request DELETE *)"
    ],
    "deny": [
      "Bash(git push --force*)",
      "Bash(git push -f*)"
    ]
  }
}
```

パターンの書式は Claude Code のバージョンで変わることがある。効いているかは
`/permissions` で確認する。

GitHub Copilot にはコマンド単位の確認機構が無いため、Copilot 実行を守るのは
ツール側の設計（取り消せない操作の非実装、`pr create` の既定ドラフト）と、サーバ側の
ブランチポリシーになる。ターゲットブランチへの直接 push の禁止は、エージェントの
規約ではなくブランチポリシー（PR 必須）で強制する。

### 6. 画面の観点を足す（任意）

`issue-design` と `pr-review` は、画面を作る・変える変更のときに、外部のスキル
[Impeccable](https://github.com/pbakaus/impeccable)（Apache-2.0）の観点を使う。
入っていなければその観点を飛ばすだけで、手順は止まらない。この配布物には同梱しない。

使うなら、Impeccable のリポジトリの配布物を、他のスキルと同じホームディレクトリ配下に
手で置く。エージェントから `impeccable` という名前のスキルが見えればよい。

版は GitHub Actions と同じ `skill-v4.5.0` に揃える。工程スキルは参照ファイルの節の名前を
名指ししているため、版がずれると当てる項目が食い違う。置き直すときは、古いファイルが
残らないよう先に置き場所のディレクトリを消す。

```sh
src="$(mktemp -d)"
git clone --depth 1 --branch skill-v4.5.0 https://github.com/pbakaus/impeccable.git "$src" &&
  rm -rf ~/.copilot/skills/impeccable ~/.claude/skills/impeccable &&
  cp -R "$src/.github/skills/impeccable" ~/.copilot/skills/ &&   # GitHub Copilot
  cp -R "$src/.claude/skills/impeccable" ~/.claude/skills/        # Claude Code
rm -rf "$src"
```

`npx impeccable install` や VS Code 拡張でも入るが、`npx impeccable install` はプロジェクトに
フック（Copilot は `.github/hooks/impeccable.json`、Claude Code は `.claude/settings.local.json`）も
書き込む。フックはファイルを編集するたびに Impeccable のスクリプトを実行し、その結果を
エージェントに渡すので、実装の工程にも作用する。フックを入れないなら手で置く。

工程スキルは Impeccable をスキルとして呼び出さず、参照ファイル（設計は `reference/shape.md`、
レビューは `reference/audit.md` / `audit.native.md`）だけを開く。工程スキルからは Impeccable の
実行ファイルは起動しない。

ただし、手で置いても Impeccable は 1 つのスキルとして見えるので、画面に関わる他の作業
（実装の工程を含む）でエージェントが自分から呼び出すことがある。呼び出されると実行ファイルが
起動し、初回はエンジンを GitHub から取得するため社外に出る。社外に出られない環境では
取得に失敗し、Impeccable は実行ファイルなしの手順で続ける。

## 生成物はコミットしない

`references/fields/` に生成されるファイルには、サーバ URL・プロジェクト名・社内の
プロセステンプレートの定義が含まれる。`.gitignore` で除外済みで、各実行環境のローカルに
置いたままにする。プロセステンプレートを変更した後は再生成する。

## ADO の対応範囲

| 含む | 含まない |
| --- | --- |
| 作業アイテム: WIQL 検索、参照、作成、更新、コメント、フィールドと State の取得 | 添付ファイル、リンク階層、プロセステンプレートの編集 |
| プルリクエスト: 一覧、参照、レビュースレッド、紐づく作業アイテム、コメント、作成 | 完了、破棄、投票、ポリシー上書き |
| ビルド: 定義、実行履歴、状態、失敗ステップのログ | 実行トリガ、変数グループ、承認 |
| その他のエンドポイントは `ado.py request` から | Git 操作 — `git` CLI を使う |

取り消せない操作は意図的に外してある。該当する場面では URL を提示し、人間が判断する。

レビュー時の差分取得も REST では行わない。ADS の REST が返すのは変更ファイルの一覧まで
なので、行単位の差分はローカル clone に対する `git diff` で取る。手順は
`pr-review` スキルを参照。
