import Testing
@testable import BirdSTT

@Suite("App State Tests")
struct AppStateTests {
    @Test("initial state is idle")
    func initialState() {
        #expect(AppState.idle == AppState.idle)
    }

    @Test("all states are equatable")
    func statesEquatable() {
        let states: [AppState] = [.idle, .connecting, .recording, .stopping, .done, .error("test")]
        for (i, a) in states.enumerated() {
            for (j, b) in states.enumerated() {
                if i == j {
                    #expect(a == b)
                } else {
                    #expect(a != b)
                }
            }
        }
    }

    @Test("valid transitions")
    func validTransitions() {
        #expect(AppState.idle.canTransition(to: .connecting))
        #expect(AppState.connecting.canTransition(to: .recording))
        #expect(AppState.connecting.canTransition(to: .error("fail")))
        #expect(AppState.recording.canTransition(to: .stopping))
        #expect(AppState.recording.canTransition(to: .error("fail")))
        #expect(AppState.stopping.canTransition(to: .done))
        #expect(AppState.stopping.canTransition(to: .error("fail")))
        #expect(AppState.done.canTransition(to: .idle))
        #expect(AppState.error("x").canTransition(to: .idle))
    }

    @Test("invalid transitions")
    func invalidTransitions() {
        #expect(!AppState.idle.canTransition(to: .recording))
        #expect(!AppState.idle.canTransition(to: .done))
        #expect(!AppState.recording.canTransition(to: .idle))
        #expect(!AppState.done.canTransition(to: .recording))
    }
}
