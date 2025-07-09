# NetworkMonitor API Reference

## 概要

NetworkMonitorは、iOS、macOS、watchOS、tvOSアプリケーション向けのネットワーク監視・分析ライブラリです。このドキュメントでは、主要なAPIとその使用方法について説明します。

## 基本的な使用方法

```swift
import NetworkMonitor

let monitor = NetworkMonitor.shared
monitor.start()
// ... アプリケーションの処理
monitor.stop()
```

## コアコンポーネント

### NetworkMonitor

メインのネットワーク監視クラスです。

#### プロパティ

- `static let shared: NetworkMonitor` - シングルトンインスタンス
- `static let version: String` - ライブラリのバージョン

#### メソッド

- `func start()` - 監視を開始
- `func stop()` - 監視を停止
- `func isActive() -> Bool` - 監視が有効かどうかを確認

## データモデル

### HTTPRequest

HTTPリクエストを表すモデルです。

#### プロパティ

- `let url: String` - リクエストURL
- `let method: Method` - HTTPメソッド
- `let headers: [String: String]` - HTTPヘッダー
- `let body: Data?` - リクエストボディ
- `let timestamp: Date` - リクエスト時刻
- `let hash: String` - ユニークハッシュ

#### メソッド

- `static func from(urlRequest: URLRequest) -> HTTPRequest?` - URLRequestから変換
- `func toURLRequest() -> URLRequest?` - URLRequestに変換
- `func bodyAsString(using encoding: String.Encoding = .utf8) -> String?` - ボディを文字列として取得
- `func decodeBody<T: Decodable>(as type: T.Type) -> T?` - ボディをJSONデコード
- `func queryParameters() -> [String: String]` - クエリパラメータを取得

#### HTTPメソッド

```swift
enum Method: String, Codable, CaseIterable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"
    case trace = "TRACE"
    case connect = "CONNECT"
    case patch = "PATCH"
}
```

### HTTPResponse

HTTPレスポンスを表すモデルです。

#### プロパティ

- `let statusCode: Int` - ステータスコード
- `let statusCategory: StatusCodeCategory` - ステータスカテゴリ
- `let headers: [String: String]` - レスポンスヘッダー
- `let body: Data?` - レスポンスボディ
- `let timestamp: Date` - レスポンス時刻
- `let duration: TimeInterval` - レスポンス時間
- `let mimeType: String?` - MIMEタイプ
- `let encoding: String?` - エンコーディング
- `let contentLength: Int64` - コンテンツサイズ
- `let fromCache: Bool` - キャッシュからの取得フラグ
- `let error: Error?` - エラー情報

#### ステータスカテゴリ

```swift
enum StatusCodeCategory: Int, Codable {
    case informational = 1  // 100-199
    case success = 2        // 200-299
    case redirection = 3    // 300-399
    case clientError = 4    // 400-499
    case serverError = 5    // 500-599
    case unknown = 0        // その他
}
```

#### メソッド

- `static func from(urlResponse: URLResponse, data: Data?, duration: TimeInterval, error: Error?) -> HTTPResponse`
- `func bodyAsString(using suggestedEncoding: String.Encoding?) -> String?`
- `func decodeBody<T: Decodable>(as type: T.Type) -> T?`
- `var isSuccess: Bool` - 成功レスポンスかどうか
- `var isClientError: Bool` - クライアントエラーかどうか
- `var isServerError: Bool` - サーバーエラーかどうか
- `var isError: Bool` - エラーレスポンスかどうか

### HTTPSession

HTTPリクエストとレスポンスを組み合わせたセッションモデルです。

#### プロパティ

- `let id: UUID` - セッションID
- `let request: HTTPRequest` - HTTPリクエスト
- `let response: HTTPResponse?` - HTTPレスポンス
- `let state: State` - セッション状態
- `let startTime: Date` - 開始時刻
- `let endTime: Date?` - 終了時刻
- `var duration: TimeInterval` - 経過時間
- `let metadata: Metadata` - カスタムメタデータ
- `let retryCount: Int` - リトライ回数
- `let usedSSLDecryption: Bool` - SSL解読使用フラグ

#### セッション状態

```swift
enum State: String, Codable {
    case initialized
    case sending
    case waiting
    case receiving
    case completed
    case failed
    case cancelled
}
```

#### メタデータ

```swift
enum MetadataValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case date(Date)
}
```

#### メソッド

- `func sending() -> HTTPSession` - 送信中状態に更新
- `func waiting(requestDuration: TimeInterval) -> HTTPSession` - 待機中状態に更新
- `func receiving(responseStartTime: Date) -> HTTPSession` - 受信中状態に更新
- `func completed(response: HTTPResponse, endTime: Date) -> HTTPSession` - 完了状態に更新
- `func failed(error: Error, endTime: Date) -> HTTPSession` - 失敗状態に更新
- `func cancelled(endTime: Date) -> HTTPSession` - キャンセル状態に更新
- `func addMetadata(key: String, value: MetadataValue) -> HTTPSession` - メタデータ追加
- `func createChildSession(request: HTTPRequest) -> HTTPSession` - 子セッション作成

## フィルタリング

### FilterCriteria

フィルタリング条件を定義するクラスです。

#### 基本的な使用方法

```swift
let criteria = FilterCriteria()
    .host(pattern: "api.example.com")
    .method(.GET)
    .statusCategory(.success)
```

#### フィルタリング条件

- `url(pattern: String, isRegex: Bool = false)` - URLパターン
- `host(pattern: String, isRegex: Bool = false)` - ホスト名パターン
- `path(pattern: String, isRegex: Bool = false)` - パスパターン
- `method(_ method: HTTPRequest.Method)` - HTTPメソッド
- `statusCode(_ statusCode: Int)` - ステータスコード
- `statusCodeRange(_ range: Range<Int>)` - ステータスコード範囲
- `statusCategory(_ category: HTTPResponse.StatusCodeCategory)` - ステータスカテゴリ
- `contentType(_ contentType: String)` - Content-Type
- `hasRequestBody()` - リクエストボディの有無
- `hasResponseBody()` - レスポンスボディの有無
- `duration(min: TimeInterval?, max: TimeInterval?)` - レスポンス時間
- `timestamp(from: Date?, to: Date?)` - タイムスタンプ範囲
- `metadata(key: String, value: HTTPSession.MetadataValue?)` - メタデータ
- `hasError()` - エラーの有無
- `fromCache()` - キャッシュからの取得
- `usedSSLDecryption()` - SSL解読の使用
- `retryCount(min: Int?, max: Int?)` - リトライ回数

#### 事前定義フィルター

- `static func successOnly() -> FilterCriteria` - 成功レスポンスのみ
- `static func errorsOnly() -> FilterCriteria` - エラーレスポンスのみ
- `static func host(_ host: String) -> FilterCriteria` - 特定ホスト
- `static func slowRequests(threshold: TimeInterval) -> FilterCriteria` - 遅いリクエスト
- `static func jsonOnly() -> FilterCriteria` - JSONレスポンスのみ
- `static func imagesOnly() -> FilterCriteria` - 画像リクエストのみ

### FilterEngine

フィルタリングエンジンクラスです。

#### 基本的な使用方法

```swift
let engine = FilterEngine()
let criteria = FilterCriteria().statusCategory(.success)
let filteredSessions = engine.filter(sessions: allSessions, using: criteria)
```

#### メソッド

- `filter(sessions: [HTTPSession], using criteria: FilterCriteriaProtocol) -> [HTTPSession]` - フィルタリング
- `filter(sessions: [HTTPSession], using criteriaList: [FilterCriteriaProtocol], operator: CriteriaOperator) -> [HTTPSession]` - 複数条件フィルタリング
- `categorize(sessions: [HTTPSession], using groupCriteria: [String: FilterCriteriaProtocol]) -> [String: [HTTPSession]]` - カテゴリ分け
- `filterAndSort(sessions: [HTTPSession], using criteria: FilterCriteriaProtocol, ascending: Bool) -> [HTTPSession]` - フィルタリング＋ソート
- `filterWithPagination(sessions: [HTTPSession], using criteria: FilterCriteriaProtocol, page: Int, pageSize: Int) -> [HTTPSession]` - ページネーション
- `generateSummaryStatistics(for sessions: [HTTPSession]) -> [String: Any]` - 統計情報生成

#### 便利メソッド

- `filterSuccessOnly(sessions: [HTTPSession]) -> [HTTPSession]`
- `filterErrorsOnly(sessions: [HTTPSession]) -> [HTTPSession]`
- `filterByHost(sessions: [HTTPSession], host: String) -> [HTTPSession]`
- `filterSlowRequests(sessions: [HTTPSession], threshold: TimeInterval) -> [HTTPSession]`

## セッションストレージ

### SessionStorageProtocol

セッションの永続化を行うプロトコルです。

#### メソッド

- `save(session: HTTPSession, completion: @escaping (Result<Void, Error>) -> Void)` - セッション保存
- `save(sessions: [HTTPSession], completion: @escaping (Result<Void, Error>) -> Void)` - 複数セッション保存
- `load(sessionID: UUID, completion: @escaping (Result<HTTPSession?, Error>) -> Void)` - セッション読み込み
- `loadAll(completion: @escaping (Result<[HTTPSession], Error>) -> Void)` - 全セッション読み込み
- `load(matching criteria: FilterCriteriaProtocol, completion: @escaping (Result<[HTTPSession], Error>) -> Void)` - フィルタリング読み込み
- `delete(sessionID: UUID, completion: @escaping (Result<Void, Error>) -> Void)` - セッション削除
- `deleteAll(completion: @escaping (Result<Void, Error>) -> Void)` - 全セッション削除
- `count(completion: @escaping (Result<Int, Error>) -> Void)` - セッション数取得
- `storageSize(completion: @escaping (Result<Int64, Error>) -> Void)` - ストレージサイズ取得

### FileSessionStorage

ファイルベースのセッションストレージ実装です。

#### 設定

```swift
let configuration = FileSessionStorage.StorageConfiguration(
    baseDirectory: customDirectory,
    fileFormat: .json,
    maxSessions: 1000,
    autoCleanup: true,
    retentionPeriod: 30 * 24 * 60 * 60, // 30日
    compressionEnabled: false
)

let storage = FileSessionStorage(configuration: configuration)
```

#### ファイル形式

```swift
enum FileFormat {
    case json
    case binaryPlist
    case custom
}
```

#### 便利メソッド

- `export(sessions: [HTTPSession], to url: URL, format: FileFormat, completion: @escaping (Result<Void, Error>) -> Void)` - エクスポート
- `importSessions(from url: URL, format: FileFormat, completion: @escaping (Result<[HTTPSession], Error>) -> Void)` - インポート

## エラーハンドリング

### StorageError

```swift
enum StorageError: Error, LocalizedError {
    case fileNotFound
    case invalidFormat
    case writePermissionDenied
    case corruptedData
    case diskSpaceInsufficient
    case encodingFailed
    case decodingFailed
}
```

## 使用例

### 1. 基本的なフィルタリング

```swift
let criteria = FilterCriteria()
    .host(pattern: "api.example.com")
    .statusCategory(.success)

let engine = FilterEngine()
let filteredSessions = engine.filter(sessions: allSessions, using: criteria)
```

### 2. 複合条件フィルタリング

```swift
let criteria = FilterCriteria()
    .host(pattern: "api.example.com")
    .method(.POST, logicalOperator: .and)
    .duration(min: 1.0, logicalOperator: .and)
```

### 3. 正規表現フィルタリング

```swift
let criteria = FilterCriteria()
    .url(pattern: ".*\\.json$", isRegex: true)
```

### 4. セッションの永続化

```swift
let storage = FileSessionStorage()

// 保存
storage.save(session: session) { result in
    switch result {
    case .success():
        print("Saved successfully")
    case .failure(let error):
        print("Save failed: \(error)")
    }
}

// 読み込み
storage.loadAll { result in
    switch result {
    case .success(let sessions):
        print("Loaded \(sessions.count) sessions")
    case .failure(let error):
        print("Load failed: \(error)")
    }
}
```

### 5. エクスポート・インポート

```swift
let exportURL = documentsDirectory.appendingPathComponent("sessions.json")

// エクスポート
storage.export(sessions: sessions, to: exportURL) { result in
    // 処理
}

// インポート
storage.importSessions(from: exportURL) { result in
    switch result {
    case .success(let importedSessions):
        print("Imported \(importedSessions.count) sessions")
    case .failure(let error):
        print("Import failed: \(error)")
    }
}
```

## パフォーマンス考慮事項

- フィルタリングは非同期処理で行われます
- 大量のセッションを扱う場合は、ページネーション機能を使用してください
- ストレージの自動クリーンアップ機能を活用してディスク使用量を管理してください
- パフォーマンス統計機能を有効にして処理時間を監視できます

## 今後の予定

- ネットワーク傍受機能の実装
- SSL解読機能の追加
- UIコンポーネントの提供
- リアルタイムストリーミング機能

詳細な実装例については、プロジェクトのテストファイルを参照してください。