import SwiftUI

struct SettingsView: View {
    @Binding var sensitivity: Double
    @Binding var playsBirthdaySong: Bool
    @Environment(\.dismiss) private var dismiss

    init(sensitivity: Binding<Double>, playsBirthdaySong: Binding<Bool>) {
        _sensitivity = sensitivity
        _playsBirthdaySong = playsBirthdaySong
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Slider(value: $sensitivity, in: 0...1) {
                        Text("吹气灵敏度")
                    } minimumValueLabel: {
                        Text("用力吹")
                    } maximumValueLabel: {
                        Text("轻轻吹")
                    }
                    .font(.footnote)
                } header: {
                    Text("吹气灵敏度")
                } footer: {
                    Text("吹不灭就往右调；说话、唱歌就把蜡烛吹灭了，就往左调。iPhone 的麦克风在机身底部，对着底部吹最灵敏。")
                }

                Section {
                    Toggle("吹灭后播放生日歌", isOn: $playsBirthdaySong)
                } footer: {
                    Text("手机开着静音时不会出声。")
                }

                Section {
                    Text("麦克风只用来感应你有没有在吹气，声音不会被录下或保存。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}
