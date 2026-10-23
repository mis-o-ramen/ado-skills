---
name: azure-devops
description: オンプレミスの Azure DevOps Server 2022 を REST API 経由で操作する能力層。作業アイテム（ユーザーストーリー、フィーチャー、バグ、タスク、PBI）の検索・参照・作成・更新・コメント、受け入れ基準など型ごとに異なるフィールドと State の取得、プルリクエストの参照・スレッド・コメント・作成、PR に紐づく作業アイテムの取得、失敗したビルドパイプラインの調査。ユーザーが作業アイテム、ワークアイテム、ユーザーストーリー、バックログ、スプリント、イテレーション、WIQL、プルリクエスト、PR、ビルド、パイプライン、Azure DevOps、ADO、TFS に言及したときに使う。設計・実装・レビュー・指摘対応・調査・分解・チケットレビューの各工程は兄弟スキル issue-design / issue-implement / pr-review / pr-fix / issue-research / issue-plan / issue-review が持ち、いずれもこのスキルを能力層として使う。Operate a self-hosted Azure DevOps / TFS server; the process stages live in the sibling stage skills (issue-design, issue-implement, pr-review, pr-fix, issue-research, issue-plan, issue-review); read the stage skill first.
---

# Azure DevOps Server（オンプレミス）

**依頼が工程（設計・実装・レビュー・指摘対応・調査・分解・チケットレビュー）なら、先にその工程スキルを読む。** このスキルは
操作の方法だけを持ち、ブランチを切る・テストを先に書く・承認を得てから PR を作る、といった
工程の手順を持たない。工程スキルを読まずに進めると、それらが丸ごと抜けたまま実装が始まる。

| 依頼 | 先に読むスキル |
| --- | --- |
| アイデアを作業アイテムに落とす（設計。「設計したい」「起票したい」） | `issue-design` |
| 作業アイテムを実装する（「〜に着手」「〜を実装して」） | `issue-implement` |
| プルリクエストをレビューする（「レビューして」「PR を見て」） | `pr-review` |
| レビュー指摘に対応する（「指摘に対応して」「スレッドを直して」） | `pr-fix` |
| 調べて報告する（「調べて」「影響範囲を調べて」） | `issue-research` |
| フィーチャーを子ストーリーに分ける（「分解して」「ストーリーに分けて」） | `issue-plan` |
| 着手前の作業アイテムを親・兄弟とまとめてレビューする（「チケットをレビューして」「子チケットを見て」） | `issue-review` |

工程スキルが見当たらないときは、コードにもブランチにも触らずに止まり、スキルが配置されて
いないことを依頼者に伝える（README「導入」の手順で配置し直す）。このスキルだけで工程を
代行しない。

すべての操作は `scripts/ado.py` を通す。この文書のコードブロックで `wit`・`pr`・`build`・
`request` から始まるコマンドは、`python3 <このスキルのディレクトリ>/scripts/ado.py` を前置して
実行する（`python3` がなければ `python`）。パスの基準は次のとおり。

- `scripts/`・`references/` で始まるパス — このスキルのディレクトリからの相対
- `@body.md` のように `@` を付けて渡すファイル — コマンドを実行するカレントディレクトリからの相対

プロジェクトを切り替えるときは、環境変数をコマンドの前に付ける
（bash 系では `ADO_PROJECT=<名前> python3 …/scripts/ado.py wit query …`、PowerShell では
`$env:ADO_PROJECT='<名前>'; python …/scripts/ado.py wit query …`）。`ado.py` の `--project` は
使わない。サブコマンドの前に入るため、実行時の確認設定 (`ado.py wit create` などに一致させる
パターン) をすり抜ける。

Git の操作そのものはスコープ外。clone / diff / branch / commit は `git` CLI を使い、
`scripts/ado.py` が扱うのは REST API でしか取得できないものに限る。ブランチ名と
コミットメッセージの規約は `git-conventions` スキル、開発ループの定義は `dev-loop` スキルに
ある。

## セットアップ

4 つの環境変数で動作する。

| 変数 | 必須 | 内容 |
| --- | --- | --- |
| `ADO_ORG_URL` | 必須 | コレクション URL。例 `https://tfs.example.com/tfs/DefaultCollection` |
| `ADO_PAT` | 必須 | 個人用アクセストークン |
| `ADO_PROJECT` | 実質必須 | 既定のチームプロジェクト（切り替え方は上の「プロジェクトを切り替えるとき」） |
| `ADO_CA_BUNDLE` | 任意 | サーバ証明書が社内 CA 発行の場合の CA バンドルのパス |

`ADO_PROJECT` が無いと、プロジェクト単位の API を使うコマンド（`wit types`・
`wit describe-type`・`wit query`・`wit create`・`wit comments`・`pr` と `build` のすべて、
`--collection-level` を付けない `request`）が失敗する。プロジェクトを持たずに動くのは、ID を
指定する `wit get`・`wit update`・`wit set-state`・`wit comment` と、`--collection-level` を
付けた `request` だけ。

何よりも先に疎通を確認する。

```
wit types
```

作業アイテム型の一覧が返れば、URL・PAT・TLS 信頼のすべてが通っている。返らない場合は
`references/recipes.md` の「トラブルシュート」を見る。

## 最初にフィールドを調べる

作業アイテムのフィールドは型ごと・プロジェクトごとに異なる。「受け入れ基準」は
ユーザーストーリーにはあるがバグやタスクにはない。さらにオンプレミスのプロセステンプレート
は改造されていることが多く、このサーバのフィールド構成が既定の Agile テンプレートと同じとは
限らない。

参照名を推測しない。そのセッションでまだ扱っていない型の作業アイテムを作成・更新する前に、
次の順で確認する。

1. `references/fields/` に `<プロジェクト>.<型>.md` があれば読む。名前は文字・数字以外 (空白や記号) を
   `-` にした小文字 (例 `myproject.user-story.md`)。
2. なければ生成する。
   ```
   wit describe-type --type "User Story" --save
   ```
   表示名・参照名・データ型・必須フラグ・許可値の表と、その型で有効な State の一覧が
   `references/fields/` に書き出される。

この表から 2 つの決まりが導かれる。

- データ型が `html` のフィールド（`System.Description`、
  `Microsoft.VSTS.Common.AcceptanceCriteria`、`Microsoft.VSTS.TCM.ReproSteps`）は、
  素の改行が失われる。`--field-multiline` で書き込む（エスケープして改行を `<br>` に
  変換する）。それ以外の型には `--field` を使う。
- `System.State` はその型に定義された State しか受け付けない。
  `New/Active/Resolved/Closed` だと決めつけない。

`html` 型のフィールドは、読み出すと HTML のまま返る。それを `--field-multiline` に渡すと
二重にエスケープされるため、**読み戻した HTML を編集して書き戻すことはできない**。
`wit update` はフィールドの値を丸ごと置き換えるので、素の文章で書いた全文を渡せば書き換え
られる（「チケットを書き換える」）。補足だけを足すならコメント（`wit comment`）にする。

生成済みのファイルはプロセステンプレートの変更後に古くなる。存在しないフィールドを示す
HTTP 400 で書き込みが失敗したら再生成する。

生成されたファイルはコミットしない（`.gitignore` で除外済み。理由は
`references/fields/README.md`）。

## 作業アイテム

```
wit types                                 # プロジェクトで使える型の一覧
wit describe-type --type "Bug" --save     # フィールド・State・許可値
wit query --wiql "SELECT …"               # WIQL 検索。ID 解決とフィールド取得まで一度に行う
wit get 1234 5678 [--relations]           # ID 指定で全フィールドを取得
wit create --type "User Story" --title …  # 作成
wit update 1234 --assign "…"              # 更新（State 以外のフィールド）
wit set-state 1234 Active                 # State の変更。下の注意を参照
wit comment 1234 --text "…"               # コメントを追加
wit comments 1234                         # ディスカッションを読む
```

`wit set-state` は工程スキルの手順の中では使わない（工程スキルは `System.State` を変えない）。
工程の外で、人間が作業アイテムと変更先の State を明示して指示したときだけ使う。

`wit create` と `wit update` の `--parent <id>` で親子リンクを張る。作業アイテムは親を
1 つしか持てないため、`wit update --parent` は既存の親を同じパッチで外して付け替える
（既にその親なら何もしない）。親子以外のリンク（Related、Duplicate など）は `request` を使う。

`--field`、`--field-multiline`、`--text`、`--description`、`--wiql` は
`@パス` を渡すとファイルから値を読む。長い文章や複数行はシェルのクォートと戦わずにこちらを
使う。

`wit query` は WIQL の `SELECT` 句に書いた列を返す。取得後に絞り込むのではなく `SELECT` を
絞る。大きなバックログに対する広いクエリは出力が膨れる。WIQL の書き方は
`references/recipes.md` を参照。

## プルリクエスト

```
pr list --repo <repo> [--status active] [--target main]
pr get <id> --repo <repo>
pr threads <id> --repo <repo> [--unresolved-only]
pr workitems <id> --repo <repo>           # 紐づく作業アイテムをフィールドごと取得
pr comment <id> --repo <repo> --text "…" [--file path --line N] [--thread N]
pr create --repo <repo> --source <branch> --target <branch> --title "…" [--publish]
```

`pr create` は既定で**ドラフト**として作る。公開はレビュアーへの通知を伴い、ここからは
取り消せないため、`--publish` を付けるのは本文の承認を得たときだけ。作成そのものも
`dev-loop` の承認点で、ドラフトでも承認なしには作らない。

`--thread` は既存スレッドへの返信、`--file`/`--line` は差分の行に紐づく新規スレッド、
どちらも指定しなければトップレベルの新規スレッドになる。ブランチ名の `refs/heads/` は
省略できる。

プルリクエストの完了・破棄、投票、ブランチポリシーの上書きは意図的に実装していない。
エージェント側から取り消せないため、プルリクエストの URL を提示して人間に判断を委ねる。

## ビルド

```
build definitions [--name <フィルタ>]
build list [--definition <id>] [--result failed] [--branch main]
build get <id>
build logs <id> [--fetch] [--tail 200] [--log <logId>]
```

`build logs <id>` 単体で、失敗したステップとそこに記録されたエラーメッセージを一覧する。
原因究明はたいていこれで足りる。メッセージが具体性を欠くときだけ `--fetch` を足すと、
失敗した各ステップのログ末尾 `--tail` 行を取得する。ログ全体は巨大なので、`--tail 0` を
渡すのではなく `--tail` を段階的に増やす。

ビルドの実行トリガはスコープ外。

## 工程スキルが引く操作

工程スキル (`issue-design`・`issue-implement`・`pr-review`・`pr-fix`・`issue-research`・
`issue-plan`・`issue-review`) はすべて GitHub と共用で、基盤ごとに違う操作を「チケットを読む」のような操作名で書いている。この節がその Azure DevOps での実行方法。
工程スキルの「チケット」は作業アイテムを指す。「受け入れ条件」の置き場は型で違うので、
「チケットを読む」の順で探す。この節の
どの操作も `System.State` を変えない。

保守者向けの注記: 操作名の一覧と契約は中央リポジトリ ai-workflows の `docs/platform-ops.md`
にあり、この節はそれを実装する。配布物には含まれないので、作業中に探さない。

### チケットを読む

```
wit get <id> --relations
wit comments <id>
```

受け入れ条件がどのフィールドにあるかは型で決まる。参照名を推測せず「最初にフィールドを
調べる」の手順で確認し、次の順で探す。

1. 受け入れ基準のフィールド (ユーザーストーリーなら `Microsoft.VSTS.Common.AcceptanceCriteria`)
2. その型に受け入れ基準のフィールドが無ければ、本文のフィールドの末尾の「受け入れ条件」の
   見出しの下。バグなら `Microsoft.VSTS.TCM.ReproSteps`、それ以外の型なら `System.Description`

### 親チケットを読む

`wit get <id> --relations` の `relations` のうち `System.LinkTypes.Hierarchy-Reverse` が
親。その ID を `wit get` で読む。無ければ親は無い。

### 子チケットを一覧する

```
wit get <親id> --relations
wit get <子id> <子id> … --relations
```

親の `relations` のうち `System.LinkTypes.Hierarchy-Forward` が子。子の ID をまとめて
`wit get` で読む。子の `relations` に `rel` が `ArtifactLink` で `name` が
`Pull Request` のものがあれば、紐づく PR があり着手済み。

### チケットを探す

```
wit query --wiql "SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.TeamProject] = @project AND ([System.Title] CONTAINS '<キーワード>' OR [System.Description] CONTAINS WORDS '<キーワード>')"
```

タイトルと本文 (`System.Description`) の両方から探す。閉じた作業アイテムも State で絞らずに
含める。WIQL の書き方は `references/recipes.md`。

`CONTAINS WORDS` はサーバの全文検索を使うため、サーバの設定によってはエラーになる。エラーに
なったら、タイトルだけで探す次のクエリで探し直す。そのときは、本文を探せていないことを
報告に 1 行で書く。

```
wit query --wiql "SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.TeamProject] = @project AND [System.Title] CONTAINS '<キーワード>'"
```

`CONTAINS WORDS` は本文を単語単位で照合する (部分一致ではない)。語の一部では当たらない。

### チケットを起票する

型は機能ならユーザーストーリー (プロセスによっては PBI)、バグならバグ。書く前に
「最初にフィールドを調べる」でその型のフィールドを確認する。設計の工程の要素は次に置く。

- タイトル → `--title`
- 背景・目的、スコープ外、設計判断 → `System.Description` (`--field-multiline System.Description=@…`)
- 受け入れ条件 → 受け入れ基準のフィールド (ユーザーストーリーなら
  `Microsoft.VSTS.Common.AcceptanceCriteria`)。`--field-multiline` で 1 件 1 行に書く

```
wit create --type "User Story" --title "…" \
  --field-multiline System.Description=@body.md \
  --field-multiline Microsoft.VSTS.Common.AcceptanceCriteria=@criteria.md
```

バグは要素の置き場が違う。

- 期待する動作・実際の動作・再現手順 → `Microsoft.VSTS.TCM.ReproSteps`。要素ごとに見出しを
  分けて書く
- 受け入れ条件 → バグに受け入れ基準のフィールドがあればそこ。無ければ
  `Microsoft.VSTS.TCM.ReproSteps` の末尾に「受け入れ条件」の見出しを置き、その下に 1 件 1 行で
  書く。工程スキルの「バグの再現手順は別の見出しに書く」は、同じフィールドの中で「再現手順」と
  「受け入れ条件」の見出しを分けることで満たす

起点の作業アイテムがあるとき、起点の型が起票する型と同じなら、新しく起票せずに起点を
「チケットを書き換える」で書き換える。型が違えば (起点がアイデアや課題を置く型で、
ユーザーストーリーにしたい、など) `wit update` では型を変えられないので、新しく起票して、
起点に `wit comment` で起票した ID と URL を 1 行ずつ残す。

起票後に本文を直すときも「チケットを書き換える」で全文を置き換える。

### 親チケットを起票する

フィーチャーにする。子への分解は分解の工程 (`issue-plan`) が行う。背景・目的・成果・
スコープ外・設計判断をすべて `System.Description` に書き、成果は「成果」の見出しの下に番号付きで
1 件 1 行にする。分解とチケットレビューはこの番号で指す。受け入れ基準のフィールドは空のままに
する。受け入れ条件があるかで工程を決める読み手 (設計・実装・チケットレビュー) が、親を
受け入れ条件の埋まったチケットと読み違えないため。

```
wit create --type "Feature" --title "…" \
  --field-multiline System.Description=@parent.md
```

### 子チケットを起票する

親フィーチャーの下にユーザーストーリーを `--parent <親id>` でぶら下げる。骨組みの要素
(背景・成果・作業内容・スコープ外・依存) はすべて `System.Description` に置き、受け入れ基準の
フィールドは空のままにする。受け入れ条件は、着手の前に設計の工程が詳細化して「チケットを
書き換える」で受け入れ基準のフィールドに書く。依存は `依存: #<id>` の 1 行で書く。

```
wit create --type "User Story" --title "…" --parent <親id> \
  --field-multiline System.Description=@body.md
```

起票後に本文を直すときは「チケットを書き換える」で全文を置き換える。

### チケットを書き換える

`html` 型のフィールドは読み戻した HTML を編集して書き戻せない (「最初にフィールドを
調べる」) ので、読んだ本文を編集せず、工程スキルが渡した全文で置き換える。`wit update` は
渡したフィールドの値を丸ごと置き換え、渡さなかったフィールドには触らない。

```
wit update <id> --field-multiline System.Description=@body.md \
  --field-multiline Microsoft.VSTS.Common.AcceptanceCriteria=@criteria.md
```

受け入れ条件のフィールドの参照名は型で決まる (「チケットを読む」)。受け入れ条件を本文の
フィールドの末尾に置いている型では、そのフィールドの全文に受け入れ条件の見出しまで含めて
渡す。タイトルも変わるなら
`--title` を付ける。置き換えた後、`wit comment` で何を変えたかを 1 行残す。フィールドの
履歴は残るが、差分が読みにくい。

### チケットにコメントする

```
wit comment <id> --text @comment.md
```

プレーンテキストとして入る。記号はエスケープされ、表は崩れ、折りたたみは使えない。改行は
`<br>` に変わるので行は保たれる。項目は行単位で書き、行の中は記号で区切る。

既定では、作業アイテム側に長文を置かず、詳細はプルリクエストに置いて、作業アイテムには
リンクと結論だけを書く。ただし下の「後の工程が引く記録」は除く。

工程スキルが「折りたたみに畳む」とした部分は、次のとおりに扱う。

- 既定では根拠を省く。省いたことを 1 行で書く
- 後の工程が引く記録は省かない。チケットレビューの報告、設計の検討記録 (自分で決めたことを
  含む)、分解の前提の出どころ、チケットレビューへの対応の記録がそれにあたる。折りたたみの
  代わりに、要素ごとのまとまりを保ったまま記号で区切って書く

### PR を作る

```
pr create --repo <repo> --source <ソース> --target <ターゲット> \
  --title "…" --description @body.md --work-item <id> --publish
```

`--work-item` が作業アイテムへの紐づけ。レビューの段は `pr workitems` でここから
受け入れ基準を読むので、省かない。`--publish` を付けるのは本文の承認を得たときだけ
(「プルリクエスト」の節)。PR テンプレートは `.azuredevops/pull_request_template.md`、
無ければ `.github/pull_request_template.md`。

### PR を読む

```
pr get <id> --repo <repo>
```

`sourceRefName` がソースブランチ、`targetRefName` がターゲットブランチ。どちらも
`refs/heads/` を外して使う。`lastMergeSourceCommit` がソース側の最新コミット。

### 紐づくチケットを読む

```
pr workitems <id> --repo <repo>
```

紐づく作業アイテムがフィールドごと返る。受け入れ条件は「チケットを読む」と同じ順で
探す (参照名を推測しない)。コメントは `wit comments <id>` で読む。空の配列なら
紐づきは無い。

### PR の指摘を読む

```
pr threads <id> --repo <repo>
```

差分の行に付いたスレッドとトップレベルのスレッドが、解決状態付きで返る。
`--unresolved-only` で未解決だけに絞れるが、解決済みのスレッドに人間の判断が残って
いることがあるので、対応方針に迷ったら絞らずに読む。

### PR にコメントする

```
pr comment <id> --repo <repo> --text @report.md
```

トップレベルの新規スレッドとして入る。Markdown が効き、表・箇条書きを使える。
スレッドを解決済みにしない。既存の指摘への応答はここではなく「PR の指摘に返信する」で
書く。

### PR の行にコメントする

```
pr comment <id> --repo <repo> --file <パス> --line <N> --text @finding.md
```

差分の行に紐づく新規スレッドになる。`--line` は変更後のファイルの行番号。

### PR の指摘に返信する

```
pr comment <id> --repo <repo> --thread <threadId> --text @reply.md
```

`<threadId>` は「PR の指摘を読む」が返す `threadId`。差分の行のスレッドにも、トップレベルの
スレッドにも同じ形で返信できる。`--thread` を付けずに投稿すると、指摘から切り離された
新規スレッドになる。返信してもスレッドの状態は変わらない。解決済みにしない。

## 工程の作業はこのスキルでは進めない

開発ループの段にあたる依頼は、冒頭の表の工程スキル（同じ skills ディレクトリ直下）に
手順がある。

段の定義と、どの段にいるかの判定は `dev-loop` スキルにある。

報告の書き方は `output-contract` スキルに共通で置いてある。
各手順はそこに固有の上限を足す。投稿先ごとの書式の制約は、上の「チケットにコメントする」
「PR にコメントする」にある。

## それ以外の操作

`scripts/ado.py request <METHOD> <パス>` で任意のエンドポイントを直接呼べる。認証・
コレクション URL・TLS・`api-version` は処理済み。

```
request GET /wit/workitems/1234 --query '$expand=relations'
request POST /wit/wiql --data @query.json
```

パスは `_apis` からの相対。`--collection-level` でプロジェクト部分を外し、
プレビュー版が必要なルートには `--api-version-override` を使う。

GET 以外の `request` は、実装済みコマンドが意図的に外している操作にも到達できる。到達
できることは許可ではない。プルリクエストの完了・破棄・投票と、指摘スレッドの解決済み化は、
承認を求めてでも代行しない（`dev-loop`「人間が握る制御点」）。URL を提示して
人間が行う。それ以外の書き込みの `request` は、目的の操作を示して人間の承認を得てから使う。

## 参照

- `references/recipes.md` — WIQL の書き方、頻出フロー、トラブルシュート
- `references/fields/` — 生成されたプロジェクト×型ごとのフィールド定義
