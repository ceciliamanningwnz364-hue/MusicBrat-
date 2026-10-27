import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var player = AudioPlayerManager.shared
    @State private var showImporter = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color(red: 0.1, green: 0.05, blue: 0.2), Color(red: 0.2, green: 0.1, blue: 0.3), Color(red: 0.05, green: 0.1, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
                
                VStack(spacing: 30) {
                    if player.currentTrack != nil {
                        PlayerView()
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "waveform.circle").font(.system(size: 80)).foregroundStyle(.white.opacity(0.6))
                            Text("Добавь первый трек").font(.title3).foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    
                    Button { showImporter = true } label: {
                        Label("Добавить трек", systemImage: "plus.circle.fill")
                            .font(.headline).padding(.horizontal, 28).padding(.vertical, 14)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.2), lineWidth: 0.5))
                    }
                }.padding()
            }
            .navigationTitle("Aura Player")
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.audio]) { result in
                if case .success(let url) = result { player.play(url: url) }
            }
        }
    }
}
