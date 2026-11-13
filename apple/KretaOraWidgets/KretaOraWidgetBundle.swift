import SwiftUI
import WidgetKit

@main
struct KretaOraWidgetBundle: WidgetBundle {
    var body: some Widget {
        NextLessonWidget()
        TomorrowWidget()
        DayWidget()
    }
}
