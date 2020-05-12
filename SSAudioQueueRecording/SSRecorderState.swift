//
//  SSRecorderState.swift
//  SSAudioQueueRecording
//
//  Created by Michael on 2020/3/24.
//  Copyright © 2020 Michael. All rights reserved.
//

import UIKit
import AudioToolbox

//static const int kNumberBuffers 3;

class SSRecorderState: NSObject {
    var mDataFormat: AudioStreamBasicDescription = AudioStreamBasicDescription()
    var mQueue: AudioQueueRef? = nil
    var mAudioFile: AudioFileID? = nil
    var mBuffSize: UInt32 = 0
    var mCurrentPacketIndex: Int64 = 0
    var mIsRunning = false
}
