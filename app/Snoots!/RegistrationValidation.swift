import Foundation

enum RegistrationValidation {
    static func selectionError(_ isSelected: Bool, title: String) -> String? {
        isSelected ? nil : "請選擇\(title)。"
    }

    static func requiredError(_ value: String, title: String) -> String? {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "請填寫\(title)。" : nil
    }

    static func validate(ownerName: String, petName: String, breed: String, socialStyle: String) throws {
        let errors = [
            requiredError(petName, title: "狗勾的名字"),
            requiredError(breed, title: "品種"),
            requiredError(ownerName, title: "飼主暱稱"),
            requiredError(socialStyle, title: "一個社交情境")
        ].compactMap { $0 }
        if let message = errors.first { throw RegistrationSubmissionError(message: message) }
    }
}

struct RegistrationSubmissionError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum RegistrationFailure: Equatable {
    case validation(String)
    case offline, timedOut, serviceUnavailable

    init(error: Error) {
        if let error = error as? URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost: self = .offline
            case .timedOut: self = .timedOut
            default: self = .serviceUnavailable
            }
        } else if let error = error as? RegistrationSubmissionError {
            self = .validation(error.message)
        } else {
            self = .serviceUnavailable
        }
    }

    var title: String {
        switch self {
        case .validation: "資料送出未完成"
        case .offline: "網路連線中斷"
        case .timedOut: "連線逾時"
        case .serviceUnavailable: "目前無法完成註冊"
        }
    }

    var message: String {
        switch self {
        case .validation(let message): message
        case .offline: "請確認 Wi-Fi 或行動網路連線後，再重新送出。"
        case .timedOut: "尚未收到送出結果，請稍後重新嘗試。"
        case .serviceUnavailable: "服務暫時無法使用，請稍後再試一次。"
        }
    }

    var symbol: String {
        switch self {
        case .offline: "wifi.slash"
        case .timedOut: "clock.badge.exclamationmark"
        case .validation, .serviceUnavailable: "exclamationmark.circle"
        }
    }
}
