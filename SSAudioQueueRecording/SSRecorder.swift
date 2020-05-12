//
//  SSRecorder.swift
//  SSAudioQueueRecording
//
//  Created by Michael on 2020/4/2.
//  Copyright © 2020 Michael. All rights reserved.
//

import UIKit
import AudioToolbox
import AVFoundation

class SSRecorder: NSObject {
    var recorderState = SSRecorderState()
    
    override init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playAndRecord)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            
        }
    }
    
    func start() -> Void {
        let voidPtr = Unmanaged.passRetained(self).toOpaque()

        self.setupAudioFormat()
                
//        let queue = UnsafeMutablePointer<Optional<OpaquePointer>>(self.recorderState.mQueue)
        var status = AudioQueueNewInput(&self.recorderState.mDataFormat, handleInputCallback, voidPtr, nil, nil, 0, &self.recorderState.mQueue)
        SSCheckError(status, "AudioQueueNewInput")

        let fileName = "newOutput.caf"
        let documentPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/\(fileName)"
        
        //let path = NSFileManager.defaultManager().currentDirectoryPath + "/\(fileName)"
//        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("record-\(Date.init()).caf") as NSURL as CFURL

        let fileURL: CFURL = NSURL.fileURL(withPath: documentPath) as CFURL
        
//        let audioFile = UnsafeMutablePointer<AudioFileID?>(self.recorderState.mAudioFile)
        status = AudioFileCreateWithURL(fileURL, kAudioFileCAFType, &self.recorderState.mDataFormat, AudioFileFlags.eraseFile, &self.recorderState.mAudioFile)
        SSCheckError(status, "AudioFileCreateWithURL")
        
        status = self.setMagicCookieForFile(inAQ: self.recorderState.mQueue!, inFile: self.recorderState.mAudioFile!)
        SSCheckError(status, "setMagicCookieForFile")

        self.deriveBufferSize(inAQ: self.recorderState.mQueue!, asbDescription: self.recorderState.mDataFormat, seconds: 0.5, ioBufferSize: &self.recorderState.mBuffSize)
        for _ in 0..<3 {
            var buffer: AudioQueueBufferRef? = nil
            status = AudioQueueAllocateBuffer(self.recorderState.mQueue!, self.recorderState.mBuffSize, &buffer)
            SSCheckError(status, "AudioQueueAllocateBuffer")
            status = AudioQueueEnqueueBuffer(self.recorderState.mQueue!, buffer!, 0 ,nil)
            SSCheckError(status, "AudioQueueEnqueueBuffer")
        }
        
        self.recorderState.mIsRunning = true
        self.recorderState.mCurrentPacketIndex = 0;

        status = AudioQueueStart(self.recorderState.mQueue!, nil)
        SSCheckError(status, "AudioQueueStart")

    }
    
    func stop() -> Void {
        self.recorderState.mIsRunning = false
        
        AudioQueueDispose(self.recorderState.mQueue!, true)
        AudioFileClose(self.recorderState.mAudioFile!)
    }
    
    func pause() -> Void {
        
    }
    
    func resume() -> Void {
        
    }
    
    //
    let handleInputCallback :AudioQueueInputCallback = {(
        inUserData:UnsafeMutableRawPointer?,
        inAQ:AudioQueueRef,
        inBuffer:AudioQueueBufferRef,
        inStartTime:UnsafePointer<AudioTimeStamp>,
        inNumberPacket:UInt32,
        inPacketDescs:UnsafePointer<AudioStreamPacketDescription>?) -> () in
        let recorder = unsafeBitCast(inUserData!, to:SSRecorder.self)
        
        var ioNumPackets = inNumberPacket

        print("ioNumPackets===== "+"\(ioNumPackets)")
        if ioNumPackets>0 {
            let status = AudioFileWritePackets(recorder.recorderState.mAudioFile!, false, inBuffer.pointee.mAudioDataByteSize, inPacketDescs, recorder.recorderState.mCurrentPacketIndex, &ioNumPackets, inBuffer.pointee.mAudioData)
            SSCheckError(status, "AudioFileWritePackets")

            recorder.recorderState.mCurrentPacketIndex += Int64(ioNumPackets);
        }
        else
        {
            print("ioNumPackets = 0")//CBR???
        }
        
        if recorder.recorderState.mIsRunning {
            SSCheckError(AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, nil), "AudioQueueEnqueueBuffer")
        }
    }
    
    func deriveBufferSize(inAQ:AudioQueueRef,asbDescription:AudioStreamBasicDescription,seconds:Float64,ioBufferSize: UnsafeMutablePointer<UInt32>) -> Void {
        let maxBufferSize = 0x50000;
        
        var maxPacketSize = asbDescription.mBytesPerPacket
        if maxPacketSize == 0 {
            var maxVBRPacketSize :UInt32 = 4
            AudioQueueGetProperty(inAQ, kAudioQueueProperty_MaximumOutputPacketSize, &maxPacketSize, &maxVBRPacketSize)
        }
        
        let numBytesForTime :Float64 = asbDescription.mSampleRate*Float64(maxPacketSize)*seconds
        ioBufferSize.pointee = UInt32(numBytesForTime)<maxBufferSize ? UInt32(numBytesForTime) : UInt32(maxBufferSize)
    }
    
    func setMagicCookieForFile(inAQ:AudioQueueRef,inFile:AudioFileID) -> OSStatus {
        var result = noErr
        var cookieSize :UInt32 = 0
        
        result = AudioQueueGetPropertySize(inAQ, kAudioQueueProperty_MagicCookie, &cookieSize)
        SSCheckError(result, "AudioQueueGetPropertySize MagicCookieData")

        if result == noErr {
            let magicCookie :UnsafeMutablePointer<UInt32> = malloc(Int(cookieSize)).assumingMemoryBound(to: UInt32.self)
            result = AudioQueueGetProperty(inAQ, kAudioFilePropertyMagicCookieData, &cookieSize, magicCookie)
            SSCheckError(result, "AudioQueueGetProperty MagicCookieData")
            
            result = AudioFileSetProperty(inFile, kAudioFilePropertyMagicCookieData, cookieSize, magicCookie)
            SSCheckError(result, "AudioFileSetProperty MagicCookieData")
            
            free(magicCookie)
        }
        
        
        return result
    }
    
    func setupAudioFormat() -> Void {
        self.recorderState.mDataFormat.mFormatID = kAudioFormatLinearPCM
        self.recorderState.mDataFormat.mSampleRate = AVAudioSession.sharedInstance().sampleRate
        self.recorderState.mDataFormat.mChannelsPerFrame = 2
        self.recorderState.mDataFormat.mBitsPerChannel = 16
        self.recorderState.mDataFormat.mBytesPerPacket = (self.recorderState.mDataFormat.mBitsPerChannel / 8) * self.recorderState.mDataFormat.mChannelsPerFrame
        self.recorderState.mDataFormat.mBytesPerFrame = self.recorderState.mDataFormat.mBytesPerPacket
        self.recorderState.mDataFormat.mFramesPerPacket = 1
        self.recorderState.mDataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
    }
    
}

