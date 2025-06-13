import AVFoundation

class SoundPlayer {
    private var audioPlayers: [String: AVAudioPlayer] = [:]

    func playSound(name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }

        if let player = audioPlayers[name] {
            player.currentTime = 0
            player.play()
        } else {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                audioPlayers[name] = player
                player.play()
            } catch {
                print("Error playing sound: \(error)")
            }
        }
    }
}
