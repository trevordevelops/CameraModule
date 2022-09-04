//
//  CustomVideoPlayer.swift
//  CameraModule
//
//  Created by Trevor Welsh on 9/3/22.
//

import SwiftUI
import AVKit

struct CustomVideoPlayer: UIViewControllerRepresentable {
    @EnvironmentObject var cvm: CameraViewModel
    @Binding var player: AVPlayer
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = self.player
        controller.showsPlaybackControls = false
        controller.videoGravity = self.cvm.videoGravity
        controller.player?.volume = 1.0
        self.player.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(context.coordinator.restartPlayback), name: .AVPlayerItemDidPlayToEndTime, object: self.player.currentItem)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) { }
    
    class Coordinator: NSObject {
        public var parent: CustomVideoPlayer
        init(_ parent: CustomVideoPlayer) {
            self.parent = parent
        }
        
        @objc func restartPlayback () {
            self.parent.player.seek(to: .zero)
        }
    }
}
