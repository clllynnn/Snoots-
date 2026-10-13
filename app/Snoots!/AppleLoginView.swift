import AuthenticationServices
import SwiftUI

struct AppleLoginView: View {
    let account: SnootsAccountSession
    @State private var nonce = ""

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image("LaunchLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 92, height: 92)
                .accessibilityHidden(true)
            Text("歡迎來到 Snoots!")
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
            Text("從認識彼此開始，找到舒服的狗友步調。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            if account.isBusy {
                ProgressView("正在使用 Apple 登入…")
                    .frame(minHeight: 50)
            } else {
                SignInWithAppleButton(.signIn) { request in
                    nonce = SnootsAccountSession.newNonce()
                    request.requestedScopes = [.email]
                    request.nonce = SnootsAccountSession.hashedNonce(nonce)
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                            account.errorMessage = "Apple 登入資料無法讀取，請重試。"
                            return
                        }
                        Task { await account.signIn(with: credential, nonce: nonce) }
                    case .failure(let error):
                        let code = (error as NSError).code
                        if code != ASAuthorizationError.canceled.rawValue {
                            account.errorMessage = "Apple 登入未完成，請稍後重試。"
                        }
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityLabel("使用 Apple 登入")
            }
            #if DEBUG
            Button("模擬登入（本機測試）") {
                account.signInForPreview()
            }
            .buttonStyle(.bordered)
            .frame(minHeight: 44)
            Text("模擬帳號資料只儲存在本機，不會建立 Apple 或 Supabase 帳號。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            #endif
            if let errorMessage = account.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let statusMessage = account.statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle").font(.footnote).foregroundStyle(.secondary)
            }
            Link("Apple 隱私權政策", destination: URL(string: "https://www.apple.com/tw/legal/privacy/tzh/")!)
                .font(.footnote)
                .frame(minHeight: 44)
            if let url = SnootsPolicy.publicURL {
                Link("Snoots! 隱私權政策", destination: url).font(.footnote).frame(minHeight: 44)
            } else {
                Text("Snoots! 隱私權政策連結待提供").font(.footnote).foregroundStyle(.secondary)
            }
            Spacer(minLength: 16)
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SnootsPalette.canvas.ignoresSafeArea())
    }
}

enum SnootsPolicy {
    static var publicURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "SnootsPrivacyPolicyURL") as? String,
              !value.contains("$("), let url = URL(string: value), url.scheme == "https",
              let host = url.host, host != "apple.com", !host.hasSuffix(".apple.com") else { return nil }
        return url
    }
}
