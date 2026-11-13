import SwiftUI
import WidgetKit

/// Complications for the watch face and widgets for the Smart Stack.
@main
struct KretaOraWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextLessonWidget()
        TomorrowWidget()
    }
}
