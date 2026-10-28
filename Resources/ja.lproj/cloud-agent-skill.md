# hmux Cloud スキル

`hmux` CLI を使ってユーザーの Cloud マシンで作業します。このファイルは
アプリが生成するため編集しないでください。記載と実装が異なる場合は
`hmux vm <subcommand> --help` を優先します。

## 基本モデル

- マシンはサインイン中のユーザーが所有する永続 Cloud VM です。生成された名前が操作時のアドレスです。`vm rename` は表示ラベルだけを変更します。
- ターミナルとスクロールバックはマシン上のセッションが保持します。ペインやノートパソコンを閉じてもマシンとプロセスは存続します。
- 管理対象セッションはプライベートな hmux-remote 接続を使います。利用できる操作は応答の `capabilities` で確認し、プロバイダー名から推測しません。
- イメージはバックエンドが選択します。デスクトップや独立した永続ホームボリュームがあるとは限りません。SSH に対応しないマシンもあります。
- Base はユーザーごとに一つの永続スロットです。`vm base` は同じマシンを再度開き、`vm new` は新しいマシンを作成します。
- 一台のマシンに複数のワークスペースを作成できます。タスクごとにマシンを増やすより、マシン内のワークスペースを分けてください。
- ワークスペースは `ws_…`、ターミナルは `term_…` の ID を使います。ワークスペース名は一意の場合のみ使用できます。同名がある場合は ID が必要です。
- `agent-pool` マシンはルーターが管理し再利用します。ユーザーが手動で作成したマシンを勝手にルーターへ取り込みません。
- 台数・メモリ・無料アクセス期間の制限は `vm ls` の現在の応答から確認します。

## 一覧と状態

```bash
hmux vm ls
hmux vm status <id>
hmux vm stats <id>
hmux vm ports <id>
hmux vm tools <id>
hmux vm tree [<machine>|local] [--refresh]
```

## 作成と名前

```bash
hmux vm new [--base] [--size <4g|8g|16g|24g|32g|64g>] [--detach|-d]
hmux vm rename <id> <new-label>
hmux vm base
hmux vm base reset [--reason <text>]
```

`vm new` は位置引数を受け付けません。タイプミスで有料マシンを作成しないためです。
Pro と Team は 4g、8g、16g（2、4、8 vCPU）に対応します。Max では 24g と 32g（12、16 vCPU）、さらに 64g（32 vCPU）も利用できます。
Base のリセットは新しい世代を作り、古いマシンを保持します。

## 接続と表示

```bash
hmux vm shell <id>
hmux vm tui <id>
hmux vm desktop <id>
hmux vm open <machine>
hmux vm open <machine>/<ws>[/<term>]
hmux vm open <machine>:desktop
hmux vm open <machine> <port> [--print]
hmux vm ssh <id>
```

HTTP ポートはプライベートネットワークの URL を使います。デスクトップと SSH は
対応マシンのみ利用できます。`vm tree` のアドレスをそのまま `vm open` に渡せます。

## ワークスペースとターミナル

```bash
hmux vm workspace new <id> [--name <n>] [--reuse] [--no-open]   # --reuse: 同名があれば再利用、--no-open: ローカルに開かず用意だけ
hmux vm workspace open <id> <ws> [--here|--tabs|--pane <p> --left|--right|--up|--down]
hmux vm workspace rename <id> <ws> <name>
hmux vm workspace rm <id> <ws>
hmux vm workspace close <id> <ws>
hmux vm terminal close <id> <term>
hmux vm terminal send <id> <term> 'bun test' --keys enter
hmux vm terminal wait <id> <term> --pattern 'pass|fail' [--timeout 120]
hmux vm terminal wait-exit <id> <term> [--timeout <s>]   # プロセスの終了を待つ（exited code=<n> | pending）
hmux vm terminal output <id> <term> [--after <offset>]   # これまでの出力全体（画面だけではなく）
hmux vm terminal read <id> <term>
hmux surface ls [--json]
hmux surface new-terminal --machine <id> --no-open -- <cmd>
```

`workspace rm` は内部のターミナルも終了します。`workspace close` はターミナルを
実行したままワークスペースを閉じます。`workspace open` は空なら何も開かず、
`vm open <machine>/<ws>` は空のワークスペースでシェルを開始します。
`--tabs` と分割方向は併用せず、方向は一つだけ指定します。

対話プログラムや別のエージェントは `terminal send/wait/read` で操作し、
ユーザーのフォーカスを奪いません。見せる内容ができたときだけペインを開きます。

## コマンドとエージェント

```bash
hmux vm exec [--timeout <s>] <id> -- <command...>   # 既定 30 秒、最大 900 秒
hmux vm run [--sync] [--pull <remote-path>] [--machine <id>] [--new] [--size <4g|8g|16g|24g|32g|64g|MB>] [--timeout <seconds>] [--wait [--output]] -- <command...>
hmux vm route [--cwd <dir>]
hmux vm wait <id> [--timeout <seconds>] [--wake]
hmux vm agent --agent <claude|codex|opencode|pi> [--machine <id>] [--sync] [--cwd <dir>] [--name <name>] [--no-open] [--new] [--size <4g|8g|16g|24g|32g|64g|MB>] [--wait [--output] [--timeout <s>]] -- <prompt or args...>
hmux vm dev <id> [<folder>] [--name <ws>] [--layout <file>] [--command "<cmd>"] [--port <n>] [--remote <path>] [--no-sync] [--no-open]
hmux vm self <id> [<path>] [--json]   # マシンのリフレクション（名前、所有者、チーム、peers、integrations）
```

`vm run` は空いているプールマシンを再利用し、必要なら起動または作成します。
既定の期限は 600 秒、上限は 15 分です。`--sync` は先に作業ディレクトリを送信し、
`--pull` は終了後に指定パスを取得します。長時間の作業は永続ターミナルの
`vm agent` で開始してください。引数の先頭が通常の文章ならワンショットの
プロンプトとして実行し、フラグや既知のサブコマンドはそのまま渡します。
クラウド用エージェントの認証設定は `hmux ai-accounts upload` で行います。
`--wait` はエージェントのプロセスが終了するまで待ち（Ctrl-C は待機だけを止め、
エージェントは止めません）、`--output` はその後に出力全体を表示し、終了コードは
そのまま返ります（タイムアウトやシグナルは 1）。`vm dev` は 1 つの動詞で開発環境を
用意します: ルーティング、フォルダの送信、開発コマンドの検出（`package.json` の
`scripts.dev` をロックファイルに応じて bun/pnpm/yarn/npm、`cargo run`、`go run .`、
`manage.py runserver`、`make dev`）、フォルダ名のワークスペースの作成または再利用、
開発ペイン + シェル + ブラウザのレイアウト適用、そして Mac 側でジオメトリ付きで開きます。
`--command`/`--port` は検出を上書きし、`--layout` は組み込みレイアウトを置き換えます。

## ファイルと保存

```bash
hmux vm push <id> <local-path> [remote-path] [--exclude <pattern>]... [--watch [--interval <s>]]
hmux vm push --secret <id> <local-file> <remote-path> [--mode <octal>]   # 1 ファイルをリンク経由で送る（exec を通らない、0600、アトミック、256 KiB まで）
hmux vm pull <id> <remote-path> [local-path]
hmux vm snapshot <id> [--name <name>]
hmux vm snapshot ls <id> [--json]        # このマシンのスナップショット一覧（新しい順）
hmux vm snapshot rm <id> <snapshot-id>   # このマシンのスナップショットを 1 つ削除
hmux vm fork <id> [--name <name>]
hmux vm restore <snapshot-id>
hmux vm pause <id>    # 作業が終わったら停止（計算資源は止まり、ファイルとデーモン状態は残る）
hmux vm resume <id>   # 再開
hmux vm rm <id>
```

ディレクトリは tar で転送し、`node_modules` や `.git` などを既定で除外します。
転送サイズには制限があるため、ビルド成果物を含めないでください。
`--watch` はローカルの変更を検知するたびに再送信します（1 回ごとに 1 行、Ctrl-C で終了）。
通常の push と watch は転送先にファイルを上書きし、リモートにしかないファイルやローカルで削除したファイルを残します。削除が必要な場合はマシン上で明示的に削除してください。エージェントがリモートで作成したファイルを保護するため、ディレクトリの完全なミラーにはなりません。
`--secret` は鍵、トークン、認証情報を含む設定ファイル用です。`vm env set` と同じく
エンドツーエンドのリンクでマシンの `hmux file receive` に届き、受信側は読み取り前に
エコーを切るため、コマンドライン、コントロールプレーン、プロバイダー API、画面、
スクロールバックのどこにもバイトが現れません。ディレクトリは拒否されます。
保存・複製・復元は機能契約で対応を確認してください。`vm rm` は確認なしで
不可逆に削除するため、このセッションで作成したマシン以外は、ユーザーが
今回明示的に指定した場合のみ削除できます。

## マシン内の操作

`hmux self [--json]` はこのマシンを識別し（名前、ID、状態、チーム、所有者、プラン）、`hmux self peers|integrations|owner|machine` は到達できるマシンと使える連携を返します（別名: `hmux whoami`、`hmux reflect`）。`hmux vm ls [--json]` は所有者のマシン一覧で、このマシンには `*` が付きます。どれもローカルデーモンを必要とせず、エッジが付与するマシン認証でリフレクション（`GET /api/vm/reflection`、古いサーバーでは `/api/vm/self`）を読み取ります。

```bash
hmux self                            # 自分の名前、ID、状態、所有者、プラン
hmux self peers                      # 到達できる他のマシンとその経路
hmux vm ls                           # 所有者のマシン一覧（このマシンは *）
hmux terminal send <term> 'bun test' --keys enter ; hmux terminal wait-exit <term> ; hmux terminal output <term>
hmux layout apply --name app app.json ; hmux env set KEY=VALUE ; hmux notify --title 完了
hmux agent claude [--timeout <s>] "テストを直して"   # このターミナルで終了まで実行（それ自体が待機。終了コードはそのまま）
hmux file receive <path> [--mode <octal>]           # `hmux vm push --secret`（Mac）と他マシンの `hmux vm push` が書き込む受信側
hmux vm exec <machine> -- <command>  # 他のマシンには Mac と同じ文法 hmux vm <verb> <machine> …
hmux vm tree <machine>
hmux vm push <machine> <local-file> <remote-path> [--mode <octal>]   # 1 ファイルを他のマシンへ、常にリンク経由
hmux vm agent <machine> --agent codex --wait --output -- "…"        # 他のマシンのエージェントを終了まで待つ
```

ローカル操作はマシン自身のセッションを使い、Mac と同じ動詞（`hmux send-key`、`hmux terminal send|read|wait|wait-exit|output`、`hmux layout …`、`hmux env …`、`hmux notify`）で操作します。他のマシンには Mac と同じ文法 `hmux vm <verb> <machine> …` を使います。接続先は `hmux self peers` で自動的に見つかり（所有者のプライベートネットワークが信頼境界なので Mac 側の手順は不要）、古い Mac 製の経路ファイルもそのまま使えます。アカウントの認証情報はマシンに保存しません。

接続完了はデーモンのイベントで通知され、30 秒の期限とキャンセル処理を備えます。
状態確認のためのポーリングは行いません。ゲストの案内言語は `LC_ALL`、
`LC_MESSAGES`、`LANG` の順で選び、英語と日本語に対応します。

## 作業上の規則

- 新規作成は課金と台数制限に影響します。まず `vm ls` を確認し、`vm run` や `vm agent` の再利用を優先します。
- 状態を繰り返し問い合わせず、`vm wait` を使います。
- `--json` はヘルプに記載されたコマンドだけで使い、人間向けの表を解析しません。
- シェル構文を使う場合は `-- sh -c '<script>'` と明示します。
- 料金プランの制限や利用できるサイズは、記憶ではなく現在の CLI 応答から読み取ります。

### マシン内のエージェントが表示を整える

`hmux tree --json` でワークスペース、画面、ペイン、分割、タブの ID を確認します。

```bash
hmux workspace rename <ws> "レビュー準備完了"
hmux terminal rename current "ビルド" --json
hmux tab rename <tab> "テスト結果" --json
hmux pane split <pane> right --ratio 0.6 --json
hmux tab move <tab> --workspace <ws> --screen <screen> --pane <destination-pane> --index 0 --json
hmux pane swap <pane> --other-workspace <ws> --other-screen <screen> --other-pane <other-pane> --json
hmux pane resize <pane> --split <split> --ratio 0.65 --json
hmux workspace move <ws> --index 0
hmux tab focus <tab>
hmux notify --title "レビュー準備完了" --body "アプリ、ログ、テスト結果を配置しました。"
```

`tab rename` は配置ごと、`terminal rename` はそのターミナルの現在の全配置の名前を変更します。
複数表示があるターミナルはタブ ID で移動してください。名前変更、移動、入れ替え、分割比率の
変更は、実行中のターミナルを再起動しません。`pane resize` は画面の分割比率の操作です。
マシンのディスクサイズ変更は利用できません。

ローカル操作は `hmux <resource> <verb> …`、ピア操作は
`hmux vm <resource> <verb> <machine> …` です。ID を先に指定するデーモン構文も使えます。
詳細は `hmux workspace help` を参照してください。

ユーザーに見せる前にデーモンのワークスペースを整えます。Mac の
`hmux vm workspace open <machine> <ws>` はローカル表示の作成時にその配置を読み取ります。
ゲストの操作は、すでに開いている Mac の表示の配置やフォーカスを強制変更しません。
`layout apply` は新規または空のワークスペース用です。使用中の配置は上記のコマンドで変更します。
