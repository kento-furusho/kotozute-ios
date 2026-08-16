import SwiftUI

/// サインイン／新規登録。登録はメールとパスワードだけで、表示名は後で聞く。
struct AuthView: View {
    @Bindable var auth: AuthStore

    @State private var isRegistering = false
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 10) {
                Text("ことづて")
                    .font(Theme.font(34, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("いいな、と思ったことを書きためて、\n週に一度ふたりで読む。")
                    .font(Theme.font(15))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            VStack(spacing: 12) {
                field("メールアドレス", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                secureField("パスワード", text: $password)
                    .textContentType(isRegistering ? .newPassword : .password)

                if isRegistering {
                    Text("8文字以上。小文字と数字を含める。")
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.top, 32)

            if let message = auth.errorMessage {
                Text(message)
                    .font(Theme.font(14))
                    .foregroundStyle(Theme.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
            }

            primaryButton
                .padding(.top, 24)

            Button(isRegistering ? "アカウントを持っている" : "はじめて使う") {
                isRegistering.toggle()
                auth.clearError()
            }
            .font(Theme.font(15))
            .foregroundStyle(Theme.inkSoft)
            .padding(.top, 16)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
            && password.count >= 8
            && !auth.isWorking
    }

    private var primaryButton: some View {
        Button {
            Task {
                let trimmed = email.trimmingCharacters(in: .whitespaces)
                if isRegistering {
                    await auth.signUp(email: trimmed, password: password)
                } else {
                    await auth.signIn(email: trimmed, password: password)
                }
            }
        } label: {
            Group {
                if auth.isWorking {
                    ProgressView().tint(.white)
                } else {
                    Text(isRegistering ? "登録する" : "はじめる")
                        .font(Theme.font(17, weight: .bold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canSubmit ? Theme.accent : Theme.inkSoft.opacity(0.4))
            .clipShape(Capsule())
        }
        .disabled(!canSubmit)
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(Theme.font(16))
            .padding(14)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
    }

    private func secureField(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .font(Theme.font(16))
            .padding(14)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
    }
}

/// メールに届いた確認コードの入力。
struct ConfirmView: View {
    @Bindable var auth: AuthStore
    let email: String

    @State private var code = ""
    @State private var password = ""

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 10) {
                Text("確認コード")
                    .font(Theme.font(26, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("\(email) に届いたコードを入れてほしい。")
                    .font(Theme.font(14))
                    .foregroundStyle(Theme.inkSoft)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                TextField("6桁のコード", text: $code)
                    .font(Theme.font(20, weight: .bold))
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .padding(14)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))

                SecureField("パスワード", text: $password)
                    .font(Theme.font(16))
                    .textContentType(.password)
                    .padding(14)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
            }
            .padding(.top, 28)

            if let message = auth.errorMessage {
                Text(message)
                    .font(Theme.font(14))
                    .foregroundStyle(Theme.accent)
                    .padding(.top, 12)
            }

            Button {
                Task { await auth.confirm(email: email, code: code, password: password) }
            } label: {
                Group {
                    if auth.isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text("確認する").font(Theme.font(17, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canSubmit ? Theme.accent : Theme.inkSoft.opacity(0.4))
                .clipShape(Capsule())
            }
            .disabled(!canSubmit)
            .padding(.top, 24)

            Button("コードを送り直す") {
                Task { await auth.resendCode(email: email) }
            }
            .font(Theme.font(15))
            .foregroundStyle(Theme.inkSoft)
            .padding(.top, 16)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }

    private var canSubmit: Bool {
        code.count >= 6 && password.count >= 8 && !auth.isWorking
    }
}
