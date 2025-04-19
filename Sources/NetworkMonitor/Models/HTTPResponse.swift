import Foundation

/// HTTPレスポンスを表すモデル。
/// レスポンスのステータスコード、ヘッダー、ボディ、タイミング情報などを格納します。
public struct HTTPResponse: Codable {
    
    /// HTTPステータスコードのカテゴリを表す列挙型
    public enum StatusCodeCategory: Int, Codable {
        case informational = 1  // 100-199: 情報レスポンス
        case success = 2        // 200-299: 成功レスポンス
        case redirection = 3    // 300-399: リダイレクションレスポンス
        case clientError = 4    // 400-499: クライアントエラーレスポンス
        case serverError = 5    // 500-599: サーバーエラーレスポンス
        case unknown = 0        // その他
        
        /// ステータスコードからカテゴリを判定
        public static func from(statusCode: Int) -> StatusCodeCategory {
            let firstDigit = statusCode / 100
            return StatusCodeCategory(rawValue: firstDigit) ?? .unknown
        }
    }
    
    /// HTTPステータスコード
    public let statusCode: Int
    
    /// ステータスコードのカテゴリ
    public let statusCategory: StatusCodeCategory
    
    /// HTTPレスポンスヘッダー
    public let headers: [String: String]
    
    /// レスポンスボディのデータ
    public let body: Data?
    
    /// レスポンスを受信した時刻
    public let timestamp: Date
    
    /// レスポンスの処理に要した時間（秒）
    public let duration: TimeInterval
    
    /// MIMEタイプ
    public let mimeType: String?
    
    /// レスポンスのエンコーディング
    public let encoding: String?
    
    /// レスポンスのサイズ（バイト）
    public let contentLength: Int64
    
    /// レスポンスがキャッシュから取得されたかどうか
    public let fromCache: Bool
    
    /// レスポンスに関連するエラー（存在する場合）
    public let error: Error?
    
    /// 標準のイニシャライザ
    /// - Parameters:
    ///   - statusCode: HTTPステータスコード
    ///   - headers: レスポンスヘッダー
    ///   - body: レスポンスボディ
    ///   - timestamp: レスポンスを受信した時刻
    ///   - duration: レスポンスの処理に要した時間（秒）
    ///   - mimeType: MIMEタイプ
    ///   - encoding: エンコーディング
    ///   - fromCache: キャッシュから取得されたかどうか
    ///   - error: レスポンスに関連するエラー
    public init(
        statusCode: Int,
        headers: [String: String] = [:],
        body: Data? = nil,
        timestamp: Date = Date(),
        duration: TimeInterval = 0,
        mimeType: String? = nil,
        encoding: String? = nil,
        fromCache: Bool = false,
        error: Error? = nil
    ) {
        self.statusCode = statusCode
        self.statusCategory = StatusCodeCategory.from(statusCode: statusCode)
        self.headers = headers
        self.body = body
        self.timestamp = timestamp
        self.duration = duration
        self.mimeType = mimeType
        self.encoding = encoding
        
        // Content-Lengthヘッダーから取得するか、ボディサイズを使用
        if let contentLengthString = headers["Content-Length"],
           let contentLength = Int64(contentLengthString) {
            self.contentLength = contentLength
        } else {
            self.contentLength = Int64(body?.count ?? 0)
        }
        
        self.fromCache = fromCache
        self.error = error
    }
    
    // MARK: - Codable Conformance
    
    /// エラーはCodableではないため、カスタムのCodable実装が必要
    private enum CodingKeys: String, CodingKey {
        case statusCode, statusCategory, headers, body, timestamp, duration
        case mimeType, encoding, contentLength, fromCache, errorDescription
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        statusCode = try container.decode(Int.self, forKey: .statusCode)
        statusCategory = try container.decode(StatusCodeCategory.self, forKey: .statusCategory)
        headers = try container.decode([String: String].self, forKey: .headers)
        body = try container.decodeIfPresent(Data.self, forKey: .body)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        mimeType = try container.decodeIfPresent(String.self, forKey: .mimeType)
        encoding = try container.decodeIfPresent(String.self, forKey: .encoding)
        contentLength = try container.decode(Int64.self, forKey: .contentLength)
        fromCache = try container.decode(Bool.self, forKey: .fromCache)
        
        // エラーはStringとして保存されるため、NSErrorとして復元
        if let errorDescription = try container.decodeIfPresent(String.self, forKey: .errorDescription) {
            error = NSError(domain: "HTTPResponseErrorDomain", code: 0, userInfo: [NSLocalizedDescriptionKey: errorDescription])
        } else {
            error = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(statusCode, forKey: .statusCode)
        try container.encode(statusCategory, forKey: .statusCategory)
        try container.encode(headers, forKey: .headers)
        try container.encodeIfPresent(body, forKey: .body)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(duration, forKey: .duration)
        try container.encodeIfPresent(mimeType, forKey: .mimeType)
        try container.encodeIfPresent(encoding, forKey: .encoding)
        try container.encode(contentLength, forKey: .contentLength)
        try container.encode(fromCache, forKey: .fromCache)
        
        // エラーはその説明文字列としてエンコード
        if let error = error {
            try container.encode(error.localizedDescription, forKey: .errorDescription)
        }
    }
    
    /// URLResponseからHTTPResponseを作成
    /// - Parameters:
    ///   - urlResponse: 変換元のURLResponse
    ///   - data: レスポンスボディのデータ
    ///   - duration: リクエストからレスポンスまでの時間
    ///   - error: 発生したエラー（存在する場合）
    /// - Returns: 新しいHTTPResponseインスタンス
    public static func from(
        urlResponse: URLResponse,
        data: Data? = nil,
        duration: TimeInterval = 0,
        error: Error? = nil
    ) -> HTTPResponse {
        // HTTPURLResponseへのキャスト
        if let httpResponse = urlResponse as? HTTPURLResponse {
            // HTTPヘッダーをDictionary形式に変換
            let headers = httpResponse.allHeaderFields as? [String: String] ?? [:]
            
            return HTTPResponse(
                statusCode: httpResponse.statusCode,
                headers: headers,
                body: data,
                timestamp: Date(),
                duration: duration,
                mimeType: httpResponse.mimeType,
                encoding: httpResponse.textEncodingName,
                fromCache: false,
                error: error
            )
        }
        
        // HTTPURLResponseではない場合（まれ）
        return HTTPResponse(
            statusCode: 0,
            body: data,
            duration: duration,
            mimeType: urlResponse.mimeType,
            encoding: urlResponse.textEncodingName,
            error: error ?? NSError(domain: "HTTPResponseErrorDomain", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not an HTTP response"])
        )
    }
    
    /// レスポンスボディを文字列として取得
    /// - Parameter encoding: 使用するエンコーディング（指定がなければヘッダーから取得、それもなければUTF-8）
    /// - Returns: ボディの文字列表現、変換できない場合はnil
    public func bodyAsString(using suggestedEncoding: String.Encoding? = nil) -> String? {
        guard let data = body else { return nil }
        
        // エンコーディングの決定（優先順位: 引数 > レスポンスのエンコーディング情報 > デフォルトUTF8）
        if let encoding = suggestedEncoding {
            return String(data: data, encoding: encoding)
        }
        
        // レスポンスのエンコーディング情報から取得
        if let encodingName = encoding {
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(encodingName as CFString)
            if cfEncoding != kCFStringEncodingInvalidId {
                let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
                return String(data: data, encoding: String.Encoding(rawValue: nsEncoding))
            }
        }
        
        // Content-Typeヘッダーからのエンコーディング取得を試みる
        if let contentType = headers["Content-Type"],
           let charsetRange = contentType.range(of: "charset=") {
            let charsetStart = contentType.index(charsetRange.upperBound, offsetBy: 0)
            let charsetString: String
            if let semicolonRange = contentType[charsetStart...].firstIndex(of: ";") {
                charsetString = String(contentType[charsetStart..<semicolonRange]).trimmingCharacters(in: .whitespaces)
            } else {
                charsetString = String(contentType[charsetStart...]).trimmingCharacters(in: .whitespaces)
            }
            
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(charsetString as CFString)
            if cfEncoding != kCFStringEncodingInvalidId {
                let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
                return String(data: data, encoding: String.Encoding(rawValue: nsEncoding))
            }
        }
        
        // デフォルトはUTF-8
        return String(data: data, encoding: .utf8)
    }
    
    /// レスポンスボディをJSONとしてデコード
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
    
    /// レスポンスが成功（200-299）かどうかを判定
    public var isSuccess: Bool {
        return statusCategory == .success
    }
    
    /// レスポンスがクライアントエラー（400-499）かどうかを判定
    public var isClientError: Bool {
        return statusCategory == .clientError
    }
    
    /// レスポンスがサーバーエラー（500-599）かどうかを判定
    public var isServerError: Bool {
        return statusCategory == .serverError
    }
    
    /// レスポンスが何らかのエラー（クライアントまたはサーバー）かどうかを判定
    public var isError: Bool {
        return isClientError || isServerError || error != nil
    }
}

// MARK: - Equatable
extension HTTPResponse: Equatable {
    public static func == (lhs: HTTPResponse, rhs: HTTPResponse) -> Bool {
        // エラーはEquatableではないので、比較から除外
        return lhs.statusCode == rhs.statusCode &&
               lhs.headers == rhs.headers &&
               lhs.body == rhs.body &&
               lhs.mimeType == rhs.mimeType &&
               lhs.encoding == rhs.encoding &&
               lhs.contentLength == rhs.contentLength &&
               lhs.fromCache == rhs.fromCache
    }
}

// MARK: - CustomStringConvertible
extension HTTPResponse: CustomStringConvertible {
    public var description: String {
        var desc = "Status: \(statusCode)\n"
        
        if !headers.isEmpty {
            desc += "Headers:\n"
            for (key, value) in headers {
                desc += "  \(key): \(value)\n"
            }
        }
        
        if let body = body, !body.isEmpty {
            if let bodyString = bodyAsString() {
                if bodyString.count > 1000 {
                    desc += "Body: \(bodyString.prefix(1000))... (\(body.count) bytes)"
                } else {
                    desc += "Body: \(bodyString)"
                }
            } else {
                desc += "Body: \(body.count) bytes"
            }
        }
        
        desc += "\nDuration: \(String(format: "%.3f", duration))s"
        
        if let error = error {
            desc += "\nError: \(error.localizedDescription)"
        }
        
        return desc
    }
} 