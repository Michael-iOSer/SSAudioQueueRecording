//
//  ViewController.swift
//  SSAudioQueueRecording
//
//  Created by Michael on 2020/3/24.
//  Copyright © 2020 Michael. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    var recorder:SSRecorder = SSRecorder()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
    }
    @IBAction func startAction(_ sender: Any) {
        self.recorder.start()
    }
    
    @IBAction func pauseAction(_ sender: Any) {
        self.recorder.pause()
    }
    
    @IBAction func resumeAction(_ sender: Any) {
        self.recorder.resume()
    }
    
    @IBAction func stopAction(_ sender: Any) {
        self.recorder.stop()
    }
}

