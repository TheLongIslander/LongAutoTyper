import Foundation

struct TypingFocusState: Sendable {
    let isFocused: Bool
    let targetAppName: String?
}

enum TypingUpdate: Sendable {
    case countdown(Int)
    case started(totalCharacters: Int)
    case paused(targetAppName: String?)
    case resumed(targetAppName: String?)
    case progress(typed: Int, total: Int)
    case completed
    case stopped
    case failed(String)
}

actor TypingEngine {
    private var typingTask: Task<Void, Never>?

    func start(
        text: String,
        delayPerCharacter: Double,
        countdownSeconds: Int,
        initialDelaySeconds: Double = 0,
        focusStateProvider: @escaping @Sendable @MainActor () -> TypingFocusState,
        onUpdate: @escaping @Sendable @MainActor (TypingUpdate) -> Void
    ) {
        typingTask?.cancel()

        typingTask = Task {
            let safeDelay = max(0, delayPerCharacter)
            let safeCountdown = max(0, countdownSeconds)
            let safeInitialDelay = max(0, initialDelaySeconds)
            let characters = Array(text)

            if safeCountdown > 0 {
                for secondsLeft in stride(from: safeCountdown, through: 1, by: -1) {
                    if Task.isCancelled {
                        await onUpdate(.stopped)
                        return
                    }
                    await onUpdate(.countdown(secondsLeft))
                    do {
                        try await Task.sleep(for: .seconds(1))
                    } catch {
                        await onUpdate(.stopped)
                        return
                    }
                }
            }

            if Task.isCancelled {
                await onUpdate(.stopped)
                return
            }

            if safeInitialDelay > 0 {
                do {
                    try await Task.sleep(for: .seconds(safeInitialDelay))
                } catch {
                    await onUpdate(.stopped)
                    return
                }
            }

            let canStartTyping = await waitForFocusIfNeeded(
                focusStateProvider: focusStateProvider,
                onUpdate: onUpdate
            )
            if !canStartTyping {
                return
            }

            await onUpdate(.started(totalCharacters: characters.count))

            var typed = 0
            for character in characters {
                if Task.isCancelled {
                    await onUpdate(.stopped)
                    return
                }

                let canContinueTyping = await waitForFocusIfNeeded(
                    focusStateProvider: focusStateProvider,
                    onUpdate: onUpdate
                )
                if !canContinueTyping {
                    return
                }

                let success = KeyEventTyper.type(character: character)
                if !success {
                    await onUpdate(.failed("Could not emit keyboard event."))
                    return
                }

                typed += 1
                await onUpdate(.progress(typed: typed, total: characters.count))

                if safeDelay > 0 {
                    do {
                        try await Task.sleep(for: .seconds(safeDelay))
                    } catch {
                        await onUpdate(.stopped)
                        return
                    }
                }
            }

            await onUpdate(.completed)
        }
    }

    func stop() {
        typingTask?.cancel()
        typingTask = nil
    }

    private func waitForFocusIfNeeded(
        focusStateProvider: @escaping @Sendable @MainActor () -> TypingFocusState,
        onUpdate: @escaping @Sendable @MainActor (TypingUpdate) -> Void
    ) async -> Bool {
        var wasPaused = false
        var targetAppName: String?

        while true {
            if Task.isCancelled {
                await onUpdate(.stopped)
                return false
            }

            let focusState = await focusStateProvider()
            targetAppName = focusState.targetAppName

            if focusState.isFocused {
                break
            }

            if !wasPaused {
                wasPaused = true
                await onUpdate(.paused(targetAppName: targetAppName))
            }

            do {
                try await Task.sleep(for: .milliseconds(120))
            } catch {
                await onUpdate(.stopped)
                return false
            }
        }

        if wasPaused {
            await onUpdate(.resumed(targetAppName: targetAppName))
        }

        return true
    }
}
