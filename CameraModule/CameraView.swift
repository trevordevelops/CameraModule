//
//  ContentView.swift
//  CameraModule
//
//  Created by Trevor Welsh on 9/2/22.
//

import SwiftUI
import AVFoundation
import AVKit

struct CameraView: View {
    @EnvironmentObject var cvm: CameraViewModel
    @State private var isNotchDevice: Bool = true
    private let aspectRatio: CGFloat = 3 / 4
    private let spacing: CGFloat = 15
    var body: some View {
        GeometryReader { geo in
            let geoSize = geo.size
            let previewFrame = CGRect(x: 0, y: 0, width: geoSize.width, height: geoSize.width / aspectRatio)
            Color.black.ignoresSafeArea()
            VStack(alignment: .center) {
                if isNotchDevice { Spacer() }
                
                CustomCameraView(frame: previewFrame)
                    .frame(width: previewFrame.width, height: previewFrame.height)
                    .overlay(cvm.isCapturingPhoto ? Color.black : Color.clear)
                    .overlay(Color.white.opacity(cvm.preferredCameraPosition == .front && cvm.flashMode == .on && (cvm.isCapturingPhoto || cvm.isRecording) ? 0.9 : 0.0))
                    .overlay(ZStack { if !isNotchDevice { topControls } })
                
                contentCaptureMode
                bottomInteractionButtons
                
                
                Spacer()
            }
            .foregroundColor(.white)
            .frame(width: geoSize.width, height: geoSize.height)
            .overlay(ZStack { if isNotchDevice { topControls } })
            .onAppear { isNotchDevice = geo.safeAreaInsets.bottom > 0 }
        }
        .onAppear {
            cvm.endTimer()
            cvm.checkForCameraPermissions()
        }
        .onDisappear {
            cvm.endMovieRecording()
            cvm.session.stopRunning()
        }
    }
    
    var topControls: some View {
        VStack {
            HStack {
                Button {
                    if cvm.flashMode == .on {
                        cvm.flashMode = .off
                    } else {
                        cvm.flashMode = .on
                    }
                } label: {
                    Image(systemName: cvm.flashMode == .on ? "bolt.circle.fill" : "bolt.slash.circle")
                        .font(.system(size: 26))
                        .foregroundColor(cvm.flashMode == .on ? .yellow : .white)
                }
                .opacity(cvm.isCapturingPhoto || cvm.isRecording ? 0.0 : 1.0)
                Spacer()
            }
            .padding(.horizontal, spacing)
            .overlay(
                Text(cvm.timerString)
                    .font(.system(size: 19, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, spacing)
                    .padding(.vertical, spacing / 3)
                    .background(Color.black.opacity(0.4))
                    .foregroundColor(.white)
                    .cornerRadius(spacing / 2)
                    .padding(spacing / 2)
                    .opacity(cvm.videoModeEnabled ? 1.0 : 0.0)
            )
            
            Spacer()
        }
        .onReceive(cvm.timer) { _ in
            cvm.getRecordingDisplayCounter()
        }
    }
    var contentCaptureMode: some View {
        VStack(alignment: .center, spacing: (spacing / 2)) {
            HStack(alignment: .center, spacing: (spacing * 4)) {
                if !cvm.videoModeEnabled {
                    //used for even spacing
                    Text("Photo ").opacity(0.0)
                }
                
                Button {
                    cvm.videoModeEnabled = false
                } label: {
                    Text("PHOTO")
                        .foregroundColor(cvm.videoModeEnabled ? .white : .yellow)
                }

                Button {
                    cvm.videoModeEnabled = true
                } label: {
                    Text("VIDEO")
                        .foregroundColor(cvm.videoModeEnabled ? .yellow : .white)
                }

                if cvm.videoModeEnabled {
                    //used for even spacing
                    Text("  Video").opacity(0.0)
                }
            }
            .font(.subheadline.bold())
            .animation(.default, value: cvm.videoModeEnabled)
            
            Image(systemName: "triangle.fill")
                .font(.system(size: 12))
                .foregroundColor(.yellow)
        }
        .padding(.vertical, isNotchDevice ? spacing : 0)
        .opacity(cvm.isCapturingPhoto || cvm.isRecording ? 0.0 : 1.0)
    }
    var bottomInteractionButtons: some View {
        HStack(alignment: .center, spacing: spacing) {
            Button {
                guard !cvm.isRecording && !cvm.isCapturingPhoto else { return }
                cvm.showGallery = true
            } label: {
                RoundedRectangle(cornerRadius: (spacing / 2))
                    .fill(.red)
                    .frame(width: 48, height: 48)
            }
            .padding(spacing)
            .sheet(isPresented: $cvm.showGallery) {
                GalleryView()
            }
            
            Spacer()
            
            if !cvm.isCapturingPhoto {
                Button {
                    if cvm.videoModeEnabled {
                        if cvm.isRecording {
                            cvm.endMovieRecording()
                        } else {
                            cvm.startMovieRecording()
                        }
                    } else {
                        cvm.takePhoto()
                    }
                } label: {
                    Circle()
                        .fill(cvm.videoModeEnabled ? .red : .white)
                        .frame(width: 65, height: 65)
                        .overlay(
                            Circle()
                                .stroke(.white, lineWidth: 4)
                                .frame(width: 75, height: 75)
                                .opacity(cvm.isRecording ? 0.0 : 1.0)
                        )
                }
            } else {
                Circle()
                    .fill(cvm.videoModeEnabled ? .red : .white)
                    .frame(width: 65, height: 65)
                    .overlay(
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 75, height: 75)
                    )
                    .opacity(0.5)
            }
            
            
            Spacer()
            
            if cvm.canRotateCamera && !cvm.isRecording {
                Button {
                    cvm.rotateCamera()
                } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .font(.system(size: 28))
                        .padding(spacing)
                }
            } else {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 28))
                    .padding(spacing)
                    .opacity(0.5)
            }
        }
        .padding(.vertical, (spacing / 2))
    }
}

struct GalleryView: View {
    var body: some View {
        ZStack {
            Text("HELLO")
        }
    }
}

public struct CustomCameraView: UIViewRepresentable {
    @EnvironmentObject var cvm: CameraViewModel
    public var frame: CGRect
    private let view: UIView = UIView()
    private let flashLayer: CALayer = CALayer()
    
    public func makeCoordinator() -> Coordinator {
        return Coordinator(parent: self)
    }
    
    public func makeUIView(context: UIViewRepresentableContext<CustomCameraView>) -> UIView {
        view.frame = frame
        let preview = AVCaptureVideoPreviewLayer(session: cvm.session)
        
        let dragPanGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.zoomDragGesture(_:)))
        dragPanGesture.delegate = context.coordinator
        view.addGestureRecognizer(dragPanGesture)
        
        preview.frame = frame
        preview.videoGravity = cvm.videoGravity
        view.backgroundColor = .clear
        view.layer.addSublayer(preview)
        return view
    }
    
    public func updateUIView(_ uiView: UIViewType, context: UIViewRepresentableContext<CustomCameraView>) {
        uiView.frame = frame
    }
    
    public class Coordinator: NSObject, UIGestureRecognizerDelegate {
        public var parent: CustomCameraView
        init(parent: CustomCameraView) {
            self.parent = parent
        }
        
        @objc func zoomDragGesture(_ sender: UIPanGestureRecognizer) {
            parent.cvm.videoZoom(translHeight: sender.translation(in: parent.view).y)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static let cvm = CameraViewModel()
    static var previews: some View {
        CameraView()
            .environmentObject(cvm)
    }
}
