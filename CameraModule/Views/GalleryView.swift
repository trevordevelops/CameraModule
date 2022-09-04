//
//  GalleryView.swift
//  CameraModule
//
//  Created by Trevor Welsh on 9/3/22.
//

import SwiftUI
import AVFoundation

struct GalleryView: View {
    @FetchRequest(sortDescriptors: [NSSortDescriptor(key: "capturedDate", ascending: false)]) var capturedMedias: FetchedResults<CapturedMedia>
    @State private var selectedMediaIndex: Int = 0
    @State private var showSelectedMedia: Bool = false
    private let spacing: CGFloat = 15
    private let squareSpacing: CGFloat = 3
    var body: some View {
        NavigationView {
            GeometryReader { geo in
                let squareSize = geo.size.width / 3
                
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
                            }
                            .foregroundColor(.white)
                        } else {
                            LazyVGrid(columns: [GridItem(), GridItem(), GridItem()], alignment: .leading, spacing: squareSpacing) {
                                ForEach(capturedMedias.indices, id: \.self) { index in
                                    let media = capturedMedias[index]
                                    Button {
                                        selectedMediaIndex = index
                                        showSelectedMedia = true
                                    } label: {
                                        if let data = media.image, let uiImage = UIImage(data: data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: squareSize, height: squareSize)
                                                .clipShape(Rectangle())
                                                .overlay(
                                                    ZStack {
                                                        if media.movie != nil {
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
                
                NavigationLink(isActive: $showSelectedMedia) {
                    tabViewGallery
                } label: {
                    EmptyView()
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private var tabViewGallery: some View {
        ZStack(alignment: .center) {
            TabView(selection: $selectedMediaIndex) {
                ForEach(capturedMedias.indices, id: \.self) { index in
                    MediaView(media: capturedMedias[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }
}

struct MediaView: View {
    @State private var avPlayer: AVPlayer? = nil
    public let media: CapturedMedia
    var body: some View {
        if let movieData = media.movie, let imageData = media.image, let uiImage = UIImage(data: imageData) {
            if avPlayer != nil {
                CustomVideoPlayer(player: Binding($avPlayer)!)
            } else {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .overlay(
                        Button(action: {
                            guard let url = URL(dataRepresentation: movieData, relativeTo: nil) else { return }
                            avPlayer = AVPlayer(url: url)
                            avPlayer?.play()
                        }, label: {
                            Image(systemName: "play.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 0)
                        })
                    )
            }
        } else if let data = media.image, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}
