import SwiftUI

struct ContentView: View {
    @StateObject private var strobeController = StrobeController()
    @Environment(\.scenePhase) private var scenePhase

    /// Screen background: black while off, mustard while strobing.
    private var backgroundColor: Color {
        strobeController.isStrobing ? .mustard : .black
    }

    /// Label/Picker text color: kept as the inverse of the background for contrast.
    private var contentColor: Color {
        strobeController.isStrobing ? .black : .mustard
    }

    /// Button fill: inverse of the background, so it always stands out.
    private var buttonBackgroundColor: Color {
        strobeController.isStrobing ? .black : .mustard
    }

    /// Button label: inverse of the button fill.
    private var buttonForegroundColor: Color {
        strobeController.isStrobing ? .mustard : .black
    }

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Text("\(strobeController.frequencyHz) Hz")
                    .font(.title2.bold())
                    .foregroundStyle(contentColor)

                Picker("Frequency", selection: $strobeController.frequencyHz) {
                    ForEach(1...50, id: \.self) { hz in
                        Text("\(hz) Hz")
                            .foregroundStyle(contentColor)
                            .tag(hz)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxHeight: 150)

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        if strobeController.isStrobing {
                            strobeController.stop()
                        } else {
                            strobeController.start()
                        }
                    }
                } label: {
                    Text(strobeController.isStrobing ? "OFF" : "ON")
                        .font(.title.bold())
                        .foregroundStyle(buttonForegroundColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(buttonBackgroundColor)
                        .clipShape(Capsule())
                }
                .disabled(!strobeController.isTorchAvailable)

                if let errorMessage = strobeController.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                } else if !strobeController.isTorchAvailable {
                    Text("Torch is not available on this device.")
                        .font(.footnote)
                        .foregroundStyle(contentColor.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(32)
        }
        // Colors are fixed by app state, not by the system appearance —
        // pin the color scheme so system controls (like the wheel picker)
        // never fight the mustard/black palette.
        .preferredColorScheme(strobeController.isStrobing ? .light : .dark)
        .animation(.easeInOut(duration: 0.25), value: strobeController.isStrobing)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                strobeController.stop()
            }
        }
    }
}

#Preview {
    ContentView()
}
