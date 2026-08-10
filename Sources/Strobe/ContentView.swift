import SwiftUI

struct ContentView: View {
    @StateObject private var strobeController = StrobeController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Частота: \(strobeController.frequencyHz) Гц")
                    .font(.headline)

                Picker("Частота", selection: $strobeController.frequencyHz) {
                    ForEach(1...50, id: \.self) { hz in
                        Text("\(hz) Гц").tag(hz)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxHeight: 150)
                .disabled(strobeController.isStrobing)

                Button {
                    if strobeController.isStrobing {
                        strobeController.stop()
                    } else {
                        strobeController.start()
                    }
                } label: {
                    Text(strobeController.isStrobing ? "Выключить" : "Включить")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(strobeController.isStrobing ? Color.red : Color.blue)
                        .clipShape(Capsule())
                }
                .disabled(!strobeController.isTorchAvailable)

                if let errorMessage = strobeController.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else if !strobeController.isTorchAvailable {
                    Text("На этом устройстве недоступен фонарик.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
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
