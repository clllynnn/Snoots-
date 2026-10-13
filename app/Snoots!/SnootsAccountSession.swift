import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import Security

enum AccountGate: Equatable {
    case checking, signedOut, needsProfile, ready
}

struct RegisteredDog: Codable {
    let name: String
    let breed: String
    let breedMappingStatus: String
    let size: String
    let sex: String
    let isNeutered: Bool
    let socialStyle: String
    let photoPath: String

    enum CodingKeys: String, CodingKey {
        case name, breed, size, sex
        case breedMappingStatus = "breed_mapping_status"
        case isNeutered = "is_neutered"
        case socialStyle = "social_style"
        case photoPath = "photo_path"
    }
}

struct RegisteredOwner: Codable {
    let nickname: String
}

private struct RegisteredMatchingDetails: Decodable {
    let birthDate: String
    let activityNeeds: [String]
    let activityPreferences: [String]
    let activityFreeText: String
    let activityKeywords: [String]
    let meetingEnvironments: [String]
    let firstMeetingPace: String
    let interactionScenario: String?
    let interactionFeatures: [String]
    let healthAnswers: [String: String]

    enum CodingKeys: String, CodingKey {
        case birthDate = "birth_date"
        case activityNeeds = "activity_needs"
        case activityPreferences = "activity_preferences"
        case activityFreeText = "activity_free_text"
        case activityKeywords = "activity_keywords"
        case meetingEnvironments = "meeting_environments"
        case firstMeetingPace = "first_meeting_pace"
        case interactionScenario = "interaction_scenario"
        case interactionFeatures = "interaction_features"
        case healthAnswers = "health_answers"
    }

    var local: DogMatchingProfile {
        var result = DogMatchingProfile()
        result.birthDate = SnootsAccountSession.profileDateFormatter.date(from: birthDate)
        result.activityNeeds = activityNeeds
        result.activityPreferences = activityPreferences
        result.activityDescription = activityFreeText
        result.activityKeywords = activityKeywords
        result.meetingEnvironments = meetingEnvironments
        result.firstMeetingPace = firstMeetingPace
        result.interactionScenario = interactionScenario
        result.interactionFeatures = interactionFeatures
        result.protectionAnswers = healthAnswers
        return result
    }
}

struct RegistrationPayload {
    let ownerName: String
    let dogName: String
    let breed: String
    let otherBreed: String?
    let size: String
    let sex: String
    let isNeutered: Bool
    let socialStyle: String
    let photoData: Data
}

private struct SupabaseSessionResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let user: SupabaseUser

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

private struct SupabaseUser: Decodable {
    let id: UUID
}

private enum AccountServiceError: LocalizedError {
    case notConfigured, invalidAppleToken, missingSession, invalidResponse, secureStorage, server(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "目前尚未設定帳號服務，請稍後再試。"
        case .invalidAppleToken: "Apple 登入憑證無法讀取，請重新登入。"
        case .missingSession: "登入已過期，請重新使用 Apple 登入。"
        case .invalidResponse: "服務回傳資料異常，請稍後再試。"
        case .secureStorage: "無法安全保存登入狀態，請檢查裝置設定後重試。"
        case .server(let status): status == 401 ? "登入已過期，請重新登入。" : "服務暫時無法使用，請稍後重試。"
        }
    }
}

/// The refresh token is never stored in UserDefaults. Keychain survives app restarts.
private enum RefreshTokenKeychain {
    private static let account = "snoots.supabase.refresh-token"

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ value: String) throws {
        clear()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(value.utf8)
        ]
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
            throw AccountServiceError.secureStorage
        }
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

#if DEBUG
private struct DebugMockProfile: Codable {
    let owner: RegisteredOwner
    let dog: RegisteredDog
    let photoData: Data
    var matchingProfile: DogMatchingProfile?
}

private enum DebugMockAccountStore {
    private static let activeKey = "snoots.debugMockAccount.active"
    private static var profileURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "Snoots!/debug-mock-profile.json")
    }

    static var isActive: Bool {
        get { UserDefaults.standard.bool(forKey: activeKey) }
        set { UserDefaults.standard.set(newValue, forKey: activeKey) }
    }

    static func load() throws -> DebugMockProfile? {
        guard FileManager.default.fileExists(atPath: profileURL.path) else { return nil }
        return try JSONDecoder().decode(DebugMockProfile.self, from: Data(contentsOf: profileURL))
    }

    static func save(_ profile: DebugMockProfile) throws {
        try FileManager.default.createDirectory(
            at: profileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(profile).write(to: profileURL, options: .atomic)
    }

    static func delete() throws {
        if FileManager.default.fileExists(atPath: profileURL.path) { try FileManager.default.removeItem(at: profileURL) }
        isActive = false
    }
}
#endif

@MainActor
@Observable
final class SnootsAccountSession {
    static var profileDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Taipei")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private(set) var gate: AccountGate = .checking
    private(set) var isBusy = false
    var errorMessage: String?
    var statusMessage: String?
    private(set) var userID: UUID?
    private(set) var owner: RegisteredOwner?
    private(set) var dog: RegisteredDog?
    private(set) var dogPhotoData: Data?
    private(set) var matchingProfile: DogMatchingProfile?

    private var accessToken: String?
    private let configuration = SupabaseNearbyConfiguration.load()
    #if DEBUG
    private var isMockSession = false
    #endif

    var usesPreviewAccount: Bool {
        #if DEBUG
        isMockSession
        #else
        false
        #endif
    }

    /// Uses the signed-in person's token; never substitutes an anonymous key.
    func authenticatedData(_ path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        guard accessToken != nil, userID != nil, !usesPreviewAccount else {
            throw AccountServiceError.missingSession
        }
        do {
            return try await rawRequest(path, method: method, body: body)
        } catch AccountServiceError.server(401) {
            guard let token = RefreshTokenKeychain.load() else { throw AccountServiceError.missingSession }
            let session: SupabaseSessionResponse = try await authToken(grant: "refresh_token", body: ["refresh_token": token])
            try accept(session)
            return try await rawRequest(path, method: method, body: body)
        }
    }

    static func newNonce() -> String {
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var random = SystemRandomNumberGenerator()
        return String((0..<32).map { _ in alphabet.randomElement(using: &random)! })
    }

    static func hashedNonce(_ nonce: String) -> String {
        SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func restore() async {
        #if DEBUG
        if DebugMockAccountStore.isActive {
            signInForPreview()
            return
        }
        #endif
        guard let refreshToken = RefreshTokenKeychain.load() else {
            gate = .signedOut
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            let session: SupabaseSessionResponse = try await authToken(
                grant: "refresh_token", body: ["refresh_token": refreshToken]
            )
            try accept(session)
            try await loadProfile()
        } catch {
            if case AccountServiceError.server(401) = error {
                RefreshTokenKeychain.clear()
                gate = .signedOut
                errorMessage = "登入狀態已過期，請重新使用 Apple 登入。"
            } else {
                // A temporary network or schema error must not erase a valid credential.
                gate = .checking
                errorMessage = error is URLError
                    ? "目前無法連線。請確認網路後重試。"
                    : error.localizedDescription
            }
        }
    }

    #if DEBUG
    func signInForPreview() {
        errorMessage = nil
        do {
            let profile = try DebugMockAccountStore.load()
            isMockSession = true
            DebugMockAccountStore.isActive = true
            userID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
            owner = profile?.owner
            dog = profile?.dog
            dogPhotoData = profile?.photoData
            matchingProfile = profile?.matchingProfile
            gate = profile == nil ? .needsProfile : .ready
        } catch {
            errorMessage = "無法讀取本機模擬資料，請稍後重試。"
            gate = .signedOut
        }
    }
    #endif

    func signIn(with credential: ASAuthorizationAppleIDCredential, nonce: String) async {
        statusMessage = nil
        guard let data = credential.identityToken,
              let identityToken = String(data: data, encoding: .utf8) else {
            errorMessage = AccountServiceError.invalidAppleToken.localizedDescription
            return
        }
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let session: SupabaseSessionResponse = try await authToken(
                grant: "id_token",
                body: ["provider": "apple", "id_token": identityToken, "nonce": nonce]
            )
            try accept(session)
            try await loadProfile()
        } catch {
            errorMessage = error.localizedDescription
            gate = userID == nil ? .signedOut : .checking
        }
    }

    func register(_ payload: RegistrationPayload) async throws {
        guard let userID else { throw AccountServiceError.missingSession }
        #if DEBUG
        if isMockSession {
            let profile = DebugMockProfile(
                owner: RegisteredOwner(nickname: payload.ownerName),
                dog: RegisteredDog(
                    name: payload.dogName,
                    breed: payload.breed == "其他" ? (payload.otherBreed ?? payload.breed) : payload.breed,
                    breedMappingStatus: payload.breed == "其他" ? "pending" : "mapped",
                    size: payload.size,
                    sex: payload.sex,
                    isNeutered: payload.isNeutered,
                    socialStyle: payload.socialStyle,
                    photoPath: "debug-mock-local"
                ),
                photoData: payload.photoData,
                matchingProfile: nil
            )
            try DebugMockAccountStore.save(profile)
            owner = profile.owner
            dog = profile.dog
            dogPhotoData = profile.photoData
            matchingProfile = nil
            gate = .ready
            return
        }
        #endif
        isBusy = true
        defer { isBusy = false }
        // A previous submission may have committed even if its response was lost.
        if (try? await loadProfile()) != nil, gate == .ready { return }
        let photoPath = "\(userID.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
        try await uploadPhoto(payload.photoData, at: photoPath)
        do {
            let body: [String: Any] = [
                "p_nickname": payload.ownerName,
                "p_dog_name": payload.dogName,
                "p_breed": payload.breed,
                "p_other_breed": payload.otherBreed as Any? ?? NSNull(),
                "p_size": payload.size,
                "p_sex": payload.sex,
                "p_is_neutered": payload.isNeutered,
                "p_social_style": payload.socialStyle,
                "p_photo_path": photoPath
            ]
            let _: Data = try await rawRequest(
                "rest/v1/rpc/complete_registration", method: "POST",
                body: try JSONSerialization.data(withJSONObject: body)
            )
            try await loadProfile()
        } catch {
            if (try? await loadProfile()) != nil, gate == .ready { return }
            // Only a definite client-side rejection is safe to clean up. A timed-out
            // response may hide a successful commit, so keep its referenced photo.
            if case AccountServiceError.server(let status) = error,
               (400..<500).contains(status) {
                try? await deletePhoto(at: photoPath)
            }
            throw error
        }
    }

    func saveMatchingProfile(_ details: DogMatchingProfile) async throws {
        guard let userID, let birthDate = details.birthDate,
              !details.activityNeeds.isEmpty,
              !details.activityPreferences.isEmpty,
              let pace = details.firstMeetingPace else {
            throw RegistrationSubmissionError(message: "請完成出生日期、活動需求、活動喜好與初次見面步調。")
        }
        isBusy = true
        defer { isBusy = false }
        #if DEBUG
        if isMockSession {
            guard var profile = try DebugMockAccountStore.load() else {
                throw AccountServiceError.missingSession
            }
            profile.matchingProfile = details
            try DebugMockAccountStore.save(profile)
            matchingProfile = details
            return
        }
        #endif
        let body: [String: Any] = [
            "user_id": userID.uuidString.lowercased(),
            "birth_date": Self.profileDateFormatter.string(from: birthDate),
            "activity_needs": details.activityNeeds,
            "activity_preferences": details.activityPreferences,
            "activity_free_text": details.activityDescription,
            "activity_keywords": details.activityKeywords,
            "meeting_environments": details.meetingEnvironments,
            "first_meeting_pace": pace,
            "interaction_scenario": details.interactionScenario as Any? ?? NSNull(),
            "interaction_features": details.interactionFeatures,
            "health_answers": details.protectionAnswers
        ]
        let _: Data = try await rawRequest(
            "rest/v1/dog_matching_profiles?on_conflict=user_id", method: "POST",
            body: try JSONSerialization.data(withJSONObject: body),
            extraHeaders: ["Prefer": "resolution=merge-duplicates,return=minimal"]
        )
        matchingProfile = details
    }

    func signOut() async {
        #if DEBUG
        if isMockSession {
            DebugMockAccountStore.isActive = false
            isMockSession = false
            userID = nil
            owner = nil
            dog = nil
            dogPhotoData = nil
            matchingProfile = nil
            errorMessage = nil
            gate = .signedOut
            return
        }
        #endif
        if let accessToken {
            let _: Data? = try? await rawRequest(
                "auth/v1/logout?scope=local", method: "POST", body: Data(), bearer: accessToken
            )
        }
        RefreshTokenKeychain.clear()
        accessToken = nil
        userID = nil
        owner = nil
        dog = nil
        dogPhotoData = nil
        matchingProfile = nil
        errorMessage = nil
        gate = .signedOut
    }

    private func accept(_ session: SupabaseSessionResponse) throws {
        try RefreshTokenKeychain.save(session.refreshToken)
        accessToken = session.accessToken
        userID = session.user.id
    }

    private func loadProfile() async throws {
        guard let userID else { throw AccountServiceError.missingSession }
        let id = userID.uuidString.lowercased()
        let owners: [RegisteredOwner] = try await request(
            "rest/v1/owner_profiles?select=nickname&user_id=eq.\(id)&limit=1"
        )
        let dogs: [RegisteredDog] = try await request(
            "rest/v1/dog_profiles?select=name,breed,breed_mapping_status,size,sex,is_neutered,social_style,photo_path&user_id=eq.\(id)&limit=1"
        )
        owner = owners.first
        dog = dogs.first
        if let path = dog?.photoPath {
            dogPhotoData = try await rawRequest(
                "storage/v1/object/authenticated/dog-photos/\(path)", method: "GET"
            )
        } else {
            dogPhotoData = nil
        }
        if dog != nil {
            let profiles: [RegisteredMatchingDetails] = try await request(
                "rest/v1/dog_matching_profiles?select=birth_date,activity_needs,activity_preferences,activity_free_text,activity_keywords,meeting_environments,first_meeting_pace,interaction_scenario,interaction_features,health_answers&user_id=eq.\(id)&limit=1"
            )
            matchingProfile = profiles.first?.local
        } else {
            matchingProfile = nil
        }
        gate = owner != nil && dog != nil ? .ready : .needsProfile
    }

    private func uploadPhoto(_ data: Data, at path: String) async throws {
        let _: Data = try await rawRequest(
            "storage/v1/object/dog-photos/\(path)", method: "POST", body: data,
            contentType: "image/jpeg"
        )
    }

    private func deletePhoto(at path: String) async throws {
        let _: Data = try await rawRequest(
            "storage/v1/object/dog-photos/\(path)", method: "DELETE"
        )
    }

    private func authToken<T: Decodable>(grant: String, body: [String: String]) async throws -> T {
        let data = try JSONSerialization.data(withJSONObject: body)
        return try await request("auth/v1/token?grant_type=\(grant)", method: "POST", body: data)
    }

    private func request<T: Decodable>(
        _ path: String, method: String = "GET", body: Data? = nil
    ) async throws -> T {
        let data = try await rawRequest(path, method: method, body: body)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func rawRequest(
        _ path: String, method: String, body: Data? = nil,
        bearer: String? = nil, contentType: String = "application/json",
        extraHeaders: [String: String] = [:]
    ) async throws -> Data {
        guard let configuration,
              let url = URL(string: path, relativeTo: configuration.projectURL)?.absoluteURL else {
            throw AccountServiceError.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.timeoutInterval = 25
        request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(bearer ?? accessToken ?? configuration.publishableKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        for (key, value) in extraHeaders { request.setValue(value, forHTTPHeaderField: key) }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw AccountServiceError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else {
            if (path.hasPrefix("rest/v1/rpc/") || path.hasPrefix("functions/v1/")), response.statusCode != 401,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                if message.range(of: "[\\u4e00-\\u9fff]", options: .regularExpression) != nil {
                    throw MeetupPreviewError(message: message)
                }
                throw MeetupPreviewError(message: "服務尚未就緒或操作未完成，請重新載入後重試。")
            }
            throw AccountServiceError.server(response.statusCode)
        }
        return data
    }

    func uploadExperiencePhoto(_ bytes: Data) async throws -> String {
        guard let userID else { throw AccountServiceError.missingSession }
        guard bytes.count <= 10_000_000 else { throw MeetupPreviewError(message: "照片不能超過 10 MB。") }
        if usesPreviewAccount { return "preview/\(UUID().uuidString).jpg" }
        let path = "\(userID.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
        _ = try await rawRequest("storage/v1/object/warm-photos/\(path)", method: "POST", body: bytes, contentType: "image/jpeg")
        return path
    }

    func updateOwnProfile(nickname: String, name: String, breed: String, size: String, sex: String,
                          neutered: Bool, reaction: String, photo: Data?) async throws {
        guard let userID, let existing = dog else { throw AccountServiceError.missingSession }
        let nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let breed = breed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nickname.isEmpty, nickname.count <= 60, !name.isEmpty, name.count <= 60, !breed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw MeetupPreviewError(message: "請填寫飼主暱稱、狗狗名字（60 字內）與犬種。")
        }
        #if DEBUG
        if isMockSession {
            let updated = RegisteredDog(name: name, breed: breed, breedMappingStatus: breed == existing.breed ? existing.breedMappingStatus : "pending",
                size: size, sex: sex, isNeutered: neutered, socialStyle: reaction, photoPath: existing.photoPath)
            let profile = DebugMockProfile(owner: RegisteredOwner(nickname: nickname), dog: updated, photoData: photo ?? dogPhotoData ?? Data(), matchingProfile: matchingProfile)
            try DebugMockAccountStore.save(profile)
            owner = profile.owner; dog = updated; dogPhotoData = profile.photoData
            return
        }
        #endif
        var path = existing.photoPath
        if let photo {
            path = "\(userID.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
            try await uploadPhoto(photo, at: path)
        }
        let payload: [String: Any] = ["nickname": nickname, "name": name, "breed": breed, "size": size, "sex": sex,
            "isNeutered": neutered, "socialStyle": reaction, "photoPath": path]
        _ = try await authenticatedData("rest/v1/rpc/update_own_profile", method: "POST", body: JSONSerialization.data(withJSONObject: ["p_data": payload]))
        try await loadProfile()
        if path != existing.photoPath { try? await deletePhoto(at: existing.photoPath) }
    }

    /// Reauthentication is required for real deletion. The server revokes Apple tokens,
    /// removes Storage through its API, then deletes Auth; a 202 response is NOT success.
    func deleteAccount(credential: ASAuthorizationAppleIDCredential? = nil) async throws -> String {
        #if DEBUG
        if isMockSession {
            try DebugMockAccountStore.delete()
            await signOut()
            URLCache.shared.removeAllCachedResponses()
            statusMessage = "本機模擬帳號與資料已刪除。"
            return "deleted"
        }
        #endif
        guard let credential, let code = credential.authorizationCode, let identity = credential.identityToken,
              let codeString = String(data: code, encoding: .utf8), let identityString = String(data: identity, encoding: .utf8) else {
            throw MeetupPreviewError(message: "請使用同一 Apple 帳號重新驗證後刪除。")
        }
        let bytes = try await authenticatedData("functions/v1/delete-account", method: "POST", body: JSONSerialization.data(withJSONObject: ["authorizationCode": codeString, "identityToken": identityString]))
        guard let response = try JSONSerialization.jsonObject(with: bytes) as? [String: Any], let status = response["status"] as? String else { throw AccountServiceError.invalidResponse }
        if status == "deleted" {
            await signOut(); URLCache.shared.removeAllCachedResponses()
            statusMessage = "帳號與相關資料已刪除，Apple 授權已撤銷。"
        } else if status == "pending" {
            await signOut()
            errorMessage = "刪除已受理，帳號已停止使用。部分資料待後台完成清理，請透過 Snoots! 支援信箱查詢處理結果。"
        }
        return status
    }
}
