import UIKit
import PDFKit
import AVFoundation
import UniformTypeIdentifiers

class PDFViewController: UIViewController, UIDocumentPickerDelegate, AVSpeechSynthesizerDelegate {
    private let pdfView = PDFView()
    private let synthesizer = AVSpeechSynthesizer()
    private var currentPage = 0
    private var progressView: UIProgressView!
    private var speedSlider: UISlider!
    private var pageControl: UIPageControl!
    private var readingProgress: Float = 0.0
    private var durationLabel: UILabel!
    private var timeSlider: UISlider!
    private var currentUtterance: AVSpeechUtterance?
    private var utteranceStartTime: Date?
    private var estimatedDuration: TimeInterval = 0
    private var playPauseButton: UIButton!
    private var nextButton: UIButton!
    private var previousButton: UIButton!
    private var voicePickerButton: UIButton!
    private var darkModeButton: UIButton!
    private var isPlaying = false
    private var selectedVoice: AVSpeechSynthesisVoice?
    private var availableVoices: [AVSpeechSynthesisVoice] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAudio()
        setupUI()
        setupPDFView()
        setupControls()
        loadAvailableVoices()
    }
    
    private func setupAudio() {
        // Configure audio session
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            synthesizer.delegate = self
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    private func loadAvailableVoices() {
        availableVoices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.starts(with: "en") }
        
        // Set default voice
        if let enhancedVoice = availableVoices.first(where: { $0.quality == .enhanced }) {
            selectedVoice = enhancedVoice
        } else {
            selectedVoice = availableVoices.first
        }
        
        // Test audio
        let testUtterance = AVSpeechUtterance(string: "ReadBaba is ready")
        testUtterance.voice = selectedVoice
        testUtterance.volume = 1.0
        testUtterance.rate = 0.5
        synthesizer.speak(testUtterance)
    }
    
    private func setupUI() {
        title = "ReadBaba"
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = .systemBackground
        
        // Add Open PDF button to navigation bar
        let openButton = UIBarButtonItem(title: "Open PDF", style: .plain, target: self, action: #selector(openPDFPicker))
        navigationItem.rightBarButtonItem = openButton
    }
    
    private func setupPDFView() {
        view.addSubview(pdfView)
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pdfView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6)
        ])
        
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.backgroundColor = .systemBackground
        pdfView.displayDirection = .horizontal
        pdfView.usePageViewController(true)
        
        // Add page control
        pageControl = UIPageControl()
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pageControl)
        
        NSLayoutConstraint.activate([
            pageControl.topAnchor.constraint(equalTo: pdfView.bottomAnchor, constant: 8),
            pageControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pageControl.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        pageControl.addTarget(self, action: #selector(pageControlChanged(_:)), for: .valueChanged)
    }
    
    private func setupControls() {
        // Create main stack view
        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.spacing = 15
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)
        
        // Progress view
        progressView = UIProgressView(progressViewStyle: .default)
        progressView.progress = 0
        
        // Time slider and duration label
        timeSlider = UISlider()
        timeSlider.minimumValue = 0
        timeSlider.maximumValue = 1
        timeSlider.value = 0
        timeSlider.addTarget(self, action: #selector(timeSliderChanged), for: .valueChanged)
        
        durationLabel = UILabel()
        durationLabel.text = "00:00 / 00:00"
        durationLabel.textAlignment = .center
        durationLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        
        // Speed slider
        speedSlider = UISlider()
        speedSlider.minimumValue = AVSpeechUtteranceMinimumSpeechRate
        speedSlider.maximumValue = AVSpeechUtteranceMaximumSpeechRate
        speedSlider.value = AVSpeechUtteranceDefaultSpeechRate
        speedSlider.addTarget(self, action: #selector(speedChanged), for: .valueChanged)
        
        // Play/Pause button
        playPauseButton = UIButton(type: .system)
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        playPauseButton.backgroundColor = .systemBlue
        playPauseButton.tintColor = .white
        playPauseButton.layer.cornerRadius = 25
        playPauseButton.addTarget(self, action: #selector(playPauseAction), for: .touchUpInside)
        
        // Previous button
        previousButton = UIButton(type: .system)
        previousButton.setImage(UIImage(systemName: "backward.fill"), for: .normal)
        previousButton.addTarget(self, action: #selector(previousPage), for: .touchUpInside)
        
        // Next button
        nextButton = UIButton(type: .system)
        nextButton.setImage(UIImage(systemName: "forward.fill"), for: .normal)
        nextButton.addTarget(self, action: #selector(nextPage), for: .touchUpInside)
        
        // Navigation controls
        let navigationStack = UIStackView()
        navigationStack.axis = .horizontal
        navigationStack.distribution = .equalSpacing
        navigationStack.spacing = 20
        
        navigationStack.addArrangedSubview(previousButton)
        navigationStack.addArrangedSubview(playPauseButton)
        navigationStack.addArrangedSubview(nextButton)
        
        // Speed control stack
        let speedStack = UIStackView()
        speedStack.axis = .horizontal
        speedStack.distribution = .fill
        speedStack.spacing = 10
        
        let speedLabel = UILabel()
        speedLabel.text = "Speed"
        speedLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        
        speedStack.addArrangedSubview(speedLabel)
        speedStack.addArrangedSubview(speedSlider)
        
        // Settings stack
        let settingsStack = UIStackView()
        settingsStack.axis = .horizontal
        settingsStack.distribution = .equalSpacing
        settingsStack.spacing = 20
        
        // Voice picker button
        voicePickerButton = UIButton(type: .system)
        voicePickerButton.setImage(UIImage(systemName: "person.wave.2"), for: .normal)
        voicePickerButton.addTarget(self, action: #selector(showVoicePicker), for: .touchUpInside)
        
        // Dark mode toggle
        darkModeButton = UIButton(type: .system)
        darkModeButton.setImage(UIImage(systemName: "moon.fill"), for: .normal)
        darkModeButton.addTarget(self, action: #selector(toggleDarkMode), for: .touchUpInside)
        
        settingsStack.addArrangedSubview(voicePickerButton)
        settingsStack.addArrangedSubview(darkModeButton)
        
        // Add all controls to main stack
        mainStack.addArrangedSubview(progressView)
        mainStack.addArrangedSubview(timeSlider)
        mainStack.addArrangedSubview(durationLabel)
        mainStack.addArrangedSubview(navigationStack)
        mainStack.addArrangedSubview(speedStack)
        mainStack.addArrangedSubview(settingsStack)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: pageControl.bottomAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            playPauseButton.heightAnchor.constraint(equalToConstant: 50),
            playPauseButton.widthAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc private func openPDFPicker() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf], asCopy: true)
        documentPicker.delegate = self
        present(documentPicker, animated: true)
    }
    
    // UIDocumentPickerDelegate
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        loadPDF(url: url)
        startReading()
    }
    
    @objc private func playPauseAction() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .immediate)
            playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
            isPlaying = false
        } else if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            isPlaying = true
        } else {
            startReading()
            playPauseButton.setImage(UIImage(systemName: "pause.fill"), for: .normal)
            isPlaying = true
        }
    }
    
    @objc private func nextPage() {
        if currentPage < (pdfView.document?.pageCount ?? 1) - 1 {
            currentPage += 1
            pageControl.currentPage = currentPage
            pdfView.go(to: pdfView.document?.page(at: currentPage) ?? PDFPage())
            startReading()
        }
    }
    
    @objc private func previousPage() {
        if currentPage > 0 {
            currentPage -= 1
            pageControl.currentPage = currentPage
            pdfView.go(to: pdfView.document?.page(at: currentPage) ?? PDFPage())
            startReading()
        }
    }
    
    @objc private func showVoicePicker() {
        let voiceVC = UITableViewController(style: .grouped)
        voiceVC.title = "Select Voice"
        
        // Group voices by language
        let groupedVoices = Dictionary(grouping: availableVoices) { $0.language }
        let sortedLanguages = groupedVoices.keys.sorted()
        
        voiceVC.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "VoiceCell")
        
        voiceVC.tableView.dataSource = { [weak self] tableView, indexPath in
            let cell = tableView.dequeueReusableCell(withIdentifier: "VoiceCell", for: indexPath)
            let language = sortedLanguages[indexPath.section]
            let voice = groupedVoices[language]![indexPath.row]
            
            var config = cell.defaultContentConfiguration()
            config.text = voice.name
            config.secondaryText = "\(voice.quality == .enhanced ? "Enhanced" : "Standard")"
            cell.contentConfiguration = config
            
            if voice.identifier == self?.selectedVoice?.identifier {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
            
            return cell
        }
        
        voiceVC.tableView.delegate = { [weak self] tableView, indexPath in
            let language = sortedLanguages[indexPath.section]
            let voice = groupedVoices[language]![indexPath.row]
            self?.selectedVoice = voice
            
            if self?.synthesizer.isSpeaking == true {
                self?.synthesizer.stopSpeaking(at: .immediate)
                self?.startReading()
            }
            
            tableView.reloadData()
        }
        
        let nav = UINavigationController(rootViewController: voiceVC)
        present(nav, animated: true)
    }
    
    @objc private func toggleDarkMode() {
        if view.overrideUserInterfaceStyle == .dark {
            view.overrideUserInterfaceStyle = .light
            darkModeButton.setImage(UIImage(systemName: "moon.fill"), for: .normal)
        } else {
            view.overrideUserInterfaceStyle = .dark
            darkModeButton.setImage(UIImage(systemName: "sun.max.fill"), for: .normal)
        }
    }
    
    private func startReading() {
        // Stop any ongoing speech
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        // First check if we have a document
        guard let document = pdfView.document else {
            showAlert(message: "No PDF document loaded")
            return
        }
        
        // Get current page
        guard let page = document.page(at: currentPage) else {
            showAlert(message: "Could not access current page")
            return
        }
        
        // Extract text
        guard let text = page.string, !text.isEmpty else {
            showAlert(message: "No readable text found on this page")
            return
        }
        
        print("Attempting to read text: \(text.prefix(100))...") // Debug print
        
        // Ensure audio session is active
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to activate audio session: \(error)")
        }
        
        // Configure speech with enhanced voice selection
        let utterance = AVSpeechUtterance(string: text)
        
        // Get available voices
        let voices = AVSpeechSynthesisVoice.speechVoices()
        
        // Try to find the best voice
        if let enhancedVoice = voices.first(where: { $0.language.starts(with: "en") && $0.quality == .enhanced }) {
            print("Using enhanced voice: \(enhancedVoice.identifier)")
            utterance.voice = enhancedVoice
        } else if let defaultVoice = AVSpeechSynthesisVoice(language: "en-US") {
            print("Using default voice: \(defaultVoice.identifier)")
            utterance.voice = defaultVoice
        } else {
            print("No suitable voice found, using system default")
        }
        
        // Configure speech parameters based on speed slider
        utterance.rate = speedSlider.value
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0 // Maximum volume
        
        // Start speaking
        synthesizer.speak(utterance)
        
        // Store current utterance and start time
        currentUtterance = utterance
        utteranceStartTime = Date()
        
        // Estimate duration based on word count and speed
        let wordCount = text.components(separatedBy: .whitespacesAndNewlines).count
        estimatedDuration = TimeInterval(Double(wordCount) * (0.3 / Double(utterance.rate)))
        updateDurationLabel()
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let seconds = Int(seconds) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func updateDurationLabel() {
        guard let startTime = utteranceStartTime else {
            durationLabel.text = "00:00 / \(formatTime(estimatedDuration))"
            return
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        durationLabel.text = "\(formatTime(elapsed)) / \(formatTime(estimatedDuration))"
    }
    
    @objc private func timeSliderChanged(_ sender: UISlider) {
        guard let utterance = currentUtterance,
              let text = utterance.speechString else { return }
        
        // Calculate the character position based on slider value
        let position = Int(Float(text.count) * sender.value)
        
        // Stop current speech
        synthesizer.stopSpeaking(at: .immediate)
        
        // Create new utterance with remaining text
        let index = text.index(text.startIndex, offsetBy: min(position, text.count - 1))
        let remainingText = String(text[index...])
        
        let newUtterance = AVSpeechUtterance(string: remainingText)
        newUtterance.voice = selectedVoice
        newUtterance.rate = speedSlider.value
        newUtterance.pitchMultiplier = 1.0
        newUtterance.volume = 1.0
        
        // Update time tracking
        utteranceStartTime = Date().addingTimeInterval(-TimeInterval(Double(position) * (0.3 / Double(utterance.rate))))
        currentUtterance = newUtterance
        
        synthesizer.speak(newUtterance)
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "ReadBaba", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    func loadPDF(url: URL) {
        guard let document = PDFDocument(url: url) else {
            showAlert(message: "Could not load PDF")
            return
        }
        pdfView.document = document
        currentPage = 0
        
        // Setup page control
        pageControl.numberOfPages = document.pageCount
        pageControl.currentPage = 0
        
        // Reset progress
        progressView.progress = 0
        readingProgress = 0
    }
    
    @objc private func pageControlChanged(_ sender: UIPageControl) {
        currentPage = sender.currentPage
        pdfView.go(to: pdfView.document?.page(at: currentPage) ?? PDFPage())
    }
    
    @objc private func speedChanged(_ sender: UISlider) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            startReading() // Restart with new speed
        }
    }
    
    // Update progress as speech progresses
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        let progress = Float(characterRange.location + characterRange.length) / Float(utterance.speechString.count)
        progressView.progress = progress
        timeSlider.value = progress
        updateDurationLabel()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("Finished speaking")
        progressView.progress = 1.0
        
        // Move to next page if available
        if currentPage < (pdfView.document?.pageCount ?? 1) - 1 {
            currentPage += 1
            pageControl.currentPage = currentPage
            pdfView.go(to: pdfView.document?.page(at: currentPage) ?? PDFPage())
            startReading() // Start reading next page
        }
    }
    
    // MARK: - AVSpeechSynthesizerDelegate
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("Started speaking")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        print("Paused speaking")
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        isPlaying = false
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("Cancelled speaking")
        playPauseButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
        isPlaying = false
        progressView.progress = 0
    }
}
