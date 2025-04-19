import Foundation

/// HTTPリクエストを表すモデル。
/// リクエストのURL、HTTPメソッド、ヘッダー、ボディなどの情報を格納します。
public struct HTTPRequest: Codable {
    /// HTTPメソッドの列挙型
    public enum Method: String, Codable, CaseIterable {
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
    
    /// リクエストのURL文字列
    public let url: String
    
    /// リクエストのURLコンポーネント
    public let urlComponents: URLComponents?
    
    /// HTTPメソッド
    public let method: Method
    
    /// HTTPヘッダーフィールド
    public let headers: [String: String]
    
    /// リクエストボディのデータ
    public let body: Data?
    
    /// リクエストのタイムスタンプ
    public let timestamp: Date
    
    /// リクエストのハッシュ値。識別子として使用できます。
    public let hash: String
    
    /// 標準のイニシャライザ
    /// - Parameters:
    ///   - url: リクエストのURL文字列
    ///   - method: HTTPメソッド
    ///   - headers: HTTPヘッダーフィールド
    ///   - body: リクエストボディ
    ///   - timestamp: リクエスト発生時のタイムスタンプ（デフォルトは現在時刻）
    public init(url: String, 
                method: Method, 
                headers: [String: String] = [:], 
                body: Data? = nil, 
                timestamp: Date = Date()) {
        self.url = url
        self.urlComponents = URLComponents(string: url)
        self.method = method
        self.headers = headers
        self.body = body
        self.timestamp = timestamp
        
        // URLとメソッドの組み合わせからハッシュを生成
        var hasher = Hasher()
        hasher.combine(url)
        hasher.combine(method.rawValue)
        hasher.combine(timestamp.timeIntervalSince1970)
        self.hash = "\(hasher.finalize())"
    }
    
    /// URLRequestからHTTPRequestを初期化
    /// - Parameter urlRequest: 変換元のURLRequest
    /// - Returns: 新しいHTTPRequestインスタンス
    public static func from(urlRequest: URLRequest) -> HTTPRequest? {
        guard let url = urlRequest.url?.absoluteString,
              let methodString = urlRequest.httpMethod,
              let method = Method(rawValue: methodString) else {
            return nil
        }
        
        // ヘッダーの変換
        var headers: [String: String] = [:]
        if let allHTTPHeaderFields = urlRequest.allHTTPHeaderFields {
            headers = allHTTPHeaderFields
        }
        
        return HTTPRequest(
            url: url,
            method: method,
            headers: headers,
            body: urlRequest.httpBody
        )
    }
    
    /// HTTPRequestをURLRequestに変換
    /// - Returns: 対応するURLRequest
    public func toURLRequest() -> URLRequest? {
        guard let url = URL(string: self.url) else { 
            return nil 
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.allHTTPHeaderFields = headers
        request.httpBody = body
        
        return request
    }
    
    /// リクエストボディを文字列として取得
    /// - Parameter encoding: 使用するエンコーディング（デフォルトはUTF-8）
    /// - Returns: ボディの文字列表現、変換できない場合はnil
    public func bodyAsString(using encoding: String.Encoding = .utf8) -> String? {
        guard let data = body else { return nil }
        return String(data: data, encoding: encoding)
    }
    
    /// リクエストボディをJSONとしてデコード
    /// - Parameter type: デコードするモデルの型
    /// - Returns: デコードされたモデル、失敗した場合はnil
    public func decodeBody<T: Decodable>(as type: T.Type) -> T? {
        guard let data = body else { return nil }
        
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(type, from: data)
        } catch {
            return nil
        }
    }
    
    /// クエリパラメータを辞書として取得
    /// - Returns: クエリパラメータの辞書
    public func queryParameters() -> [String: String] {
        guard let urlComponents = self.urlComponents,
              let queryItems = urlComponents.queryItems else {
            return [:]
        }
        
        var parameters: [String: String] = [:]
        for item in queryItems {
            parameters[item.name] = item.value ?? ""
        }
        
        return parameters
    }
}

// MARK: - Equatable
extension HTTPRequest: Equatable {
    public static func == (lhs: HTTPRequest, rhs: HTTPRequest) -> Bool {
        return lhs.url == rhs.url &&
               lhs.method == rhs.method &&
               lhs.headers == rhs.headers &&
               lhs.body == rhs.body
    }
}

// MARK: - CustomStringConvertible
extension HTTPRequest: CustomStringConvertible {
    public var description: String {
        var desc = "[\(method.rawValue)] \(url)\n"
        
        if !headers.isEmpty {
            desc += "Headers:\n"
            for (key, value) in headers {
                desc += "  \(key): \(value)\n"
            }
        }
        
        if let body = body, !body.isEmpty {
            if let bodyString = bodyAsString() {
                desc += "Body: \(bodyString)"
            } else {
                desc += "Body: \(body.count) bytes"
            }
        }
        
        return desc
    }
} 