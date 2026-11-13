package hu.kretaora.core.timetable

import hu.kretaora.core.model.KretaDate
import hu.kretaora.core.model.Lesson
import java.time.Instant

/** One thing that changed about an upcoming lesson. */
data class TimetableChange(
    val kind: Kind,
    /** The lesson as it is now, or the removed lesson. */
    val lesson: Lesson,
    /** The lesson as it was, when there was one. */
    val previous: Lesson? = null,
) {
    enum class Kind(val key: String) {
        CANCELLED("cancelled"),

        /** A cancelled lesson will be held after all. */
        RESTORED("restored"),

        /** The teacher or the substitute changed. */
        TEACHER("teacher"),
        TIME("time"),
        ROOM("room"),
        ADDED("added"),
        REMOVED("removed"),
    }

    val id: String get() = "${kind.key}:${lesson.id}"
}

object TimetableDiff {
    /**
     * Changes worth telling the student about.
     *
     * - The first snapshot of an account is a silent baseline.
     * - Only lessons that have not ended yet count.
     * - Days outside the previously seen window are new, not "added", so a
     *   week rolling into view stays silent.
     * - A lesson whose identifier changed but which sits in the same slot
     *   with the same subject is compared as one lesson.
     */
    fun changes(old: TimetableSnapshot?, new: TimetableSnapshot, now: Instant): List<TimetableChange> {
        if (old == null || old.accountId != new.accountId) return emptyList()

        val oldById = index(old.lessons)
        val newById = index(new.lessons)
        fun isUpcoming(lesson: Lesson) = lesson.end > now

        val modified = newById.values.mapNotNull { lesson ->
            oldById[lesson.id]?.takeIf { isUpcoming(lesson) }?.let { classify(it, lesson) }
        }

        val appeared = newById.values.filter { it.id !in oldById && isUpcoming(it) && old.covers(it.start) }
        val vanished = oldById.values.filter { it.id !in newById && isUpcoming(it) && new.covers(it.start) }

        val appearedBySlot = firstBy(appeared, ::Slot)
        val moved = vanished.mapNotNull { before -> appearedBySlot[Slot(before)]?.let { before to it } }
        val movedOld = moved.map { it.first.id }.toSet()
        val movedNew = moved.map { it.second.id }.toSet()

        val replaced = moved.mapNotNull { (before, after) -> classify(before, after) }
        val added = appeared
            .filter { it.id !in movedNew && !it.isCancelled }
            .map { TimetableChange(TimetableChange.Kind.ADDED, it) }
        val removed = vanished
            .filter { it.id !in movedOld && !it.isCancelled }
            .map { TimetableChange(TimetableChange.Kind.REMOVED, it) }

        return (modified + replaced + added + removed)
            .sortedWith(compareBy<TimetableChange> { it.lesson.start }.thenBy { it.id })
    }

    /**
     * The most important difference between two versions of one lesson, or
     * null when nothing the student cares about changed.
     */
    internal fun classify(before: Lesson, after: Lesson): TimetableChange? {
        val kind = when {
            before.isCancelled != after.isCancelled ->
                if (after.isCancelled) TimetableChange.Kind.CANCELLED else TimetableChange.Kind.RESTORED
            after.isCancelled -> null
            before.start != after.start || before.end != after.end -> TimetableChange.Kind.TIME
            before.substituteTeacher != after.substituteTeacher || before.teacher != after.teacher ->
                TimetableChange.Kind.TEACHER
            before.room != after.room -> TimetableChange.Kind.ROOM
            else -> null
        }
        return kind?.let { TimetableChange(it, after, before) }
    }

    /**
     * Only real lessons take part. Free-slot placeholders are noise, and a
     * school-year event such as a day off is not a lesson that was added.
     */
    private fun index(lessons: List<Lesson>): Map<String, Lesson> =
        firstBy(lessons.filter { it.kind == Lesson.Kind.LESSON }) { it.id }

    /** Like `associateBy`, but the first lesson with a key wins. */
    private fun <K> firstBy(lessons: List<Lesson>, key: (Lesson) -> K): Map<K, Lesson> =
        lessons.asReversed().associateBy(key)
}

/** Identifies "the same lesson" across an identifier change. */
private data class Slot(val day: String, val position: String, val name: String) {
    constructor(lesson: Lesson) : this(
        day = KretaDate.dayString(lesson.start),
        position = lesson.index?.toString() ?: KretaDate.timeString(lesson.start),
        name = lesson.name.lowercase(),
    )
}
