package hu.kretaora.core.timetable

import hu.kretaora.core.model.InstantSerializer
import hu.kretaora.core.model.Lesson
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import java.io.File
import java.io.IOException
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import java.time.Instant

/**
 * The last timetable the app saw, plus the window it covers. Widgets render
 * from this; the diff compares against it.
 */
@Serializable
data class TimetableSnapshot(
    val accountId: String,
    val lessons: List<Lesson>,
    /** Start of the first covered school day. */
    @Serializable(with = InstantSerializer::class) val rangeStart: Instant,
    /** Start of the day after the last covered school day. */
    @Serializable(with = InstantSerializer::class) val rangeEnd: Instant,
    @Serializable(with = InstantSerializer::class) val syncedAt: Instant,
) {
    val schedule: Schedule get() = Schedule(lessons)

    fun covers(instant: Instant): Boolean = rangeStart <= instant && instant < rangeEnd
}

/**
 * Persists the snapshot as one JSON file, written atomically. The app, the
 * background worker and the widgets all read the same file.
 */
class SnapshotStore(directory: File) {
    private val file = File(directory, "timetable.json")
    private val json = Json { ignoreUnknownKeys = true }

    /**
     * The stored snapshot, or null when there is none or it is unreadable.
     * An unreadable file behaves like a first launch: the next sync rebuilds
     * it silently.
     */
    fun load(): TimetableSnapshot? =
        try {
            json.decodeFromString(TimetableSnapshot.serializer(), file.readText(Charsets.UTF_8))
        } catch (_: IOException) {
            null
        } catch (_: SerializationException) {
            null
        } catch (_: IllegalArgumentException) {
            null
        }

    fun save(snapshot: TimetableSnapshot) {
        val directory = file.parentFile
        Files.createDirectories(directory.toPath())
        val temporary = File.createTempFile("timetable", ".tmp", directory)
        try {
            temporary.writeText(json.encodeToString(TimetableSnapshot.serializer(), snapshot), Charsets.UTF_8)
            Files.move(
                temporary.toPath(),
                file.toPath(),
                StandardCopyOption.ATOMIC_MOVE,
                StandardCopyOption.REPLACE_EXISTING,
            )
        } finally {
            Files.deleteIfExists(temporary.toPath())
        }
    }

    fun clear() {
        Files.deleteIfExists(file.toPath())
    }
}
