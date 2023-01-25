//
// TotpManager.swift
// Proton Pass - Created on 25/01/2023.
// Copyright (c) 2023 Proton Technologies AG
//
// This file is part of Proton Pass.
//
// Proton Pass is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Pass is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Pass. If not, see https://www.gnu.org/licenses/.

import Core
import SwiftOTP
import SwiftUI
import UIComponents

enum TotpState: Equatable {
    case empty
    case valid(TotpData)
    case invalid
}

struct TotpData: Equatable {
    let code: String
    let timerData: OTPCircularTimerData
}

extension OTPComponents.Algorithm {
    var otpAlgorithm: OTPAlgorithm {
        switch self {
        case .sha1:
            return .sha1
        case .sha256:
            return .sha256
        case .sha512:
            return .sha512
        }
    }
}

final class TotpManager: DeinitPrintable, ObservableObject {
    deinit {
        timer?.invalidate()
        print(deinitMessage)
    }

    private var timer: Timer?
    private let logger: Logger

    @Published private(set) var state = TotpState.empty

    init(logManager: LogManager) {
        self.logger = .init(subsystem: Bundle.main.bundleIdentifier ?? "",
                            category: "\(Self.self)",
                            manager: logManager)
    }

    func bind(uri: String) {
        timer?.invalidate()
        guard !uri.isEmpty else {
            state = .empty
            return
        }

        do {
            let otpComponents = try URLUtils.OTPParser.parse(urlString: uri)
            guard otpComponents.type == .totp else {
                state = .invalid
                return
            }
            guard let secretData = base32DecodeToData(otpComponents.secret) else {
                state = .invalid
                return
            }

            guard let totp = TOTP(secret: secretData,
                                  digits: Int(otpComponents.digits),
                                  timeInterval: Int(otpComponents.period),
                                  algorithm: otpComponents.algorithm.otpAlgorithm) else {
                state = .invalid
                return
            }
            beginCaculating(totp: totp)
        } catch {
            logger.error(error)
            state = .invalid
        }
    }

    func getCurrentCode() -> String? {
        switch state {
        case .valid(let data):
            return data.code
        default:
            return nil
        }
    }
}

private extension TotpManager {
    func beginCaculating(totp: TOTP) {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            let timeInterval = Int(Date().timeIntervalSince1970)
            let remainingSeconds = totp.timeInterval - (timeInterval % totp.timeInterval)
            let code = totp.generate(secondsPast1970: timeInterval) ?? ""
            let timerData = OTPCircularTimerData(total: totp.timeInterval,
                                                 remaining: remainingSeconds)
            self?.state = .valid(.init(code: code, timerData: timerData))
        }
    }
}
