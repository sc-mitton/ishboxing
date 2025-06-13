import CoreGraphics

struct Vector {
    let start: CGPoint
    let end: CGPoint

    init(start: CGPoint, end: CGPoint) {
        self.start = start
        self.end = end
    }

    func dotProduct(other: Vector) -> Double {
        return start.x * other.start.x + start.y * other.start.y
    }
}
