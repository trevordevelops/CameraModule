//
//  GalleryView.swift
//  CameraModule
//
//  Created by Trevor Welsh on 9/3/22.
//

import SwiftUI
import AVKit

struct GalleryView: View {
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "capturedDate", ascending: false)]) var capturedMedias: FetchedResults<CapturedMedia>
    @State private var selectedMediaIndex: Int = 0
    @State private var showMediaFSV: Bool = false
    private let spacing: CGFloat = 15
    private let squareSpacing: CGFloat = 3
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                GeometryReader { geo in
                    let squareSize = geo.size.width / 3
                    let previewFrame = CGSize(width: geo.size.width, height: geo.size.width / (3 / 4))
                    
                    Color.black.ignoresSafeArea()
                    VStack(alignment: .center, spacing: spacing) {
                        Capsule()
                            .fill(Color.gray)
                            .frame(width: 60, height: 4)
                            .padding(spacing)
                        ScrollView(.vertical, showsIndicators: true) {
                            if capturedMedias.isEmpty {
                                VStack(alignment: .center, spacing: spacing) {
                                    Spacer()
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 56))
                                    Text("Any photos or videos you capture will appear here.")
                                        .font(.body)
                                        .multilineTextAlignment(.center)
                                        .padding(spacing * 2)
                                    Spacer()
                                    Spacer()
                                }
                                .foregroundColor(.white)
                                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                            } else {
                                LazyVGrid(columns: [GridItem(), GridItem(), GridItem()], alignment: .leading, spacing: squareSpacing) {
                                    ForEach(capturedMedias.indices, id: \.self) { index in
                                        let media = capturedMedias[index]
                                        Button {
                                            selectedMediaIndex = index
                                            showMediaFSV = true
                                        } label: {
                                            if let data = media.image, let uiImage = UIImage(data: data) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: squareSize, height: squareSize)
                                                    .clipShape(Rectangle())
                                                    .overlay(
                                                        ZStack {
                                                            if media.videoPath != nil {
                                                                Image(systemName: "play.fill")
                                                                    .font(.system(size: 30))
                                                                    .foregroundColor(.white)
                                                                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 0)
                                                            }
                                                        }
                                                    )
                                            } else {
                                                Rectangle()
                                                    .fill(Color.gray)
                                                    .frame(width: squareSize, height: squareSize)
                                            }
                                        }
                                    }
                                }
                                .navigationDestination(isPresented: $showMediaFSV) {
                                    MediaFSView(selectedMediaIndex: $selectedMediaIndex, showMediaFSV: $showMediaFSV, capturedMedias: capturedMedias, previewFrame: previewFrame, geo: geo)
                                }
                            }
                        }
                    }
                }
                .navigationBarHidden(true)
            }
        } else {
            NavigationView {
                GeometryReader { geo in
                    let squareSize = geo.size.width / 3
                    let previewFrame = CGSize(width: geo.size.width, height: geo.size.width / (3 / 4))
                    
                    Color.black.ignoresSafeArea()
                    VStack(alignment: .center, spacing: spacing) {
                        Capsule()
                            .fill(Color.gray)
                            .frame(width: 60, height: 4)
                            .padding(spacing)
                        ScrollView(.vertical, showsIndicators: true) {
                            if capturedMedias.isEmpty {
                                VStack(alignment: .center, spacing: spacing) {
                                    Spacer()
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 56))
                                    Text("Any photos or videos you capture will appear here.")
                                        .font(.body)
                                        .multilineTextAlignment(.center)
                                        .padding(spacing * 2)
                                    Spacer()
                                    Spacer()
                                }
                                .foregroundColor(.white)
                                .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                            } else {
                                LazyVGrid(columns: [GridItem(), GridItem(), GridItem()], alignment: .leading, spacing: squareSpacing) {
                                    ForEach(capturedMedias.indices, id: \.self) { index in
                                        let media = capturedMedias[index]
                                        Button {
                                            selectedMediaIndex = index
                                            showMediaFSV = true
                                        } label: {
                                            if let data = media.image, let uiImage = UIImage(data: data) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: squareSize, height: squareSize)
                                                    .clipShape(Rectangle())
                                                    .overlay(
                                                        ZStack {
                                                            if media.videoPath != nil {
                                                                Image(systemName: "play.fill")
                                                                    .font(.system(size: 30))
                                                                    .foregroundColor(.white)
                                                                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 0)
                                                            }
                                                        }
                                                    )
                                            } else {
                                                Rectangle()
                                                    .fill(Color.gray)
                                                    .frame(width: squareSize, height: squareSize)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    NavigationLink(isActive: $showMediaFSV) {
                        MediaFSView(selectedMediaIndex: $selectedMediaIndex, showMediaFSV: $showMediaFSV, capturedMedias: capturedMedias, previewFrame: previewFrame, geo: geo)
                    } label: {
                        EmptyView()
                    }

                }
                .navigationBarHidden(true)
            }
        }
    }
}

struct MediaFSView: View {
    @EnvironmentObject var cvm: CameraViewModel
    @State private var avPlayer: AVPlayer? = nil
    @Binding var selectedMediaIndex: Int
    @Binding var showMediaFSV: Bool
    public let capturedMedias: FetchedResults<CapturedMedia>
    public let previewFrame: CGSize
    public let geo: GeometryProxy
    private let spacing: CGFloat = 15
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TabView(selection: $selectedMediaIndex) {
                ForEach(capturedMedias.indices, id: \.self) { index in
                    mediaView
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            
            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(content: {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showMediaFSV = false
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 22).bold())
                        .foregroundColor(.white)
                }
            }
        })
    }
    
    private var mediaView: some View {
        VStack {
            Spacer()
            if let media = capturedMedias[selectedMediaIndex], let imageData = media.image, let uiImage = UIImage(data: imageData) {
                if let avPlayer = avPlayer {
//                    AVPlayerController(player: avPlayer)
                    VideoPlayer(player: avPlayer)
//                    CustomVideoPlayer(player: Binding($avPlayer)!)
                        .frame(width: previewFrame.width, height: previewFrame.height)
                } else {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: previewFrame.width, height: previewFrame.height)
                }
            }
            Spacer()
            Spacer()
        }
        .frame(width: previewFrame.width, height: previewFrame.height)
        .onAppear(perform: onAppear)
        .onChange(of: selectedMediaIndex) { _ in
            guard avPlayer != nil else { return }
            avPlayer?.pause()
        }
    }
    
    private func onAppear() {
        let media = capturedMedias[selectedMediaIndex]
        guard let videoPath = media.videoPath else { return }
        let fileURL = cvm.getDocumentsDirectory().appendingPathComponent(videoPath)
        avPlayer = AVPlayer(url: fileURL)
    }
}

struct AVPlayerController: UIViewControllerRepresentable {
    public var player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) { }
}

