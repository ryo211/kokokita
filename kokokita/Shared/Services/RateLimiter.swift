//
//  RateLimiter.swift
//  kokokita
//
//  Created on 2025/10/31.
//

import Foundation

/// レート制限を管理するActor
/// 複数の非同期呼び出しに対してスレッドセーフな最小間隔制御を提供
actor RateLimiter {

    /// 最小リクエスト間隔（秒）
    private let minimumInterval: TimeInterval

    /// 前回のリクエスト時刻
    private var lastRequestTime: Date?

    /// 初期化
    /// - Parameter minimumInterval: 最小リクエスト間隔（秒）
    init(minimumInterval: TimeInterval) {
        self.minimumInterval = minimumInterval
    }

    /// リクエストを待機し、必要に応じてレート制限を適用
    /// この関数を呼び出すと、前回のリクエストから最小間隔が経過していない場合は待機する
    func waitIfNeeded() async throws {
        if let lastTime = lastRequestTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            if elapsed < minimumInterval {
                let waitDuration = minimumInterval - elapsed
                try await Task.sleep(nanoseconds: UInt64(waitDuration * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
    }

    /// リセット（主にテスト用）
    func reset() {
        lastRequestTime = nil
    }
}
