import KretaKit
import SwiftUI

/// The detail line with the news parts in heavy weight, in one `Text` so it
/// truncates as a whole.
struct LessonDetailText: View {
    let detail: LessonDetail
    var style: KretaTextStyle = KretaType.small
    var newsWeight: CGFloat = 800
    var scalesWithDynamicType = true

    @ScaledMetric(relativeTo: .body) private var scaled: CGFloat = 100

    var body: some View {
        let scale = scalesWithDynamicType ? scaled / 100 : 1
        let plainFont = style.font(scale: scale)
        let newsFont = style.weight(newsWeight).font(scale: scale)
        detail.parts.enumerated().reduce(Text(verbatim: "")) { text, item in
            let (index, part) = item
            let separator = index == 0 ? "" : Formatting.separator
            let piece = Text(verbatim: part.text).font(part.isNews ? newsFont : plainFont)
            return Text("\(text)\(Text(verbatim: separator).font(plainFont))\(piece)")
        }
        .lineHeight(.exact(points: style.lineHeight * scale))
        .lineLimit(1)
        .truncationMode(.tail)
    }
}
