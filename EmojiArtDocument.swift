import SwiftUI

class EmojiArtDocument: ObservableObject {
    
    @Published private(set) var emojiArt: EmojiArtModel {
        didSet {
            scheduleAutosave()
            if emojiArt.background != oldValue.background {
                fetchBackgroundImageDataIfNecessary()
            }
        }
    }
    
    private var autosaveTimer: Timer?
    
    private func scheduleAutosave() {
        autosaveTimer?.invalidate() //cancels previous timers
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: Autosave.coalescingInterval, repeats: false) { _ in
            self.autoSave()
        }
    }
    
    private func autoSave() {
        if let url = Autosave.url {
            save(to: url) //passing document directory file path component to save
        }
    }
    
    private struct Autosave {
        static let filename = "Autosaved.emojiart"
        static var url: URL? {
            let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first //iOS only has one url
            return documentDirectory?.appendingPathComponent(filename) //adding file component to directory url
        }
        static let coalescingInterval = 5.0
    }
    
    private func save(to url: URL) {
        let thisFunction = "\(String(describing: self)).\(#function))"
        do {
            let data = try emojiArt.json()
            try data.write(to: url) //saving data to url
            print("\(thisFunction) success!")
        } catch let encodingError where encodingError is EncodingError {
            print("\(thisFunction) couldn't encode EmojiArt as JSON because \(encodingError.localizedDescription)")
        } catch {
            print("\(thisFunction) error = \(error)") //error is default error var from catch statement
        }
    }
    
    init() {
        if let url = Autosave.url, let autosavedEmojiArt = try? EmojiArtModel(url: url) { //if autoSaved model can be created from file url, set new instance to be the same as autosaved instance, otherwise create a blank doc
            emojiArt = autosavedEmojiArt
            fetchBackgroundImageDataIfNecessary()
        } else {
            emojiArt = EmojiArtModel()
            //        emojiArt.addEmoji("😃", at: (-200, -100), size: 80)
            //        emojiArt.addEmoji("😷", at: (50, 100), size: 40)
        }
    }
    
    var emojis: [EmojiArtModel.Emoji] {
        emojiArt.emojis
    }
    
    var background: EmojiArtModel.Background {
        emojiArt.background
    }
    
    @Published var backgroundImage: UIImage?
    @Published var backgroundImageFetchStatus = BackgroundImageFetchStatus.idle
    
    enum BackgroundImageFetchStatus: Equatable {
        case idle
        case fetching
        case failed(URL)
    }
    
    private func fetchBackgroundImageDataIfNecessary() {
        backgroundImage = nil
        
        switch emojiArt.background {
            case .url(let url):
                //fetch url
                backgroundImageFetchStatus = .fetching
                DispatchQueue.global(qos: .userInitiated).async { //dispatching to background thread
                    let imageData = try? Data(contentsOf: url) //if can't fetch data, just set imageData to nil
                    DispatchQueue.main.async { [weak self] in //dispatching UI changes to main thread
                        if self?.emojiArt.background == EmojiArtModel.Background.url(url) { //if current background is same as fetched url, update background
                            self?.backgroundImageFetchStatus = .idle
                            if imageData != nil {
                                self?.backgroundImage = UIImage(data: imageData!) // '?' means if nil, stop exectuing
                            }
                            if self?.backgroundImage == nil {
                                self?.backgroundImageFetchStatus = .failed(url)
                            }
                        }
                    }
                }
            case .imageData(let data):
                backgroundImage = UIImage(data: data)
            case .blank:
                break
        }
    }
    
    //MARK: Intent(s)
    
    func setBackground(_ background: EmojiArtModel.Background) {
        emojiArt.background = background
        print("Background set to \(background)")
    }
    
    func addEmoji(_ emoji: String, at location: (x: Int, y: Int), size: CGFloat) {
        emojiArt.addEmoji(emoji, at: location, size: Int(size))
    }
    
    func moveEmoji(_ emoji: EmojiArtModel.Emoji, by offset: CGSize) {
        if let index = emojiArt.emojis.index(matching: emoji) {
            emojiArt.emojis[index].x += Int(offset.width)
            emojiArt.emojis[index].y = Int(offset.height)
        }
    }
    
    func scaleEmoji(_ emoji: EmojiArtModel.Emoji, by scale: CGFloat) {
        if let index = emojiArt.emojis.index(matching: emoji) {
            emojiArt.emojis[index].size = Int((CGFloat(emojiArt.emojis[index].size) * scale).rounded(.toNearestOrAwayFromZero))
        }
    }
}
