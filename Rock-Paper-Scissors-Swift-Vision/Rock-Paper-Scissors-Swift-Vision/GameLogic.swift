import Foundation
import Vision

class Game{
    var cpuPlay: String?
    var userPlay: String?
    private var paperEvidenceCounter = 0
    private var rockEvidenceCounter = 0
    private var scissorEvidenceCounter = 0
    
    func getCPUPlay() {
        let playArray = ["🤚", "✌️", "✊"]
        cpuPlay = playArray.randomElement()!

    }
    
    func reset() {
        paperEvidenceCounter = 0
        rockEvidenceCounter = 0
        scissorEvidenceCounter = 0
    }
    
    //After the user presents a valid play ("🤚", "✌️", "✊"), this function will save that play once confident. This may take up to a second on older iphones, but is almost instantaneous on the iPad Pro.
    func gatherEvidence(_ testDifferenceRing: CGFloat,_  testDifferenceIndex: CGFloat) -> Bool {
        if paperEvidenceCounter > 7 {
            userPlay = "🤚"
            return true
        } else if rockEvidenceCounter > 7 {
            userPlay = "✊"
            return true
        } else if scissorEvidenceCounter > 7 {
            userPlay = "✌️"
            return true
        }
    
        if testDifferenceIndex <= 57 && testDifferenceRing < 60 {
            paperEvidenceCounter+=1
            rockEvidenceCounter = 0
            scissorEvidenceCounter = 0
        }
        else if testDifferenceIndex <= 57 && testDifferenceRing > 60 {
            scissorEvidenceCounter+=1
            paperEvidenceCounter = 0
            rockEvidenceCounter = 0
            
        } else if testDifferenceIndex >= 57 && testDifferenceRing > 60 {
            rockEvidenceCounter+=1
            paperEvidenceCounter = 0
            scissorEvidenceCounter = 0
    
        }
        return false
    }
    
    //gameplay logic
    func getWinner() -> String {
        if cpuPlay == userPlay {
            return "DRAW"
        } else if cpuPlay == "🤚" && userPlay == "✌️" {
                return "USER"
        } else if cpuPlay == "✌️" && userPlay == "✊" {
                return "USER"
        } else if cpuPlay == "✊" && userPlay == "🤚" {
                return "USER"
        }
        return "CPU"
    }
}
