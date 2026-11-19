






import UIKit

public extension UIView {
    
    var ST_x : CGFloat {
        get {
            return frame.origin.x
        }
        set(newValue) {
            var oldFrame = frame
            oldFrame.origin.x = newValue
            frame = oldFrame
        }
    }
    
    var ST_y : CGFloat {
        get {
            return frame.origin.y
        }
        set(newValue) {
            var oldFrame = frame
            oldFrame.origin.y = newValue
            frame = oldFrame
        }
    }
    
    var ST_width : CGFloat {
        get {
            return frame.size.width
        }
        set(newValue) {
            var oldFrame = frame
            oldFrame.size.width = newValue
            frame = oldFrame
        }
    }
    
    var ST_height : CGFloat {
        get {
            return frame.size.height
        }
        set(newValue) {
            var oldFrame = frame
            oldFrame.size.height = newValue
            frame = oldFrame
        }
    }
    
    var ST_top : CGFloat {
        get {
            return ST_y
        }
    }
    
    var ST_left : CGFloat {
        get {
            return ST_x
        }
    }
    
    var ST_bottom : CGFloat {
        get {
            return (frame.size.height + ST_y)
        }
    }
    
    var ST_right : CGFloat {
        get {
            return (frame.size.width + ST_x)
        }
    }
    
}
