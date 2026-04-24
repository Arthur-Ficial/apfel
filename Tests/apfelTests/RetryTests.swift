// ============================================================================
// RetryTests.swift — Tests for retry logic: isRetryableError + withRetry
// Part of apfel test suite
// ============================================================================

import Foundation
import ApfelCore

// MARK: - isRetryableError Tests

func runRetryTests() {

    // ---- isRetryableError using ApfelError.classify() ----

    test("isRetryableError: rateLimited ApfelError is retryable") {
        try assertTrue(isRetryableError(ApfelError.rateLimited))
    }

    test("isRetryableError: concurrentRequest ApfelError is retryable") {
        try assertTrue(isRetryableError(ApfelError.concurrentRequest))
    }

    test("isRetryableError: assetsUnavailable ApfelError is retryable") {
        try assertTrue(isRetryableError(ApfelError.assetsUnavailable))
    }

    test("isRetryableError: guardrailViolation is NOT retryable") {
        try assertTrue(!isRetryableError(ApfelError.guardrailViolation))
    }

    test("isRetryableError: contextOverflow is NOT retryable") {
        try assertTrue(!isRetryableError(ApfelError.contextOverflow))
    }

    test("isRetryableError: unsupportedLanguage is NOT retryable") {
        try assertTrue(!isRetryableError(ApfelError.unsupportedLanguage("Klingon")))
    }

    test("isRetryableError: toolExecution is NOT retryable") {
        try assertTrue(!isRetryableError(ApfelError.toolExecution("tool failed")))
    }

    test("isRetryableError: unknown error is NOT retryable") {
        try assertTrue(!isRetryableError(ApfelError.unknown("something happened")))
    }

    // ---- Locale-independent error detection ----
    // The model supports: en, es, de, fr, pt, it, zh, ko, nl, da, nb, vi, tr, ja, sv
    // Test that error classification works regardless of the localizedDescription language.

    let localeTests: [(lang: String, rateLimitedMsg: String, concurrentMsg: String)] = [
        ("en", "Rate limited. Try again later.", "Too many concurrent requests."),
        ("de", "Ratenbegrenzung. Versuchen Sie es spaeter erneut.", "Zu viele gleichzeitige Anfragen."),
        ("fr", "Limite de debit atteinte. Reessayez plus tard.", "Trop de requetes simultanees."),
        ("es", "Limite de velocidad. Intentalo mas tarde.", "Demasiadas solicitudes simultaneas."),
        ("pt", "Limite de taxa. Tente novamente mais tarde.", "Muitas solicitacoes simultaneas."),
        ("it", "Limite di velocita. Riprova piu tardi.", "Troppe richieste simultanee."),
        ("zh", "速率受限。请稍后重试。", "并发请求过多。"),
        ("ko", "속도 제한. 나중에 다시 시도하세요.", "동시 요청이 너무 많습니다."),
        ("nl", "Snelheidslimiet bereikt. Probeer later opnieuw.", "Te veel gelijktijdige verzoeken."),
        ("da", "Hastighedsgraense naaet. Proev igen senere.", "For mange samtidige anmodninger."),
        ("nb", "Hastighetsgrense naadd. Proev igjen senere.", "For mange samtidige foresporsler."),
        ("vi", "Gioi han toc do. Vui long thu lai sau.", "Qua nhieu yeu cau dong thoi."),
        ("tr", "Hiz siniri asildi. Daha sonra tekrar deneyin.", "Cok fazla esanli istek."),
        ("ja", "レート制限。後でもう一度お試しください。", "同時リクエストが多すぎます。"),
        ("sv", "Hastighetsbegransning. Forsok igen senare.", "For manga samtidiga forfraaningar."),
    ]

    for lt in localeTests {
        test("isRetryableError: rateLimited detected on \(lt.lang) locale") {
            // GenerationError.rateLimited — the mirror string has "rateLimited" regardless of locale
            let err = FoundationModelsGenerationErrorStub(caseName: "rateLimited", localizedMsg: lt.rateLimitedMsg)
            let classified = ApfelError.classify(err)
            try assertEqual(classified, .rateLimited, "locale=\(lt.lang)")
            try assertTrue(isRetryableError(err), "isRetryableError should be true for \(lt.lang) rateLimited")
        }

        test("isRetryableError: concurrentRequests detected on \(lt.lang) locale") {
            let err = FoundationModelsGenerationErrorStub(caseName: "concurrentRequests", localizedMsg: lt.concurrentMsg)
            let classified = ApfelError.classify(err)
            try assertEqual(classified, .concurrentRequest, "locale=\(lt.lang)")
            try assertTrue(isRetryableError(err), "isRetryableError should be true for \(lt.lang) concurrentRequests")
        }
    }

    // ---- Non-retryable errors on non-English locales ----

    test("isRetryableError: guardrailViolation NOT retryable on German locale") {
        let err = FoundationModelsGenerationErrorStub(
            caseName: "guardrailViolation",
            localizedMsg: "Inhaltsrichtlinie verletzt"
        )
        try assertTrue(!isRetryableError(err))
    }

    test("isRetryableError: exceededContextWindowSize NOT retryable on Japanese locale") {
        let err = FoundationModelsGenerationErrorStub(
            caseName: "exceededContextWindowSize",
            localizedMsg: "コンテキストウィンドウサイズを超えました"
        )
        try assertTrue(!isRetryableError(err))
    }

    test("isRetryableError: unsupportedLanguageOrLocale NOT retryable on Chinese locale") {
        let err = FoundationModelsGenerationErrorStub(
            caseName: "unsupportedLanguageOrLocale",
            localizedMsg: "不支持的语言或区域设置"
        )
        try assertTrue(!isRetryableError(err))
    }

    test("isRetryableError: assetsUnavailable GenerationError is retryable") {
        let err = FoundationModelsGenerationErrorStub(
            caseName: "assetsUnavailable",
            localizedMsg: "Model assets are still loading"
        )
        try assertEqual(ApfelError.classify(err), .assetsUnavailable)
        try assertTrue(isRetryableError(err))
    }

    // ---- withRetry tests ----

    testAsync("withRetry: succeeds on first attempt, no retry") {
        nonisolated(unsafe) var attempts = 0
        let result = try await withRetry(maxRetries: 3) {
            attempts += 1
            return "success"
        }
        try assertEqual(result, "success")
        try assertEqual(attempts, 1, "should succeed on first attempt")
    }

    testAsync("withRetry: retries on retryable error then succeeds") {
        nonisolated(unsafe) var attempts = 0
        let result: String = try await withRetry(maxRetries: 3, delays: [0.01, 0.01, 0.01]) {
            attempts += 1
            if attempts < 3 {
                throw ApfelError.rateLimited
            }
            return "recovered"
        }
        try assertEqual(result, "recovered")
        try assertEqual(attempts, 3, "should take 3 attempts")
    }

    testAsync("withRetry: does NOT retry on non-retryable error") {
        nonisolated(unsafe) var attempts = 0
        do {
            let _: String = try await withRetry(maxRetries: 3, delays: [0.01, 0.01, 0.01]) {
                attempts += 1
                throw ApfelError.guardrailViolation
            }
            throw TestFailure("should have thrown")
        } catch {
            let classified = ApfelError.classify(error)
            try assertEqual(classified, .guardrailViolation)
            try assertEqual(attempts, 1, "should NOT retry non-retryable errors")
        }
    }

    testAsync("withRetry: respects maxRetries count") {
        nonisolated(unsafe) var attempts = 0
        do {
            let _: String = try await withRetry(maxRetries: 2, delays: [0.01, 0.01]) {
                attempts += 1
                throw ApfelError.rateLimited
            }
            throw TestFailure("should have thrown")
        } catch {
            // maxRetries=2 means: 1 initial + 2 retries = 3 total attempts
            try assertEqual(attempts, 3, "1 initial + 2 retries = 3 total")
        }
    }

    testAsync("withRetry: stops after successful attempt") {
        nonisolated(unsafe) var attempts = 0
        let result: String = try await withRetry(maxRetries: 5, delays: [0.01, 0.01, 0.01, 0.01, 0.01]) {
            attempts += 1
            if attempts == 2 {
                return "ok"
            }
            throw ApfelError.concurrentRequest
        }
        try assertEqual(result, "ok")
        try assertEqual(attempts, 2, "should stop at attempt 2")
    }

    testAsync("withRetry disabled: passthrough returns result directly") {
        // When retry is disabled (retryEnabled=false), the function should be a no-op wrapper.
        // This tests the concept that without --retry, behavior is identical.
        nonisolated(unsafe) var attempts = 0
        let result: String = try await withRetry(maxRetries: 0) {
            attempts += 1
            return "direct"
        }
        try assertEqual(result, "direct")
        try assertEqual(attempts, 1)
    }

    testAsync("withRetry disabled: error passes through without retry") {
        nonisolated(unsafe) var attempts = 0
        do {
            let _: String = try await withRetry(maxRetries: 0) {
                attempts += 1
                throw ApfelError.rateLimited
            }
            throw TestFailure("should have thrown")
        } catch {
            try assertEqual(attempts, 1, "maxRetries=0 means no retries, just the initial attempt")
        }
    }

    testAsync("withRetry: concurrentRequest error triggers retry") {
        nonisolated(unsafe) var attempts = 0
        let result: String = try await withRetry(maxRetries: 3, delays: [0.01, 0.01, 0.01]) {
            attempts += 1
            if attempts < 2 {
                throw ApfelError.concurrentRequest
            }
            return "ok"
        }
        try assertEqual(result, "ok")
        try assertEqual(attempts, 2)
    }

    testAsync("withRetry: contextOverflow error does NOT trigger retry") {
        nonisolated(unsafe) var attempts = 0
        do {
            let _: String = try await withRetry(maxRetries: 3, delays: [0.01, 0.01, 0.01]) {
                attempts += 1
                throw ApfelError.contextOverflow
            }
            throw TestFailure("should have thrown")
        } catch {
            try assertEqual(attempts, 1, "contextOverflow should not be retried")
        }
    }
}
