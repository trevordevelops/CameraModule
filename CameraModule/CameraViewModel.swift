//
//  CameraViewModel.swift
//  CameraModule
//
//  Created by Trevor Welsh on 9/2/22.
//

import SwiftUI
import Photos
import AVFoundation

class CameraViewModel: NSObject, ObservableObject {
    @Published var videoModeEnabled: Bool = false
    @Published var isRecording: Bool = false
    @Published var isCapturingPhoto: Bool = false
    @Published var canRotateCamera: Bool = false
    @Published var movieFileOutput: AVCaptureMovieFileOutput = AVCaptureMovieFileOutput()
    @Published var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @Published var startTime: Date = Date()
    @Published var timerString: String = "00:00"
    @Published var showGallery: Bool = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var photoOutput: AVCapturePhotoOutput = AVCapturePhotoOutput()
    @Published var preferredCameraPosition: AVCaptureDevice.Position = .back
    @Published var preferredStartingCameraType: AVCaptureDevice.DeviceType = .builtInWideAngleCamera
    @Published var session = AVCaptureSession()
    @Published var videoGravity: AVLayerVideoGravity = .resizeAspect
    @Published var videoQuality: AVCaptureSession.Preset = .photo
    private var audioDeviceInput: AVCaptureDeviceInput!
    private var setupResult: SessionSetupResult = .success
    private var videoDeviceInput: AVCaptureDeviceInput!
    private let sessionQueue = DispatchQueue(label: "session queue")
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    public func checkForCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
        default:
            setupResult = .notAuthorized
        }
        sessionQueue.async {
            self.configureSession()
        }
    }
    
    private func configureSession() {
        DispatchQueue.main.async {
            self.canRotateCamera = false
        }
        if setupResult != .success {
            return
        }
        self.removeSessionInOutPuts()
        self.session.beginConfiguration()
        do {
            var defaultVideoDevice: AVCaptureDevice?
            
            if self.preferredCameraPosition == .front {
                if let preferredCameraDevice = AVCaptureDevice.default(self.preferredStartingCameraType, for: .video, position: self.preferredCameraPosition) {
                    defaultVideoDevice = preferredCameraDevice
                } else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                    defaultVideoDevice = frontCameraDevice
                }
            } else {
                if let preferredCameraDevice = AVCaptureDevice.default(self.preferredStartingCameraType, for: .video, position: self.preferredCameraPosition) {
                    defaultVideoDevice = preferredCameraDevice
                } else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                    defaultVideoDevice = backCameraDevice
                }
            }
            
            
            guard let videoDevice = defaultVideoDevice else {
                print("Default video device is unavailable.")
                setupResult = .configurationFailed
                self.session.commitConfiguration()
                return
            }
            self.videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if self.videoDeviceInput.device.supportsSessionPreset(.photo) {
                self.session.sessionPreset = .photo
            }
            if self.session.canAddInput(self.videoDeviceInput) {
                self.session.addInput(self.videoDeviceInput)
                try self.videoDeviceInput.device.lockForConfiguration()
                self.videoDeviceInput.device.exposureMode = .continuousAutoExposure
                if self.videoDeviceInput.device.isFocusPointOfInterestSupported {
                    self.videoDeviceInput.device.focusMode = .continuousAutoFocus
                }
            } else {
                print("Couldn't add video device input to the self.ue.session.")
                setupResult = .configurationFailed
                self.session.commitConfiguration()
                return
            }
        } catch {
            print("Couldn't create video device input: \(error)")
            setupResult = .configurationFailed
            self.session.commitConfiguration()
            return
        }
        self.addPhotoOutput()
        self.addAudioDevice()
        self.addMovieOutput()
        self.session.commitConfiguration()
        self.session.startRunning()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.canRotateCamera = true
        }
    }
    
    private func removeSessionInOutPuts() {
        for input in self.session.inputs {
            self.session.removeInput(input)
        }
        for output in self.session.outputs {
            self.session.removeOutput(output)
        }
    }
    
    private func addPhotoOutput() {
        if self.session.canAddOutput(self.photoOutput) {
            self.session.addOutput(self.photoOutput)
        } else {
            print("Could not add photo output to the session")
            setupResult = .configurationFailed
            self.session.commitConfiguration()
            return
        }
    }
    
    private func addMovieOutput() {
        if self.session.canAddOutput(self.movieFileOutput) {
            self.session.addOutput(self.movieFileOutput)
            if let connection = self.movieFileOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
            }
        }
    }
    
    private func addAudioDevice() {
        do {
            guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
                setupResult = .configurationFailed
                self.session.commitConfiguration()
                return
            }
            
            self.audioDeviceInput = try AVCaptureDeviceInput(device: audioDevice)
            if self.session.canAddInput(self.audioDeviceInput) {
                self.session.addInput(self.audioDeviceInput)
            } else {
                print("Could not add audio device input to the session")
            }
        } catch {
            print("Could not create audio device input: \(error)")
            setupResult = .configurationFailed
            self.session.commitConfiguration()
            return
        }
    }
    
    public func videoZoom(translHeight: CGFloat) {
        do {
            let captureDevice = self.videoDeviceInput.device
            try captureDevice.lockForConfiguration()
            let maxZoomFactor: CGFloat = captureDevice.activeFormat.videoMaxZoomFactor
            DispatchQueue.main.async {
                let value = -translHeight
                var rawZoomFactor: CGFloat = 0
                rawZoomFactor = (value / UIScreen.main.bounds.height) * maxZoomFactor
                
                let zoomFactor = min(max(rawZoomFactor, 1), maxZoomFactor)
                captureDevice.videoZoomFactor = zoomFactor
                captureDevice.unlockForConfiguration()
            }
        } catch {
            print("Error locking configuration for camera zoom, drag gesture")
        }
    }
    
    public func rotateCamera() {
        guard !movieFileOutput.isRecording && !isCapturingPhoto && canRotateCamera else { return }
        canRotateCamera = false
        let currentVideoDevice = self.videoDeviceInput.device
        let deviceCurrentPosition = currentVideoDevice.position
        switch deviceCurrentPosition {
        case .unspecified, .front:
            preferredCameraPosition = .back
        case .back:
            preferredCameraPosition = .front
        @unknown default:
            preferredCameraPosition = .back
        }
        configureSession()
    }
    
    private func startTimer() {
        startTime = Date()
        timer = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()
        isRecording = true
    }
    
    public func endTimer() {
        timer.upstream.connect().cancel()
        isRecording = false
        timerString = "00:00"
    }
    
    public func getRecordingDisplayCounter() {
        guard isRecording else { return }
        let timeSince = Date().timeIntervalSince(startTime)
        let seconds = (Int(timeSince) % 3600) % 60
        let minutes = (Int(timeSince) % 3600) / 60
        guard Int(timeSince) < 3600 else {
            endMovieRecording()
            return
        }
        timerString = "\(minutes < 10 ? "0\(minutes)" : "\(minutes)"):\(seconds < 10 ? "0\(seconds)" : "\(seconds)")"
    }
}

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    public func takePhoto() {
        guard !isCapturingPhoto else { return }
        self.sessionQueue.async {
            do {
                DispatchQueue.main.async {
                    self.isCapturingPhoto = true
                }
                let captureDevice = self.videoDeviceInput.device
                try captureDevice.lockForConfiguration()
                let photoSettings = AVCapturePhotoSettings()
                if self.videoDeviceInput.device.isFlashAvailable {
                    photoSettings.flashMode = self.flashMode
                }
                self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
            } catch {
                print("Error taking photo: \(error)")
            }
        }
    }
    
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let photoData = photo.fileDataRepresentation() else {
            self.isCapturingPhoto = false
            return
        }
        let dataProvider = CGDataProvider(data: photoData as CFData)
        guard let cgImageRef = CGImage(jpegDataProviderSource: dataProvider!, decode: nil, shouldInterpolate: true, intent: CGColorRenderingIntent.defaultIntent) else {
            self.isCapturingPhoto = false
            return
        }
        
        DispatchQueue.main.async {
            var uiImage: UIImage!
            switch UIDevice.current.orientation {
            case .portrait:
                uiImage = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: self.preferredCameraPosition == .front ? .leftMirrored : .right)
            case .landscapeLeft:
                uiImage = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: self.preferredCameraPosition == .front ? .downMirrored : .up)
            case .landscapeRight:
                uiImage = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: self.preferredCameraPosition == .front ? .upMirrored : .up)
            case .portraitUpsideDown:
                uiImage = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: self.preferredCameraPosition == .front ? .left : .right)
            default:
                uiImage = UIImage(cgImage: cgImageRef, scale: 1.0, orientation: self.preferredCameraPosition == .front ? .leftMirrored : .right)
            }
            
            self.savePhoto(uiImage)
            self.isCapturingPhoto = false
        }
    }
    
    public func savePhoto(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(didFinishSavingWithError(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc private func didFinishSavingWithError(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer) {
        guard let error = error else { return }
        print(error)
    }
}

extension CameraViewModel: AVCaptureFileOutputRecordingDelegate {
    public func startMovieRecording() {
        self.sessionQueue.async {
            do {
                try self.videoDeviceInput.device.lockForConfiguration()
                if self.videoDeviceInput.device.isTorchModeSupported(self.videoDeviceInput.device.torchMode) && self.flashMode == .on {
                    self.videoDeviceInput.device.torchMode = .on
                    self.videoDeviceInput.device.unlockForConfiguration()
                }
                let movieFileOutputConnection = self.movieFileOutput.connection(with: .video)
                if self.preferredCameraPosition == .front {
                    movieFileOutputConnection?.isVideoMirrored = true
                }
                movieFileOutputConnection?.videoOrientation = .portrait
                let availableVideoCodecTypes = self.movieFileOutput.availableVideoCodecTypes
                if availableVideoCodecTypes.contains(.hevc) {
                    self.movieFileOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.hevc], for: movieFileOutputConnection!)
                }
                let outputFileName = NSUUID().uuidString
                let outputFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((outputFileName as NSString).appendingPathExtension("mov")!)
                self.movieFileOutput.startRecording(to: URL(fileURLWithPath: outputFilePath), recordingDelegate: self)
                DispatchQueue.main.async {
                    self.startTimer()
                }
            } catch {
                print("Error starting movie recording: \(error)")
            }
        }
    }
    
    public func endMovieRecording() {
        self.sessionQueue.async {
            do {
                self.movieFileOutput.stopRecording()
                try self.videoDeviceInput.device.lockForConfiguration()
                if self.videoDeviceInput.device.isTorchModeSupported(self.videoDeviceInput.device.torchMode) && self.flashMode == .on {
                    self.videoDeviceInput.device.torchMode = .off
                }
                self.videoDeviceInput.device.videoZoomFactor = 1
                self.videoDeviceInput.device.unlockForConfiguration()
                DispatchQueue.main.async {
                    self.endTimer()
                }
            } catch {
                print("Error ending movie recording: \(error)")
            }
        }
    }
    
    /// - Tag: DidFinishRecording
    public func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        DispatchQueue.main.async {
//            self.videoPlayerURL = outputFileURL
//            self.getUploadReadyURL(url: outputFileURL) { url, thumbnail in
//                DispatchQueue.main.async {
//                    self.uploadReadyLiveURL = url
//                    self.liveMomentThumbnail = thumbnail
//                }
//            }
            self.saveMovieToCameraRoll(url: outputFileURL, error: error) { didSave in
                print(didSave)
            }
        }
    }
    
    public func saveMovieToCameraRoll(url: URL, error: Error?, completion: @escaping (_ didSave: Bool) -> Void) {
        var success = true
        if let error = error {
            print("Movie file finishing error: \(String(describing: error))")
            success = ((error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as AnyObject).boolValue
        }
        guard success else {
            self.cleanupFileManagerToSaveNewFile(outputFileURL: url)
            return
        }
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                self.cleanupFileManagerToSaveNewFile(outputFileURL: url)
                return
            }
            PHPhotoLibrary.shared().performChanges({
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .video, fileURL: url, options: options)
            }, completionHandler: { success, error in
                if !success {
                    print("Couldn't save the movie to your photo library: \(String(describing: error))")
                }
                self.cleanupFileManagerToSaveNewFile(outputFileURL: url)
                completion(success)
            })
        }
    }
    
    private func getUploadReadyURL(url: URL, completion: @escaping (_ url: URL, _ thumbnail: UIImage) -> Void) {
        do {
            let asset = AVAsset(url: url)
            let imgGenerator = AVAssetImageGenerator(asset: asset)
            imgGenerator.appliesPreferredTrackTransform = true
            let cgImage = try imgGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
            let thumbnail = UIImage(cgImage: cgImage)
            
            var layerInstructionsArray: [AVVideoCompositionLayerInstruction] = []
            guard let videoTrack = asset.tracks(withMediaType: .video).first else { return }
            guard let audioTrack = asset.tracks(withMediaType: .audio).first else { return }
            let speedComp = AVMutableComposition()
            guard let speedVideo = speedComp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { return }
            guard let speedAudio = speedComp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else { return }
            speedVideo.preferredTransform = videoTrack.preferredTransform
            let transforms = videoTrack.preferredTransform
            let assetTimeRange = CMTimeRange(start: .zero, duration: asset.duration)
            try speedVideo.insertTimeRange(assetTimeRange, of: videoTrack, at: .zero)
            try speedAudio.insertTimeRange(assetTimeRange, of: audioTrack, at: .zero)
            
            let vidInstruct = AVMutableVideoCompositionLayerInstruction()
            vidInstruct.setTransform(transforms, at: .zero)
            layerInstructionsArray.append(vidInstruct)
            
            let mainInstruct = AVMutableVideoCompositionInstruction()
            mainInstruct.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
            mainInstruct.layerInstructions = layerInstructionsArray
            
            let mainComp = AVMutableVideoComposition()
            mainComp.instructions = [mainInstruct]
            mainComp.frameDuration = CMTimeMake(value: 1, timescale: 20)
            mainComp.renderSize = CGSize(width: 1080, height: 1920)
            
            let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .long
            let date = dateFormatter.string(from: NSDate() as Date)
            let savePath = (documentDirectory as NSString).appendingPathComponent("hudle-\(date).mp4")
            let url = NSURL(fileURLWithPath: savePath)
            
            guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1920x1080) else { return }
            exporter.outputURL = url as URL
            exporter.outputFileType = .mp4
            exporter.shouldOptimizeForNetworkUse = true
            exporter.exportAsynchronously {
                guard let url = exporter.outputURL else {
                    print("ERROR")
                    return
                }
                completion(url, thumbnail)
            }
        } catch {
            print("ERROR")
        }
        
        
    }
    
    private func cleanupFileManagerToSaveNewFile(outputFileURL: URL) {
        let path = outputFileURL.path
        guard FileManager.default.fileExists(atPath: path) else { return }
        do {
            try FileManager.default.removeItem(atPath: path)
        } catch {
            print("Could not remove file at url: \(outputFileURL)")
        }
    }
}
