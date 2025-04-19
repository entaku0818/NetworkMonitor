# コードスタイルガイド

NetworkMonitorプロジェクトでは、コードの一貫性と可読性を確保するために以下のスタイルガイドラインに従ってください。

## 基本原則

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)に従う
- シンプルで明確なコードを心がける
- 適切なドキュメントコメントを記述する

## 命名規則

### 型名

- 型名（クラス、構造体、列挙型、プロトコル）は**UpperCamelCase**を使用する
  ```swift
  class RequestInterceptor { }
  struct HTTPHeader { }
  enum RequestMethod { }
  protocol NetworkMonitorDelegate { }
  ```

### 変数と関数名

- 変数名、関数名は**lowerCamelCase**を使用する
  ```swift
  let maxRetryCount = 3
  var isMonitoring = false
  
  func startMonitoring() { }
  func interceptRequest(_ request: URLRequest) -> URLRequest { }
  ```

### 定数

- グローバル定数や型の静的定数は**lowerCamelCase**を使用する
  ```swift
  let defaultTimeout = 30.0
  static let defaultPort = 8080
  ```

## フォーマット

### インデント

- インデントには**スペース4つ**を使用する
- タブ文字は使用しない

### 括弧

- 開き括弧は同じ行に配置する
  ```swift
  if condition {
      // code
  } else {
      // code
  }
  
  func myFunction() {
      // code
  }
  ```

### 行の長さ

- 1行は120文字以内に収める
- 長い行は適切に改行する

## ドキュメンテーション

- 公開API、クラス、メソッドには必ずDocCスタイルのドキュメントコメントを記述する
  ```swift
  /// ネットワークリクエストを傍受するクラス。
  /// URLProtocolを継承し、アプリケーション内のすべてのHTTPリクエストをキャプチャする。
  class NetworkInterceptor: URLProtocol {
      
      /// 指定されたリクエストを処理できるかどうかを判断する。
      /// - Parameter request: 評価するURLRequest
      /// - Returns: リクエストを処理できる場合はtrue、それ以外はfalse
      override class func canInit(with request: URLRequest) -> Bool {
          // 実装
      }
  }
  ```

## アクセス制御

- できるだけ制限の厳しいアクセスレベルを使用する
- 内部実装の詳細は`private`または`fileprivate`にする
- 外部に公開するAPIは明示的に`public`にする
- デフォルトの`internal`アクセスレベルも、明示的に記述することが望ましい

## エラー処理

- `try-catch`ブロックを使用してエラーを適切に処理する
- エラーケースは明確に定義する
- エラーメッセージは具体的で理解しやすいものにする

## テスト

- すべての公開APIにはユニットテストを記述する
- テスト関数名は`test`で始め、テストの内容を明確に表現する
  ```swift
  func testInterceptorCapturesHTTPRequests() { }
  func testSessionModelStoresResponseData() { }
  ```

## Swift特有のガイドライン

### オプショナル

- Implicitly Unwrapped Optionalの使用は最小限にする
- オプショナルバインディングや`guard let`を積極的に使用する
  ```swift
  if let data = responseData {
      // dataを安全に使用
  }
  
  guard let url = URL(string: urlString) else {
      return
  }
  ```

### 型推論

- 型が明確な場合は型推論を利用する
- ただし、APIの境界では明示的な型アノテーションを使用する

### クロージャ

- トレーリングクロージャ構文を適切に使用する
- 長いクロージャは読みやすいように適切に改行・インデントする

## コードレビュー

- コードレビューでは、このスタイルガイドに沿っているかを確認する
- コード品質、パフォーマンス、セキュリティの問題も確認する 