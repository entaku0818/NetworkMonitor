# NetworkMonitor

NetworkMonitorは、Swift Package Managerを使用してiOS、macOS、watchOS、tvOSアプリケーションでネットワーク通信を監視、分析、フィルタリングするためのライブラリです。Charlesのように使いやすく、かつ強力な機能を提供します。

## 機能概要

### 実装済み機能 ✅

- **HTTPリクエスト/レスポンスモデル**: 完全なHTTPセッション管理とメタデータ対応
- **高度なフィルタリングエンジン**: 複合条件、正規表現、事前定義フィルター対応
- **セッション永続化**: JSON/Binary Plist形式でのファイル保存・読み込み
- **非同期処理**: 完全な非同期API設計でパフォーマンス最適化
- **包括的なテストカバレッジ**: 93テストケースで品質保証

### 計画中機能 🚧

- **ネットワークリクエスト/レスポンスの傍受**: HTTPおよびHTTPSリクエストとレスポンスをリアルタイムで傍受
- **SSL解読**: HTTPSトラフィックを解読するためのユーティリティ（開発環境用）
- **UIコンポーネント**: キャプチャされたネットワークトラフィックを表示するためのビューコンポーネント
- **カスタムプロキシ**: 必要に応じてリクエスト/レスポンスを変更可能なプロキシ機能

## アーキテクチャ設計

### 1. コアモジュール

```
NetworkMonitor
├── Core
│   ├── Monitor - メインのモニタリングエンジン
│   ├── Interceptor - ネットワークリクエスト/レスポンスの傍受
│   ├── Storage - キャプチャデータの保存
│   └── Certificate - SSL証明書の管理
├── Models
│   ├── Request - HTTPリクエストモデル
│   ├── Response - HTTPレスポンスモデル
│   └── Session - ネットワークセッションモデル
├── Filters
│   ├── FilterEngine - フィルタリングロジック
│   ├── FilterCriteria - フィルター条件の定義
│   └── Predefined Filters - よく使われるフィルターのプリセット
└── UI (オプショナル)
    ├── SessionListView - セッションリスト表示
    ├── RequestDetailView - リクエスト詳細表示
    └── FilterConfigurationView - フィルター設定UI
```

### 2. データフロー

1. アプリケーションがネットワークリクエストを発行
2. NetworkMonitorの`Interceptor`がリクエストを傍受
3. リクエストデータが`Request`モデルに変換される
4. `Monitor`がリクエストを記録し、必要に応じて変更
5. リクエストが実際のネットワークに送信される
6. レスポンスが返ってきたら同様にプロセス
7. `FilterEngine`が設定されたフィルターに基づいて結果をフィルタリング
8. フィルタリング済みデータが`Storage`に保存または`UI`に表示

## 技術的な実装方針

### ネットワーク傍受方法

1. **URLProtocol**: `URLProtocol`を拡張して、`URLSession`ベースのリクエストを傍受
2. **NSURLConnectionDelegateのスワップ**: レガシーなNSURLConnectionもサポート
3. **プロキシ設定**: システムワイドなプロキシとして機能させるオプション

### SSLトラフィックの取り扱い

1. **CA証明書の生成と管理**
   - 独自のルート証明書（CA）の生成機能
   - 証明書のエクスポートとインストール手順のガイド
   - iOSシミュレータおよび実機での証明書信頼設定方法
   
2. **オンザフライでのSSL証明書生成**
   - ドメインごとの動的証明書生成
   - サーバー証明書の模倣と署名
   - 証明書キャッシュ機能
   
3. **App Transport Security (ATS) 対応**
   - 開発用ATSバイパス設定のガイド
   - Info.plistの設定例の提供
   - セキュリティリスクの説明と警告
   
4. **プロキシ設定方法**
   - ローカルプロキシサーバーとしての機能
   - システム全体またはアプリケーション単位での設定方法
   - カスタムURLSessionConfigurationの設定例
   
5. **セキュリティ考慮事項**
   - 開発環境のみでの使用推奨
   - リリースビルドでの自動無効化機能
   - セキュリティリスクと対策の詳細ガイド

### パフォーマンス最適化

1. 大量のネットワークトラフィックに対する効率的なメモリ管理
2. 非同期処理によるメインスレッドへの影響最小化
3. キャプチャデータの効率的な保存戦略

### フィルタリングエンジン

1. 複合条件でのフィルタリング（AND/OR論理）
2. 正規表現によるパターンマッチング
3. JSONパスやXPathによるボディコンテンツのフィルタリング

## 使用例

### 基本的な使用方法

```swift
import NetworkMonitor

// 基本的な使用例
let monitor = NetworkMonitor.shared
monitor.start()

// フィルターの設定
let filter = FilterCriteria()
    .host(pattern: "api.example.com")
    .method(.POST)
    .statusCodeRange(400..<500)

let filterEngine = FilterEngine()
let sessions = filterEngine.filter(sessions: allSessions, using: filter)

// 結果の表示
for session in sessions {
    print("Request: \(session.request.url)")
    print("Status: \(session.response?.statusCode ?? 0)")
}

// 終了
monitor.stop()
```

### フィルタリングの例

```swift
// 成功レスポンスのみを取得
let successFilter = FilterCriteria.successOnly()
let successSessions = filterEngine.filter(sessions: allSessions, using: successFilter)

// 複合条件でのフィルタリング
let complexFilter = FilterCriteria()
    .host(pattern: "api.example.com")
    .method(.GET, logicalOperator: .and)
    .duration(min: 1.0, logicalOperator: .and)

// 正規表現を使用したフィルタリング
let regexFilter = FilterCriteria()
    .url(pattern: ".*\\.json$", isRegex: true)

// 事前定義フィルターの使用
let slowRequests = filterEngine.filterSlowRequests(sessions: allSessions, threshold: 2.0)
let errorRequests = filterEngine.filterErrorsOnly(sessions: allSessions)
```

### セッションストレージの例

```swift
// ファイルベースのストレージ設定
let storageConfig = FileSessionStorage.StorageConfiguration(
    fileFormat: .json,
    maxSessions: 1000,
    autoCleanup: true,
    retentionPeriod: 30 * 24 * 60 * 60 // 30日
)

let storage = FileSessionStorage(configuration: storageConfig)

// セッションの保存
storage.save(session: session) { result in
    switch result {
    case .success():
        print("Session saved successfully")
    case .failure(let error):
        print("Save failed: \(error)")
    }
}

// セッションの読み込み
storage.loadAll { result in
    switch result {
    case .success(let sessions):
        print("Loaded \(sessions.count) sessions")
    case .failure(let error):
        print("Load failed: \(error)")
    }
}

// フィルタリングしながら読み込み
let criteria = FilterCriteria().statusCategory(.success)
storage.load(matching: criteria) { result in
    switch result {
    case .success(let filteredSessions):
        print("Found \(filteredSessions.count) successful sessions")
    case .failure(let error):
        print("Filter load failed: \(error)")
    }
}
```

## HTTPSトラフィック解読のアプリへの組み込み

HTTPSトラフィックを解読してアプリに組み込む場合、以下の手順が必要になります：

### 1. CA証明書のインストールと信頼設定

```swift
// 証明書生成の例
func generateCACertificate() -> SecCertificate? {
    // 証明書生成ロジック
    // ...
    return certificate
}

// 証明書エクスポート
func exportCertificate(_ certificate: SecCertificate) -> Data? {
    // 証明書のエクスポートロジック
    // ...
    return certificateData
}

// ユーザーガイド表示
func showCertificateInstallationGuide() {
    // 証明書インストール手順のガイド表示
    // ...
}
```

### 2. App Transport Security (ATS) 設定

Info.plistに以下の設定を追加して、開発中のみATSを調整します：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
    <!-- 開発環境のみでtrueにすることを推奨 -->
</dict>
```

または、特定のドメインのみを対象にする場合：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>example.com</key>
        <dict>
            <key>NSIncludesSubdomains</key>
            <true/>
            <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key>
            <true/>
        </dict>
    </dict>
</dict>
```

### 3. URLSessionConfigurationの設定

カスタムURLSessionを使用している場合は、プロトコルの登録が必要です：

```swift
let config = URLSessionConfiguration.default
config.protocolClasses = [NetworkInterceptor.self] + (config.protocolClasses ?? [])

let session = URLSession(configuration: config)
// このセッションを使用してリクエストを実行
```

### 4. アプリ内での有効化・無効化

デバッグビルドでのみ有効化する例：

```swift
#if DEBUG
    Monitor.shared.enableSSLDecryption()
#endif
```

### 5. セキュリティ上の考慮事項

- 証明書のプライベートキーはセキュアに保管
- ユーザーデータやセンシティブな情報の取り扱いに注意
- App Storeに提出する際は、デバッグコードが残っていないか確認
- リリースビルドでは必ず無効化

## 今後の開発ロードマップ

### フェーズ1: 基本機能の実装
- [ ] コアモニタリングエンジン
- [ ] 基本的なリクエスト/レスポンスのモデル
- [ ] シンプルなフィルタリング機能

### フェーズ2: 高度な機能の追加
- [ ] SSL解読機能
- [ ] 複雑なフィルタリングルール
- [ ] データ永続化

### フェーズ3: UIコンポーネントと使いやすさの向上
- [ ] SwiftUIベースのビューワーコンポーネント
- [ ] Charlesライクなインターフェース
- [ ] ダッシュボード機能

## ライセンス

MIT

## 注意事項

このライブラリは開発およびデバッグ目的で設計されています。プロダクション環境での使用や、ユーザーのプライバシーに関わるデータの収集には適していません。SSL解読機能を使用する場合は、適切な情報開示と同意を得てください。

## テスト方法

### コマンドラインからテストを実行

以下のコマンドを実行してテストを行います：

```bash
swift test
```

このコマンドは、プロジェクトのルートディレクトリで実行してください。すべてのテストが自動的に実行されます。

### Xcodeでテストを実行

1. プロジェクトをXcodeで開きます：
   ```bash
   xed .
   ```

2. テストナビゲーター（⌘6）を開きます。

3. テストボタン（▶）をクリックするか、⌘U を押してテストを実行します。

## テストの内容

現在、以下のテストが実装されています：

- `initializationCreatesSharedInstance()`: シングルトンインスタンスが正しく作成されることを確認
- `monitorStartsAndStopsCorrectly()`: モニタリングの開始と停止が正しく機能することを確認
- `versionIsCorrect()`: バージョン番号が正しいことを確認

## 独自のテストを追加

`Tests/NetworkMonitorTests/` ディレクトリ内のテストファイルに独自のテストケースを追加できます。 