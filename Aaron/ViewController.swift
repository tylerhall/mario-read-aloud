//
//  ViewController.swift
//  Aaron
//
//  Created by Tyler Hall on 9/26/20.
//

import UIKit
import AVFoundation
import Speech

class ViewController: UIViewController {
    
    @IBOutlet weak var wordCountLabel: UILabel!
    @IBOutlet weak var wordsLabel: UILabel!
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var marioImageView: UIImageView!
    @IBOutlet weak var marioXDistance: NSLayoutConstraint!
    @IBOutlet weak var marioYDistance: NSLayoutConstraint!
    @IBOutlet weak var confettiView: SAConfettiView!

    enum GameState {
        case NoSession
        case Playing
        case Won
        case Ended
    }

    var gameState: GameState = .NoSession {
        didSet {
            updateMarioFrame()
            switch gameState {
            case .NoSession:
                button.setTitle("Go!", for: .normal)
                finalWords = ""
                tempWords = ""
                marioXDistance.constant = 0
                marioYDistance.constant = 0
                jumpCount = 1
                confettiView.stopConfetti()
                confettiView.isHidden = true
                marioXDistance.constant = 0
                didWinTimer?.invalidate()
                marioYDistance.constant = 0
                break
            case .Playing:
                button.setTitle("Stop", for: .normal)
                finalWords = ""
                tempWords = ""
                jumpCount = 1
                startListening()
                confettiView.stopConfetti()
                confettiView.isHidden = true
                marioXDistance.constant = 0
                marioYDistance.constant = 0
                didWinTimer?.invalidate()
                break
            case .Won:
                tempWords = ""
                finalWords = ""
                guard oldValue != .Won else { return }
                stopListening()
                play(name: "win")
                button.setTitle("You Win!", for: .normal)
                confettiView.startConfetti()
                confettiView.isHidden = false
                celebrate()
                break
            case .Ended:
                button.setTitle("Play Again", for: .normal)
                wordsLabel.text = ""
                stopListening()
                break
            }
        }
    }

    let queue = OperationQueue()
    var player: AVAudioPlayer?

    var wordCountGoal: Int = 100
    var finalWords = "" {
        didSet {
            guard gameState != .Won else { return }
            updateMarioFrame()
            updateWordCountLabel()
            wordsLabel.text = allWords
        }
    }
    var tempWords = "" {
        didSet {
            guard gameState != .Won else { return }
            updateMarioFrame()
            updateWordCountLabel()
            wordsLabel.text = allWords
        }
    }
    var allWords: String {
        return (finalWords + " " + tempWords).trimmingCharacters(in: .whitespaces)
    }
    var wordCount: Int {
        return allWords.components(separatedBy: .whitespaces).count - 1
    }
    
    var jumpCount = 1
    var isJumping = false
    
    var idleTimer: Timer?
    var didWinTimer: Timer?

    let speechRecognizer = SFSpeechRecognizer()!
    var audioEngine: AVAudioEngine?
    var request: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?

    override func viewDidLoad() {
        super.viewDidLoad()
        speechRecognizer.delegate = self
        gameState = .NoSession
        
        let tgr = UITapGestureRecognizer(target: self, action: #selector(choosewordCountGoal))
        tgr.numberOfTouchesRequired = 3
        tgr.numberOfTapsRequired = 3
        view.addGestureRecognizer(tgr)
    }
    
    @objc func choosewordCountGoal() {
        let ac = UIAlertController(title: "Word Count Goal?", message: nil, preferredStyle: .alert)
        ac.addTextField { [weak self] (textfield) in
            guard let self = self else { return }
            textfield.text = "\(self.wordCountGoal)"
        }
        ac.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] (action) in
            guard let self = self else { return }
            self.wordCountGoal = Int(ac.textFields?.first!.text ?? "100") ?? 100
            self.updateWordCountLabel()
        }))
        present(ac, animated: true, completion: nil)
    }

    func startListening() {
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request = request else { return }
        request.requiresOnDeviceRecognition = true

        audioEngine = AVAudioEngine()

        let recordingFormat = audioEngine?.inputNode.outputFormat(forBus: 0)
        audioEngine?.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
            request.append(buffer)
        }
        audioEngine?.prepare()

        do {
            try audioEngine?.start()
        } catch {
            print(error)
            return
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request, resultHandler: { [weak self] (result, error) in
            guard let self = self else { return }
            guard let result = result else {
                print(error ?? "Error")
                return
            }

            self.idleTimer?.invalidate()

            let words = result.bestTranscription.formattedString.lowercased()
            
            let j = words.components(separatedBy: "jump").count
            if j > self.jumpCount {
                self.jumpCount = j
                self.jump()
            }
            
            if result.isFinal {
                self.finalWords += " " + words
                self.tempWords = ""
            } else if words.count < self.tempWords.count {
                self.finalWords += " " + self.tempWords
                self.tempWords = words
                self.startIdleTimer()
            } else {
                self.tempWords = words
                self.startIdleTimer()
            }
        })
    }

    func startIdleTimer() {
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false, block: { [weak self] (timer) in
            self?.marioImageView.image = UIImage(named: "mario0")
            self?.wordsLabel.text = ""
        })
    }

    func stopListening() {
        audioEngine?.stop()
        request?.endAudio()
        audioEngine?.inputNode.removeTap(onBus: 0)
    }
    
    func updateWordCountLabel() {
        switch gameState {
        case .NoSession:
            wordCountLabel.text = ""
            break
        case .Playing:
            let count = wordCountGoal - wordCount
            if count <= 0 {
                gameState = .Won
                wordCountLabel.text = "🥳🎉"
            } else {
                wordCountLabel.text = "\(count)"
            }
            break
        case .Won:
            wordCountLabel.text = "🥳🎉"
            break
        case .Ended:
            break
        }
    }
    
    func updateMarioFrame() {
        switch gameState {
        case .NoSession:
            marioImageView.image = UIImage(named: "mario0")
            break
        case .Playing:
            let frame = (wordCount % 3) + 1
            marioImageView.image = UIImage(named: "mario\(frame)")
            let fraction = CGFloat(wordCount) / CGFloat(wordCountGoal)
            let maxWidth = view.bounds.size.width - marioImageView.bounds.size.width
            marioXDistance.constant = min(maxWidth, maxWidth * fraction)
            UIView.animate(withDuration: 0.07) { [weak self] in
                self?.view.layoutIfNeeded()
            }
        case .Won:
            marioImageView.image = UIImage(named: "mario0")
            break
        case .Ended:
            marioImageView.image = UIImage(named: "mario0")
            break
        }
    }

    func play(name: String) {
        if let url = Bundle.main.url(forResource: name, withExtension: "mp3") {
            do {
                player = try AVAudioPlayer(contentsOf: url, fileTypeHint: AVFileType.mp3.rawValue)
                player?.play()
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }

    func jump(quiet: Bool = false) {
        if !quiet {
            play(name: "jump")
        }

        isJumping = true
        marioYDistance.constant = 100
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut) { [weak self] in
            self?.view.layoutIfNeeded()
        } completion: { [weak self] (finished) in
            self?.marioYDistance.constant = 0
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseIn) { [weak self] in
                self?.view.layoutIfNeeded()
            } completion: { (finished) in
                self?.isJumping = false
            }
        }
    }
    
    func celebrate() {
        didWinTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] (timer) in
            guard let self = self else { return }
            guard !self.isJumping else { return }
            self.jump(quiet: true)
        })
    }
}

extension ViewController {

    @IBAction func buttonTapped(_ sender: AnyObject?) {
        switch gameState {
        case .NoSession:
            gameState = .Playing
            break
        case .Playing:
            gameState = .Ended
            break
        case .Won:
            gameState = .Ended
        case .Ended:
            gameState = .Playing
            break
        }
    }
}

extension ViewController: SFSpeechRecognizerDelegate, SFSpeechRecognitionTaskDelegate {
    
    func speechRecognitionTask(_ task: SFSpeechRecognitionTask, didFinishSuccessfully successfully: Bool) {
        
    }
    
    func speechRecognitionTaskWasCancelled(_ task: SFSpeechRecognitionTask) {
        
    }
}
